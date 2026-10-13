#!/usr/bin/env python3
"""Build a self-contained native wrapper. No personal configuration is applied."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import platform
import shutil
import subprocess
import tempfile
import importlib.util

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = ROOT / 'modules/dotfiles-control-center'
_spec = importlib.util.spec_from_file_location('bundled_dependencies', ROOT / 'scripts/bundled-dependencies.py')
dependencies = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dependencies)

def run(*args):
    subprocess.run([str(a) for a in args], check=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'dist')
    parser.add_argument('--sign', default='-', help='Developer ID identity; default is an ad-hoc development build')
    parser.add_argument('--dependency-cache', type=Path, default=ROOT / 'dist/dependency-cache')
    parser.add_argument('--pandoc-artifact', type=Path, help='Verified pinned-source-build artifact directory with packaged source materials')
    args = parser.parse_args()
    if args.sign != '-' and args.pandoc_artifact is None:
        raise SystemExit('Developer ID builds require --pandoc-artifact; official binaries remain development-only while source review is pending.')
    version = (ROOT / 'VERSION').read_text().strip()
    source_commit = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    source_dirty = bool(subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain'], text=True).strip())
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    run('swift', 'build', '--package-path', PACKAGE, '-c', 'release')
    binaries = Path(subprocess.check_output(['swift','build','--package-path',str(PACKAGE),'-c','release','--show-bin-path'], text=True).strip())
    with tempfile.TemporaryDirectory(prefix='dotfiles-app-') as temp:
        app = Path(temp) / 'Dotfiles.app'
        macos = app / 'Contents/MacOS'
        resources = app / 'Contents/Resources'
        macos.mkdir(parents=True)
        resources.mkdir(parents=True)
        for document in ['NATIVE_APP.md', 'EXTENSION_AUTHORING.md', 'CONSUMER_SETUP.md']:
            shutil.copy2(ROOT / document, resources / document)
        for document in ['LICENSE', 'NOTICE', 'THIRD_PARTY_NOTICES.md']:
            if (ROOT / document).exists(): shutil.copy2(ROOT / document, resources / document)
        if (ROOT / 'release/support-matrix.json').exists():
            shutil.copy2(ROOT / 'release/support-matrix.json', resources / 'support-matrix.json')
        shutil.copy2(ROOT / 'schemas/extension.schema.json', resources / 'extension.schema.json')
        for binary in ['dotfiles-control-center', 'dotfiles-utility', 'dotfiles-service-runner']:
            shutil.copy2(binaries / binary, macos / binary)
        shutil.copytree(ROOT / 'utility-catalog', resources / 'Utilities')
        clipboard = resources / 'Utilities/dotfiles.markdown-clipboard.dotutility/bin'
        clipboard.mkdir(exist_ok=True)
        pandoc = dependencies.bundle_pandoc(ROOT, clipboard.parent, platform.machine(), args.dependency_cache.resolve(),
                                            args.pandoc_artifact.resolve() if args.pandoc_artifact else None)
        (resources / 'dependencies.json').write_text(json.dumps([pandoc], indent=2) + '\n')
        run('xcrun','swiftc','-O','-target',f'{platform.machine()}-apple-macosx13.0',ROOT/'modules/markdown-clipboard/src/main.swift','-o',clipboard/'markdown-clipboard')
        for package in sorted((resources/'Utilities').glob('*.dotutility')):
            subprocess.run([str(macos/'dotfiles-utility'),'check',str(package)], check=True, stdout=subprocess.DEVNULL)
        plist = {
            'CFBundleIdentifier':'dev.dotfiles.ControlCenter',
            'CFBundleName':'Dotfiles', 'CFBundleDisplayName':'Dotfiles',
            'CFBundleExecutable':'dotfiles-control-center', 'CFBundlePackageType':'APPL',
            'CFBundleShortVersionString':version.split('-')[0],
            'CFBundleVersion':version.split('-dev.')[-1] if '-dev.' in version else version.split('-')[0],
            'DotfilesReleaseVersion':version, 'LSMinimumSystemVersion':'13.0',
            'NSHighResolutionCapable':True,
        }
        (app/'Contents/Info.plist').write_bytes(plistlib.dumps(plist))
        for binary in [clipboard/'pandoc',clipboard/'markdown-clipboard',macos/'dotfiles-service-runner',macos/'dotfiles-utility',macos/'dotfiles-control-center']:
            run('codesign','--force','--options','runtime','--sign',args.sign,binary)
        pandoc['bundledSHA256'] = hashlib.sha256((clipboard/'pandoc').read_bytes()).hexdigest()
        (resources / 'dependencies.json').write_text(json.dumps([pandoc], indent=2) + '\n')
        run('codesign','--force','--options','runtime','--sign',args.sign,app)
        run('codesign','--verify','--deep','--strict',app)
        destination = output/'Dotfiles.app'
        if destination.exists():
            # This directory is a generated artifact, not an installed app.
            if not (destination/'Contents/Info.plist').exists():
                raise SystemExit(f'Refusing to replace unexpected directory: {destination}')
            shutil.rmtree(destination)
        shutil.copytree(app,destination)
    archive = output/f'Dotfiles-{version}.zip'
    if args.pandoc_artifact:
        source = args.pandoc_artifact.resolve()/pandoc['sourceMaterialsArchive']
        destination = output/pandoc['sourceMaterialsArchive']
        if source != destination: shutil.copy2(source,destination)
        if dependencies.sha256(destination) != pandoc['sourceMaterialsSHA256']:
            raise SystemExit('Source materials changed during app packaging')
        destination.with_suffix('.zip.sha256').write_text(f'{pandoc["sourceMaterialsSHA256"]}  {destination.name}\n')
    run('ditto','-c','-k','--sequesterRsrc','--keepParent',output/'Dotfiles.app',archive)
    digest=hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n')
    (output/'build.json').write_text(json.dumps({'version':version,'sourceCommit':source_commit,'sourceDirty':source_dirty,
        'architecture':platform.machine(),'buildOS':platform.mac_ver()[0],'minimumMacOS':'13.0',
        'signing':'development' if args.sign=='-' else 'developer-id','notarized':False,'archive':archive.name,'sha256':digest,
        'dependencies':[pandoc], 'supportMatrix':json.loads((ROOT/'release/support-matrix.json').read_text())},indent=2)+'\n')
    print(f'Built {output / "Dotfiles.app"}')
    if args.sign=='-': print('Development build: public distribution still requires Developer ID signing and notarization.')

if __name__=='__main__':main()
