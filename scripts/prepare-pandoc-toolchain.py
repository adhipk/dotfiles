#!/usr/bin/env python3
"""Install exact checksum-pinned GHC/Cabal into an explicit isolated prefix, never globally."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import urllib.request
import time

ROOT=Path(__file__).resolve().parent.parent


def sha256(path):
    digest=hashlib.sha256()
    with path.open('rb') as source:
        while chunk:=source.read(1024*1024):digest.update(chunk)
    return digest.hexdigest()


def download(url, checksum, destination):
    if not destination.exists():
        destination.parent.mkdir(parents=True,exist_ok=True)
        temporary=destination.with_suffix(destination.suffix+'.download')
        for attempt in range(3):
            try:
                with urllib.request.urlopen(url,timeout=120) as response,temporary.open('wb') as output:shutil.copyfileobj(response,output)
                break
            except OSError:
                if attempt==2:raise
                time.sleep(2**attempt)
        if sha256(temporary)!=checksum:
            temporary.unlink();raise ValueError('Download checksum mismatch: '+url)
        temporary.replace(destination)
    if sha256(destination)!=checksum:raise ValueError('Cached checksum mismatch: '+str(destination))
    return destination


def run(*args,cwd=None,env=None):subprocess.run(list(map(str,args)),cwd=cwd,env=env,check=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prefix',type=Path,required=True);parser.add_argument('--cache',type=Path,required=True)
    args=parser.parse_args();prefix=args.prefix.resolve();cache=args.cache.resolve();architecture=platform.machine()
    if platform.system()!='Darwin':raise SystemExit('macOS toolchain required')
    pins=json.loads((ROOT/'release/vendor/pandoc-source/own-build-inputs.json').read_text());arch=pins['toolchains'][architecture]
    if (prefix/'toolchain.json').exists():
        record=json.loads((prefix/'toolchain.json').read_text())
        if record['inputs']!=arch:raise SystemExit('Existing toolchain differs from pins')
        print(prefix/'toolchain.json');return
    if prefix.exists():raise SystemExit('Refusing to overwrite incomplete/existing prefix; choose a fresh path')
    prefix.mkdir(parents=True);(prefix/'installing.json').write_text(json.dumps(arch,indent=2)+'\n')
    ghc=download(arch['ghcURL'],arch['ghcSHA256'],cache/('ghc-9.10.3-'+architecture+'.tar.xz'))
    cabal=download(arch['cabalURL'],arch['cabalSHA256'],cache/('cabal-3.14.2.0-'+architecture+'.tar.xz'))
    unpack=prefix/'unpack';unpack.mkdir()
    # Checksummed upstream bindists may contain internal links required by make install.
    with tarfile.open(ghc,'r:xz') as source:source.extractall(unpack,filter='data')
    directory=next(p for p in unpack.iterdir() if p.is_dir())
    run('./configure','--prefix='+str(prefix/'ghc'),cwd=directory)
    run('make','install',cwd=directory)
    binaries=prefix/'bin';binaries.mkdir()
    with tarfile.open(cabal,'r:xz') as source:
        candidates=[m for m in source.getmembers() if Path(m.name).name=='cabal' and m.isfile()]
        if len(candidates)!=1:raise ValueError('Unexpected Cabal bindist')
        with source.extractfile(candidates[0]) as binary,(binaries/'cabal').open('wb') as output:shutil.copyfileobj(binary,output)
    (binaries/'cabal').chmod(0o755)
    ghc_path=prefix/'ghc/bin/ghc';cabal_path=binaries/'cabal'
    ghc_version=subprocess.check_output([str(ghc_path),'--numeric-version'],text=True).strip()
    cabal_version=subprocess.check_output([str(cabal_path),'--numeric-version'],text=True).strip()
    if ghc_version!=pins['ghcVersion'] or cabal_version!=pins['cabalVersion']:raise ValueError('Installed tool version differs from pin')
    record={'architecture':architecture,'inputs':arch,'ghc':str(ghc_path),'cabal':str(cabal_path),'ghcVersion':ghc_version,'cabalVersion':cabal_version}
    (prefix/'toolchain.json').write_text(json.dumps(record,indent=2)+'\n');print(prefix/'toolchain.json')


if __name__=='__main__':main()
