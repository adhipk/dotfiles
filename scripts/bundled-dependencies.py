"""Pinned build-time inputs. Runtime never invokes a package manager."""
import hashlib
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

def bundle_pandoc(root, package, architecture, cache):
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
            'source': f'https://github.com/jgm/pandoc/tree/{PANDOC_VERSION}',
            'binaryURL': url, 'archiveSHA256': PANDOC_SHA256[architecture], 'license': 'GPL-2.0-or-later'}
