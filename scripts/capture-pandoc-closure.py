#!/usr/bin/env python3
"""Capture each resolved Hackage tarball and exact selected Cabal revision from the secure index."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('toolchain',ROOT/'scripts/prepare-pandoc-toolchain.py')
tools=importlib.util.module_from_spec(spec);spec.loader.exec_module(tools)


def resolved_packages(plan):
    packages={};boot=[];local=[]
    for unit in plan['install-plan']:
        name=unit['pkg-name'];version=unit['pkg-version'];identifier=name+'-'+version
        if not re.fullmatch(r'[A-Za-z0-9-]+',name) or not re.fullmatch(r'[0-9.]+',version):raise ValueError('Unsafe package identity')
        if unit['type']=='pre-existing':boot.append({'name':name,'version':version,'unitID':unit['id']});continue
        kind=unit.get('pkg-src',{}).get('type')
        if kind=='local':local.append({'name':name,'version':version});continue
        if kind!='repo-tar':raise ValueError('Uncaptured non-Hackage dependency source: '+identifier+' '+str(kind))
        checksum=unit.get('pkg-src-sha256','')
        if not re.fullmatch(r'[0-9a-f]{64}',checksum):raise ValueError('Missing secure source archive hash: '+identifier)
        record={'name':name,'version':version,'id':identifier,'sha256':checksum,'cabalSHA256':unit.get('pkg-cabal-sha256')}
        if identifier in packages and packages[identifier]!=record:raise ValueError('Conflicting source/revision hashes: '+identifier)
        packages[identifier]=record
    return sorted(packages.values(),key=lambda p:p['id']),boot,local


def revision_files(index,packages):
    expected={f"{p['name']}/{p['version']}/{p['name']}.cabal":p['cabalSHA256'] for p in packages if p.get('cabalSHA256')};found={}
    with tarfile.open(index,'r:*') as archive:
        for member in archive:
            if member.name in expected and member.isfile():
                data=archive.extractfile(member).read()
                if hashlib.sha256(data).hexdigest()==expected[member.name]:found[member.name]=data
    missing=set(expected)-set(found)
    if missing:raise ValueError('Exact selected Cabal revisions missing from local secure index: '+str(sorted(missing)))
    return found


def package_metadata(archive,name,version,revised=None):
    prefix=name+'-'+version+'/'
    with tarfile.open(archive,'r:gz') as source:
        member=source.getmember(prefix+name+'.cabal')
        if not member.isfile():raise ValueError('Invalid package Cabal source')
        cabal=revised if revised is not None else source.extractfile(member).read()
        text=cabal.decode();license_match=re.search(r'^license\s*:\s*(.*)',text,re.I|re.M)
        if not license_match or not license_match[1].strip():raise ValueError('Package license undeclared: '+name)
        license_paths=[]
        for line in re.finditer(r'^license-files?\s*:\s*(.*)',text,re.I|re.M):
            license_paths.extend(part.strip('"') for part in re.split(r'[,\s]+',line[1].strip()) if part)
        notice_files={}
        for relative in license_paths:
            if relative.startswith('/') or '..' in Path(relative).parts:raise ValueError('Unsafe package license path')
            member=source.getmember(prefix+relative)
            if not member.isfile():raise ValueError('Missing package license source: '+name+'/'+relative)
            notice_files[relative]=source.extractfile(member).read()
        return cabal,license_match[1].strip(),notice_files


def _capture(plan,cabal_dir,destination):
    packages,boot,local=resolved_packages(plan)
    if destination.exists():
        record=json.loads((destination/'closure.json').read_text())
        if record['planSHA256']!=hashlib.sha256(json.dumps(plan,sort_keys=True).encode()).hexdigest():raise ValueError('Existing closure differs from plan')
        for name,checksum in record['files'].items():
            if tools.sha256(destination/name)!=checksum:raise ValueError('Existing closure checksum mismatch')
        return record
    destination.mkdir(parents=True)
    cache=cabal_dir/'packages/hackage.haskell.org'
    indexes=[p for p in [cache/'01-index.tar',cache/'01-index.tar.gz'] if p.is_file()]
    if not indexes:raise ValueError('Secure Hackage index unavailable')
    revisions=revision_files(indexes[0],packages)
    def fetch(package):
        filename=package['id']+'.tar.gz';url='https://hackage-content.haskell.org/package/'+package['id']+'/'+filename
        cached=tools.download(url,package['sha256'],cache/package['name']/package['version']/filename)
        target=destination/'packages'/filename;target.parent.mkdir(exist_ok=True);shutil.copy2(cached,target)
        key=f"{package['name']}/{package['version']}/{package['name']}.cabal"
        revision=revisions.get(key)
        cabal,license_name,notices=package_metadata(target,package['name'],package['version'],revision)
        revision_path=destination/'revisions'/(package['id']+'.cabal');revision_path.parent.mkdir(exist_ok=True);revision_path.write_bytes(cabal)
        notice_paths=[]
        for relative,data in notices.items():
            path=destination/'licenses'/package['id']/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);notice_paths.append(str(path.relative_to(destination)))
        return dict(package,sourceURL=url,archive=str(target.relative_to(destination)),cabalRevisionFile=str(revision_path.relative_to(destination)),selectedCabalSHA256=hashlib.sha256(cabal).hexdigest(),license=license_name,licenseFiles=notice_paths)
    with ThreadPoolExecutor(max_workers=6) as executor:captured=list(executor.map(fetch,packages))
    secure_metadata={}
    for name in ['root.json','timestamp.json','snapshot.json','mirrors.json']:
        path=cache/name
        if path.exists():
            target=destination/'hackage-security'/name;target.parent.mkdir(exist_ok=True);shutil.copy2(path,target);secure_metadata[name]=str(target.relative_to(destination))
    record={'schemaVersion':1,'planSHA256':hashlib.sha256(json.dumps(plan,sort_keys=True).encode()).hexdigest(),'resolvedSourceClosure':captured,'preExistingGHCUnits':boot,'localSourcePackages':local,'hackageSecurityMetadata':secure_metadata,'status':'captured-sources-not-a-license-review','files':{str(p.relative_to(destination)):tools.sha256(p) for p in sorted(destination.rglob('*')) if p.is_file()}}
    (destination/'closure.json').write_text(json.dumps(record,indent=2)+'\n');return record


def capture(plan,cabal_dir,destination):
    if destination.exists():return _capture(plan,cabal_dir,destination)
    destination.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='closure-stage-',dir=destination.parent) as temporary:
        staging=Path(temporary)/'payload'
        record=_capture(plan,cabal_dir,staging)
        staging.replace(destination)
        return record


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--plan',type=Path,required=True);parser.add_argument('--cabal-dir',type=Path,required=True);parser.add_argument('--destination',type=Path,required=True);parser.add_argument('--inputs',type=Path,required=True)
    args=parser.parse_args();plan=json.loads(args.plan.read_text());inputs=json.loads(args.inputs.read_text())
    if plan.get('compiler-id')!='ghc-'+inputs['ghcVersion']:raise SystemExit('Resolved compiler differs from pin')
    result=capture(plan,args.cabal_dir,args.destination);print(f"Captured {len(result['resolvedSourceClosure'])} Hackage source archives and selected revisions; {len(result['preExistingGHCUnits'])} boot units require bundled GHC source review",flush=True)


if __name__=='__main__':main()
