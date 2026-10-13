#!/usr/bin/env python3
"""Build unchanged pinned upstream Pandoc with isolated Cabal state and captured inputs."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import time

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('toolchain',ROOT/'scripts/prepare-pandoc-toolchain.py')
tools=importlib.util.module_from_spec(spec);spec.loader.exec_module(tools)


def run_logged(args, cwd, env, log):
    with log.open('a') as output:
        output.write('\n$ '+ ' '.join(map(str,args))+'\n');output.flush()
        result=subprocess.run(list(map(str,args)),cwd=cwd,env=env,stdout=output,stderr=subprocess.STDOUT)
    if result.returncode:raise RuntimeError(f'Command failed ({result.returncode}); inspect {log}')


def stage_captured_sources(closure, destination):
    record=json.loads((closure/'closure.json').read_text());destination.mkdir(parents=True,exist_ok=True);mapping=[]
    for package in record['resolvedSourceClosure']:
        archive=closure/package['archive'];directory=destination/package['id']
        if tools.sha256(archive)!=package['sha256']:raise ValueError('Captured source archive checksum differs')
        if not directory.exists():
            with tarfile.open(archive,'r:gz') as source:source.extractall(destination,filter='data')
        revision=closure/package['cabalRevisionFile']
        if tools.sha256(revision)!=package['selectedCabalSHA256']:raise ValueError('Captured Cabal revision checksum differs')
        with tarfile.open(archive,'r:gz') as original:
            prefix=package['id']+'/'
            for member in original:
                if member.name==package['id'] and member.isdir():continue
                if not member.name.startswith(prefix):raise ValueError('Unexpected package archive root')
                relative=member.name[len(prefix):]
                if not relative:continue
                path=directory/relative
                if member.isfile():
                    expected=original.extractfile(member).read()
                    if relative==package['name']+'.cabal':
                        if path.read_bytes() not in [expected,revision.read_bytes()]:raise ValueError('Staged Cabal metadata drift')
                    elif path.is_symlink() or path.read_bytes()!=expected:raise ValueError('Staged upstream source drift: '+str(path))
                elif member.issym():
                    if not path.is_symlink() or os.readlink(path)!=member.linkname:raise ValueError('Staged source link drift')
        shutil.copy2(revision,directory/(package['name']+'.cabal'))
        mapping.append({'package':package['id'],'directory':str(directory),'originalArchiveSHA256':package['sha256'],'appliedCabalSHA256':package['selectedCabalSHA256']})
    return mapping


def offline_project(index_state,mapping):
    return ('index-state: '+index_state+'\nactive-repositories: :none\ntests: False\nbenchmarks: False\npackages:\n'+''.join('  '+json.dumps(item['directory'])+'\n' for item in mapping)+'package pandoc\n  flags: +embed_data_files +http\npackage pandoc-cli\n  flags: +server +lua\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--toolchain',type=Path,required=True);parser.add_argument('--work',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--jobs',type=int,default=2);parser.add_argument('--run-url',required=True)
    args=parser.parse_args();work=args.work.resolve();output=args.output.resolve();toolchain=json.loads(args.toolchain.read_text());architecture=platform.machine()
    pins=json.loads((ROOT/'release/vendor/pandoc-source/own-build-inputs.json').read_text())
    if platform.system()!='Darwin' or architecture!=toolchain['architecture']:raise SystemExit('Matching native macOS architecture required')
    if args.jobs<1 or args.jobs>8:raise SystemExit('Use 1..8 bounded compiler jobs')
    ghc=Path(toolchain['ghc']);cabal=Path(toolchain['cabal'])
    if subprocess.check_output([str(ghc),'--numeric-version'],text=True).strip()!=pins['ghcVersion'] or subprocess.check_output([str(cabal),'--numeric-version'],text=True).strip()!=pins['cabalVersion']:raise SystemExit('Pinned GHC/Cabal versions required')
    if output.exists():raise SystemExit('Refusing to overwrite existing build artifact')
    work.mkdir(parents=True,exist_ok=True)
    state=work/'inputs.json'
    if state.exists() and json.loads(state.read_text())!=pins:raise SystemExit('Work directory pins differ; use a fresh work directory')
    state.write_text(json.dumps(pins,indent=2)+'\n')
    env=dict(os.environ,CABAL_DIR=str(work/'cabal'),PATH=str(ghc.parent)+os.pathsep+str(cabal.parent)+os.pathsep+os.environ['PATH'],MACOSX_DEPLOYMENT_TARGET='13.0')
    archive=tools.download(pins['pandocSourceURL'],pins['pandocSourceSHA256'],work/'downloads/pandoc-source.tar.gz')
    source=work/('pandoc-'+pins['pandocCommit'])
    if not source.exists():
        with tarfile.open(archive,'r:gz') as upstream:upstream.extractall(work,filter='data')
    config=work/'cabal/config';config.parent.mkdir(exist_ok=True)
    if not config.exists():
        subprocess.run([str(cabal),'user-config','init'],env=env,check=True)
        config.write_text(config.read_text().replace('http://hackage.haskell.org/','https://hackage-content.haskell.org/'))
    (source/'cabal.project.local').write_text('index-state: '+pins['indexState']+'\nactive-repositories: hackage.haskell.org\n')
    log=work/'build.log';started=time.time();flags=pins['buildFlags']
    print(f'Planning/building {architecture}, isolated state {work}, progress log {log}',flush=True)
    run_logged([cabal,'update'],source,env,log)
    run_logged([cabal,'build','all','--dry-run','--index-state='+pins['indexState'],*flags],source,env,log)
    run_logged([cabal,'freeze','--index-state='+pins['indexState'],*flags],source,env,log)
    plan=source/'dist-newstyle/cache/plan.json'
    subprocess.run(['python3',str(ROOT/'scripts/capture-pandoc-closure.py'),'--plan',str(plan),'--cabal-dir',str(work/'cabal'),'--destination',str(work/'closure'),'--inputs',str(ROOT/'release/vendor/pandoc-source/own-build-inputs.json')],check=True)
    shutil.copy2(plan,work/'captured-repository-plan.json')
    shutil.copy2(source/'cabal.project.freeze',work/'captured-repository.freeze')
    mapping=stage_captured_sources(work/'closure',work/'resolved-sources')
    (work/'local-source-map.json').write_text(json.dumps(mapping,indent=2)+'\n')
    (source/'cabal.project.local').write_text(offline_project(pins['indexState'],mapping))
    # RepoTarballPackage remains remote in Cabal 3.14's offline guard, even with
    # cached tarballs. Explicit local sources plus selected revisions avoid it.
    run_logged([cabal,'freeze','--offline'],source,env,log)
    run_logged([cabal,'build','pandoc-cli:exe:pandoc','--offline','-j'+str(args.jobs)],source,env,log)
    binary=Path(subprocess.check_output([str(cabal),'list-bin','pandoc-cli:exe:pandoc'],cwd=source,env=env,text=True).strip())
    output.mkdir(parents=True);shutil.copy2(binary,output/'pandoc');subprocess.run(['strip',str(output/'pandoc')],check=True)
    binary_version=subprocess.check_output([str(output/'pandoc'),'--version'],text=True)
    if binary_version.splitlines()[0]!='pandoc '+pins['pandocVersion']:raise RuntimeError('Built binary version differs')
    libraries=subprocess.check_output(['otool','-L',str(output/'pandoc')],text=True)
    external=[line.strip() for line in libraries.splitlines()[1:] if line.strip() and not line.strip().startswith(('/usr/lib/','/System/Library/'))]
    if external:raise RuntimeError('Non-system runtime libraries remain: '+str(external))
    for name,path in {'plan.json':plan,'cabal.project':source/'cabal.project','cabal.project.local':source/'cabal.project.local','cabal.project.freeze':source/'cabal.project.freeze','build.log':log,'pandoc-source.tar.gz':archive,'captured-repository-plan.json':work/'captured-repository-plan.json','captured-repository.freeze':work/'captured-repository.freeze','local-source-map.json':work/'local-source-map.json'}.items():shutil.copy2(path,output/name)
    shutil.copytree(work/'closure',output/'closure')
    shutil.copy2(args.toolchain,output/'toolchain.json')
    ghc_source=tools.download(pins['ghcSourceURL'],pins['ghcSourceSHA256'],work/'downloads/ghc-source.tar.xz');shutil.copy2(ghc_source,output/'ghc-source.tar.xz')
    subprocess.run(['python3',str(ROOT/'scripts/inventory-pandoc-runtime-source.py'),'--ghc-source',str(output/'ghc-source.tar.xz'),'--closure',str(output/'closure'),'--output',str(output/'runtime-source-inventory.json')],check=True)
    (output/'ghc-pkg-global.txt').write_text(subprocess.check_output([str(ghc.parent/'ghc-pkg'),'dump','--global'],text=True,env=env))
    (output/'ghc-info.txt').write_text(subprocess.check_output([str(ghc),'--info'],text=True))
    (output/'runtime-libraries.txt').write_text(libraries);(output/'pandoc-version.txt').write_text(binary_version)
    (output/'own-build-inputs.json').write_text(json.dumps(pins,indent=2)+'\n')
    for script in ['build-pandoc-from-source.py','capture-pandoc-closure.py','prepare-pandoc-toolchain.py','inventory-pandoc-runtime-source.py']:shutil.copy2(ROOT/'scripts'/script,output/script)
    record={'schemaVersion':1,'producer':'dotfiles-pinned-source-build','architecture':architecture,'pandocVersion':pins['pandocVersion'],'sourceCommit':pins['pandocCommit'],'binarySHA256':tools.sha256(output/'pandoc'),'ghcVersion':pins['ghcVersion'],'cabalVersion':pins['cabalVersion'],'indexState':pins['indexState'],'macOS':platform.mac_ver()[0],'macOSSDK':subprocess.check_output(['xcrun','--show-sdk-version'],text=True).strip(),'xcodeVersion':subprocess.check_output(['xcodebuild','-version'],text=True).strip(),'buildExecutionURL':args.run_url,'elapsedSeconds':round(time.time()-started),'captureStatus':'source-captured-review-required','reviewPending':['Review complete non-system C/Lua/GHC runtime source coverage and license inventory','Verify offline reconstruction on both architectures before adopting replacement binary'],'files':{str(p.relative_to(output)):tools.sha256(p) for p in sorted(output.rglob('*')) if p.is_file()}}
    (output/'own-build.json').write_text(json.dumps(record,indent=2)+'\n');print(output/'own-build.json',flush=True)


if __name__=='__main__':main()
