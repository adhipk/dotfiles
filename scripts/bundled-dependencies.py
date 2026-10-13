"""Pinned build-time inputs. Runtime never invokes a package manager."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import urllib.request
import zipfile

PANDOC_VERSION = '3.12.1'
PANDOC_SHA256 = {
    'arm64': 'c2146cf33a583f3ac93eccddf1bb662371d5cfcce1aad1c87ad860cca1435d46',
    'x86_64': '81ed3e2cfecf096df15d407152f89a684fd65221082b919963f738e977fad3bc',
}
OWN_BUILD_RECIPES = ['prepare-pandoc-toolchain.py', 'capture-pandoc-closure.py',
                     'build-pandoc-from-source.py', 'inventory-pandoc-runtime-source.py',
                     'package-pandoc-source-build.py', 'verify-pandoc-source-binary.py']

def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''): digest.update(block)
    return digest.hexdigest()

def safe_material_path(name):
    path = Path(name)
    if path.is_absolute() or '..' in path.parts or '\\' in name or not name or name != path.as_posix():
        raise ValueError('Unsafe source artifact file path: ' + name)
    return path

def validate_source_binary(root, binary, expected):
    spec = importlib.util.spec_from_file_location('pandoc_source_verifier', root/'scripts/verify-pandoc-source-binary.py')
    verifier = importlib.util.module_from_spec(spec); spec.loader.exec_module(verifier)
    return verifier.validate(binary, expected)

def inspect_own_artifact(root, artifact, architecture):
    """Bind inputs, captured sources, recipes and validation to one raw binary."""
    pins = json.loads((root/'release/vendor/pandoc-source/own-build-inputs.json').read_text())
    metadata = json.loads((artifact/'own-build.json').read_text())
    if architecture not in pins['toolchains'] or metadata.get('architecture') != architecture:
        raise ValueError('Source-built Pandoc architecture differs from app')
    expected = {'producer':'dotfiles-pinned-source-build','pandocVersion':pins['pandocVersion'],
                'sourceCommit':pins['pandocCommit'],'ghcVersion':pins['ghcVersion'],
                'cabalVersion':pins['cabalVersion'],'indexState':pins['indexState']}
    if any(metadata.get(key) != value for key,value in expected.items()):
        raise ValueError('Source-built Pandoc producer/source/toolchain pins differ')
    if metadata.get('captureStatus') != 'source-captured-review-required':
        raise ValueError('Source capture status must retain pending review')
    archive_name = metadata.get('sourceMaterialsArchive')
    if archive_name != f'pandoc-own-source-{architecture}.zip':
        raise ValueError('Packaged source materials archive is required')
    for name,checksum in metadata.get('files',{}).items():
        path = artifact/safe_material_path(name)
        if path.is_symlink() or not path.is_file() or sha256(path) != checksum:
            raise ValueError('Own-build artifact file checksum differs: ' + name)
    binary = artifact/'pandoc'
    raw = metadata.get('binarySHA256')
    if not raw or sha256(binary) != raw: raise ValueError('Raw Pandoc checksum differs')
    archive = artifact/archive_name
    if sha256(archive) != metadata.get('sourceMaterialsSHA256'):
        raise ValueError('Source materials archive checksum differs')
    toolchain = json.loads((artifact/'toolchain.json').read_text())
    if (toolchain.get('architecture') != architecture or toolchain.get('inputs') != pins['toolchains'][architecture]
        or toolchain.get('ghcVersion') != pins['ghcVersion'] or toolchain.get('cabalVersion') != pins['cabalVersion']):
        raise ValueError('Captured toolchain inputs differ from pins')
    if json.loads((artifact/'own-build-inputs.json').read_text()) != pins:
        raise ValueError('Captured build input pins differ')
    recipes = {}
    for name in OWN_BUILD_RECIPES:
        if (artifact/name).read_bytes() != (root/'scripts'/name).read_bytes():
            raise ValueError('Captured builder recipe differs: '+name)
        recipes[name] = sha256(artifact/name)
    recipes['own-build-inputs.json'] = sha256(artifact/'own-build-inputs.json')
    validation = json.loads((artifact/'standalone-validation.json').read_text())
    if (validation.get('rawBinarySHA256') != raw or validation.get('architecture') != architecture
        or validation.get('htmlToGFM') != 'passed' or validation.get('isolatedEnvironment') != 'passed'):
        raise ValueError('Bound standalone validation is required')
    with zipfile.ZipFile(archive) as source:
        names = source.namelist()
        if len(names) != len(set(names)): raise ValueError('Duplicate source archive entries')
        for name in names:
            safe_material_path(name)
            if not name.startswith('materials/'): raise ValueError('Unexpected source archive root')
        materials = json.loads(source.read('materials/source-materials.json'))
        if materials.get('captureStatus') != 'source-captured-review-required':
            raise ValueError('Source materials capture review remains required')
        if any(materials.get(key) != metadata.get(key) for key in [*expected,'architecture','binarySHA256']):
            raise ValueError('Source materials identity differs from raw binary build')
        files = materials.get('files',{})
        required = set(OWN_BUILD_RECIPES + ['own-build-inputs.json','toolchain.json','standalone-validation.json',
                       'pandoc-source.tar.gz','ghc-source.tar.xz','closure/closure.json','runtime-source-inventory.json'])
        if not required.issubset(files): raise ValueError('Source materials are missing required captured inputs')
        if set(names) != {'materials/'+name for name in files} | {'materials/source-materials.json'}:
            raise ValueError('Source archive file inventory differs')
        for name,checksum in files.items():
            safe_material_path(name)
            digest = hashlib.sha256()
            with source.open('materials/'+name) as entry:
                for block in iter(lambda:entry.read(1024*1024),b''): digest.update(block)
            if digest.hexdigest() != checksum or sha256(artifact/name) != checksum:
                raise ValueError('Captured source archive member differs: '+name)
        if files['pandoc-source.tar.gz'] != pins['pandocSourceSHA256'] or files['ghc-source.tar.xz'] != pins['ghcSourceSHA256']:
            raise ValueError('Root/compiler source archive pins differ')
    actual = validate_source_binary(root,binary,raw)
    if actual.get('architecture') != architecture or actual.get('rawBinarySHA256') != raw:
        raise ValueError('Fresh standalone validation differs from artifact')
    return {'name':'pandoc','version':pins['pandocVersion'],'architecture':architecture,
            'producer':metadata['producer'],'sourceCommit':pins['pandocCommit'],
            'source':f'https://github.com/jgm/pandoc/tree/{pins["pandocCommit"]}',
            'sourceMaterialsArchive':archive_name,'sourceMaterialsSHA256':metadata['sourceMaterialsSHA256'],
            'rawBinarySHA256':raw,'recipeSHA256':recipes,'toolchain':toolchain['inputs'],
            'ghcVersion':pins['ghcVersion'],'cabalVersion':pins['cabalVersion'],'indexState':pins['indexState'],
            'captureStatus':materials.get('captureStatus','source-captured-review-required'),
            'buildExecutionURL':metadata.get('buildExecutionURL'),'license':'GPL-2.0-or-later'}

def bundle_pandoc(root, package, architecture, cache, artifact=None):
    if artifact is not None:
        metadata = inspect_own_artifact(root,artifact,architecture)
        target = package/'bin/pandoc'; target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(artifact/'pandoc',target)
        if sha256(target) != metadata['rawBinarySHA256']: raise ValueError('Raw binary changed during packaging')
        target.chmod(0o755)
        shutil.copytree(root/'release/vendor/pandoc',package/'licenses/pandoc')
        return metadata
    if architecture not in PANDOC_SHA256:
        raise ValueError('Unsupported Pandoc architecture: ' + architecture)
    filename = f'pandoc-{PANDOC_VERSION}-{architecture}-macOS.zip'
    url = f'https://github.com/jgm/pandoc/releases/download/{PANDOC_VERSION}/{filename}'
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / filename
    if not archive.exists():
        temporary = archive.with_suffix('.download')
        try:
            with urllib.request.urlopen(url, timeout=120) as response, temporary.open('wb') as output:
                shutil.copyfileobj(response, output)
            if hashlib.sha256(temporary.read_bytes()).hexdigest() != PANDOC_SHA256[architecture]:
                raise ValueError('Pandoc download checksum mismatch')
            temporary.replace(archive)
        finally:
            temporary.unlink(missing_ok=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != PANDOC_SHA256[architecture]:
        raise ValueError('Cached Pandoc checksum mismatch; remove the corrupt archive and retry')
    target = package / 'bin/pandoc'
    target.parent.mkdir(parents=True, exist_ok=True)
    # Read only this explicit member; upstream archive contains symlink aliases.
    with zipfile.ZipFile(archive) as source:
        with source.open(f'pandoc-{PANDOC_VERSION}-{architecture}/bin/pandoc') as binary, target.open('wb') as output:
            shutil.copyfileobj(binary, output)
    target.chmod(0o755)
    version = subprocess.check_output([str(target), '--version'], text=True).splitlines()[0]
    if version != f'pandoc {PANDOC_VERSION}':
        raise ValueError('Bundled Pandoc version does not match pin')
    libraries = subprocess.check_output(['otool', '-L', str(target)], text=True)
    if any('/opt/homebrew/' in line or '/usr/local/' in line for line in libraries.splitlines()):
        raise ValueError('Pandoc has an external Homebrew runtime dependency')
    shutil.copytree(root / 'release/vendor/pandoc', package / 'licenses/pandoc')
    return {'name': 'pandoc', 'version': PANDOC_VERSION, 'architecture': architecture,
            'producer':'upstream-official-binary','captureStatus':'upstream-corresponding-source-review-required',
            'rawBinarySHA256':sha256(target),
            'source': f'https://github.com/jgm/pandoc/tree/{PANDOC_VERSION}',
            'binaryURL': url, 'archiveSHA256': PANDOC_SHA256[architecture], 'license': 'GPL-2.0-or-later'}
