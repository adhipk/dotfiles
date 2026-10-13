#!/usr/bin/env python3
"""Inventory bundled GHC boot/runtime and Hackage C/Lua sources for human closure review."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import tarfile


def inventory_ghc(archive,units):
    wanted={unit['name']:unit for unit in units};descriptions={};embedded=[];notices=[]
    with tarfile.open(archive,'r:xz') as source:
        for member in source:
            if not member.isfile():continue
            if member.name.endswith(('.tar.gz','.tar.xz','.tar.bz2')) and ('gmp-tarballs/' in member.name or 'libffi-tarballs/' in member.name):
                data=source.extractfile(member).read();embedded.append({'path':member.name,'sha256':hashlib.sha256(data).hexdigest()})
            if Path(member.name).name.startswith(('LICENSE','COPYING','COPYRIGHT')):notices.append(member.name)
            if not member.name.endswith(('.cabal','.cabal.in')):continue
            if '/testsuite/' in member.name or '/tests/' in member.name or '/nofib/' in member.name:continue
            text=source.extractfile(member).read().decode(errors='replace')
            name=re.search(r'^name\s*:\s*(\S+)',text,re.M|re.I);version=re.search(r'^version\s*:\s*(\S+)',text,re.M|re.I)
            if name and name[1] in wanted:
                unit=wanted[name[1]]
                if version and (version[1]==unit['version'] or '@' in version[1]):descriptions.setdefault(name[1],[]).append({'path':member.name,'declaredVersion':version[1],'installedVersion':unit['version'],'unitID':unit['unitID']})
    missing=set(wanted)-set(descriptions)
    if missing:raise ValueError('GHC source does not describe installed boot units: '+str(sorted(missing)))
    if not any('gmp-' in item['path'] for item in embedded) or not any('libffi-' in item['path'] for item in embedded):raise ValueError('GHC bundled GMP/libffi sources absent')
    return {'bootLibraries':descriptions,'embeddedGMPAndLibffiSources':embedded,'licenseNoticePaths':sorted(notices),'scope':'Bound GHC source archive inventories; compiler bindist and source release identity still require reviewed provenance.'}


def inventory_packages(closure,directory):
    result=[]
    for package in closure['resolvedSourceClosure']:
        paths=[]
        with tarfile.open(directory/package['archive'],'r:gz') as source:
            for member in source:
                if member.isfile() and (member.name.endswith(('.c','.cc','.cpp','.h','.hpp','.S')) or member.name.endswith(('.tar.gz','.tar.xz','.tar.bz2'))):
                    data=source.extractfile(member).read();paths.append({'path':member.name,'sha256':hashlib.sha256(data).hexdigest()})
        if paths:result.append({'package':package['id'],'sourceArchiveSHA256':package['sha256'],'foreignSourceFilesAndEmbeddedArchives':paths})
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--ghc-source',type=Path,required=True);parser.add_argument('--closure',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();closure=json.loads((args.closure/'closure.json').read_text())
    record={'schemaVersion':1,'ghc':inventory_ghc(args.ghc_source,closure['preExistingGHCUnits']),'hackageForeignSources':inventory_packages(closure,args.closure),'reviewRequired':True,'scope':'Source-file inventory, not proof of every linked symbol or a legal compliance assurance.'}
    args.output.write_text(json.dumps(record,indent=2)+'\n');print(args.output)


if __name__=='__main__':main()
