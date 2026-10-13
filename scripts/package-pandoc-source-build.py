#!/usr/bin/env python3
"""Package captured own-build sources separately from the compiler and distributed binary."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('toolchain',ROOT/'scripts/prepare-pandoc-toolchain.py')
tools=importlib.util.module_from_spec(spec);spec.loader.exec_module(tools)


def package(artifact):
    metadata=json.loads((artifact/'own-build.json').read_text());pins=json.loads((ROOT/'release/vendor/pandoc-source/own-build-inputs.json').read_text())
    if metadata.get('producer')!='dotfiles-pinned-source-build' or metadata['sourceCommit']!=pins['pandocCommit'] or metadata['pandocVersion']!=pins['pandocVersion']:raise ValueError('Unexpected source build identity')
    if metadata['ghcVersion']!=pins['ghcVersion'] or metadata['cabalVersion']!=pins['cabalVersion'] or metadata['indexState']!=pins['indexState']:raise ValueError('Build toolchain/index inputs differ')
    if tools.sha256(artifact/'pandoc')!=metadata['binarySHA256']:raise ValueError('Raw compiled binary checksum differs')
    for name,checksum in metadata['files'].items():
        if tools.sha256(artifact/name)!=checksum:raise ValueError('Captured build file checksum differs: '+name)
    if tools.sha256(artifact/'pandoc-source.tar.gz')!=pins['pandocSourceSHA256'] or tools.sha256(artifact/'ghc-source.tar.xz')!=pins['ghcSourceSHA256']:raise ValueError('Pinned root/compiler source archive differs')
    if not (artifact/'runtime-source-inventory.json').exists():
        subprocess.run(['python3',str(ROOT/'scripts/inventory-pandoc-runtime-source.py'),'--ghc-source',str(artifact/'ghc-source.tar.xz'),'--closure',str(artifact/'closure'),'--output',str(artifact/'runtime-source-inventory.json')],check=True)
    for script in ['prepare-pandoc-toolchain.py','capture-pandoc-closure.py','build-pandoc-from-source.py','inventory-pandoc-runtime-source.py','package-pandoc-source-build.py']:
        existing=artifact/script
        if existing.exists() and existing.read_bytes()!=(ROOT/'scripts'/script).read_bytes():raise ValueError('Builder recipe snapshot differs; retain old recipe and reconstruct before adoption: '+script)
        if not existing.exists():shutil.copy2(ROOT/'scripts'/script,existing)
    closure=json.loads((artifact/'closure/closure.json').read_text())
    for name,checksum in closure['files'].items():
        if tools.sha256(artifact/'closure'/name)!=checksum:raise ValueError('Captured closure file checksum differs')
    for package in closure['resolvedSourceClosure']:
        if tools.sha256(artifact/'closure'/package['archive'])!=package['sha256'] or tools.sha256(artifact/'closure'/package['cabalRevisionFile'])!=package['selectedCabalSHA256']:raise ValueError('Captured source/revision checksum differs')
    archive=artifact/f"pandoc-own-source-{metadata['architecture']}.zip"
    if archive.exists():raise ValueError('Refusing to overwrite existing source distribution archive')
    excluded={'pandoc','own-build.json',archive.name,archive.name+'.sha256','source-materials.json'}
    source_files={str(p.relative_to(artifact)):tools.sha256(p) for p in sorted(artifact.rglob('*')) if p.is_file() and str(p.relative_to(artifact)) not in excluded}
    manifest={key:value for key,value in metadata.items() if key!='files'}
    manifest.update(schemaVersion=1,captureStatus='source-captured-review-required',files=source_files,resolvedSourceClosure=closure['resolvedSourceClosure'],preExistingGHCUnits=closure['preExistingGHCUnits'],compilerSourceSHA256=pins['ghcSourceSHA256'],pandocSourceSHA256=pins['pandocSourceSHA256'])
    (artifact/'source-materials.json').write_text(json.dumps(manifest,indent=2)+'\n')
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as output:
        for name in sorted(source_files):output.write(artifact/name,'materials/'+name)
        output.write(artifact/'source-materials.json','materials/source-materials.json')
    checksum=tools.sha256(archive);archive.with_suffix('.zip.sha256').write_text(f'{checksum}  {archive.name}\n')
    metadata.update(sourceMaterialsArchive=archive.name,sourceMaterialsSHA256=checksum,files={str(p.relative_to(artifact)):tools.sha256(p) for p in sorted(artifact.rglob('*')) if p.is_file() and p.name!='own-build.json'})
    (artifact/'own-build.json').write_text(json.dumps(metadata,indent=2)+'\n');return archive


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--artifact',type=Path,required=True)
    args=parser.parse_args();print(package(args.artifact.resolve()))


if __name__=='__main__':main()
