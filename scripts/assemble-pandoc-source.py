#!/usr/bin/env python3
"""Assemble checksum-pinned PARTIAL upstream source materials; never claim a complete GPL source closure."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def declared_dependencies(text):
    """Report Cabal declarations/ranges verbatim; not resolved versions or a build lock."""
    blocks = []
    lines = text.splitlines()
    for index, line in enumerate(lines):
        match = re.match(r'^(\s*)build-depends\s*:\s*(.*)', line)
        if not match:
            continue
        indent = len(match[1]); content = [match[2]]
        for continuation in lines[index + 1:]:
            if not continuation.strip() or continuation.lstrip().startswith('--'):
                continue
            spacing = len(continuation) - len(continuation.lstrip())
            if spacing <= indent or re.match(r'^\s*[\w-]+\s*:', continuation):
                break
            content.append(continuation.strip())
        blocks.extend(part.strip() for part in ' '.join(content).split(',') if part.strip())
    return sorted(set(blocks))


def assemble(archive, destination, provenance, provenance_doc):
    if digest(archive) != provenance['sourceSHA256']:
        raise ValueError('Source archive checksum differs from checked-in pin')
    if destination.exists() or destination.with_suffix('.zip').exists():
        raise ValueError('Refusing to overwrite existing source materials directory')
    prefix = 'pandoc-' + provenance['sourceCommit'] + '/'
    requested = provenance['recipes'] + provenance['packageDescriptions'] + provenance['notices']
    inventory = {}
    with tarfile.open(archive, 'r:gz') as source:
        members = {m.name: m for m in source.getmembers()}
        snapshots = {}
        for relative in requested:
            if relative.startswith('/') or '..' in Path(relative).parts:
                raise ValueError('Unsafe source manifest path')
            member = members.get(prefix + relative)
            if member is None or not member.isfile():
                raise ValueError('Required release source file missing: ' + relative)
            snapshots[relative] = source.extractfile(member).read()
            if relative in provenance['packageDescriptions']:
                inventory[relative] = declared_dependencies(snapshots[relative].decode())
    destination.mkdir(parents=True)
    source_name = f"pandoc-{provenance['version']}-{provenance['sourceCommit']}.tar.gz"
    shutil.copy2(archive, destination / source_name)
    for relative, contents in snapshots.items():
        target = destination / 'upstream' / relative
        target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(contents)
    shutil.copy2(provenance_doc, destination / 'SOURCE_PROVENANCE.md')
    (destination / 'declared-dependencies.json').write_text(json.dumps({'scope':'Direct declared dependency ranges; NOT resolved transitive closure or proof of official binary inputs','packages':inventory}, indent=2)+'\n')
    record = dict(provenance, assembledSourceArchive=source_name, files={str(p.relative_to(destination)):digest(p) for p in sorted(destination.rglob('*')) if p.is_file()})
    (destination / 'materials-manifest.json').write_text(json.dumps(record, indent=2)+'\n')
    bundle = destination.with_suffix('.zip')
    if bundle.exists():
        raise ValueError('Refusing to overwrite existing source-materials ZIP')
    with zipfile.ZipFile(bundle, 'w', compression=zipfile.ZIP_DEFLATED) as output:
        for path in sorted(destination.rglob('*')):
            if path.is_file(): output.write(path, str(path.relative_to(destination.parent)))
    bundle.with_suffix('.zip.sha256').write_text(f'{digest(bundle)}  {bundle.name}\n')
    return bundle


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, help='Use a previously downloaded checksum-pinned archive')
    parser.add_argument('--output', type=Path, default=ROOT / 'dist/pandoc-source-materials')
    parser.add_argument('--require-complete', action='store_true', help='Fail until exact corresponding-source evidence is available')
    args = parser.parse_args()
    provenance = json.loads((ROOT / 'release/vendor/pandoc-source/provenance.json').read_text())
    doc = ROOT / 'release/vendor/pandoc-source/SOURCE_PROVENANCE.md'
    if args.archive:
        bundle = assemble(args.archive, args.output, provenance, doc)
    else:
        with tempfile.TemporaryDirectory(prefix='pandoc-source-download-') as temporary:
            archive = Path(temporary) / 'source.tar.gz'
            with urllib.request.urlopen(provenance['sourceURL'], timeout=120) as response, archive.open('wb') as output:
                shutil.copyfileobj(response, output)
            bundle = assemble(archive, args.output, provenance, doc)
    print(f'Assembled PARTIAL source materials: {bundle}')
    print('Incomplete official-binary dependency/build provenance; public corresponding-source acceptance remains blocked.')
    if args.require_complete:
        raise SystemExit('Blocked: ' + '; '.join(provenance['missingEvidence']))


if __name__ == '__main__': main()
