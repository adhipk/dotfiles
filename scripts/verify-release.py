#!/usr/bin/env python3
"""Fail closed on candidate provenance, Apple verification, and recorded desktop acceptance."""
import argparse
import ast
import plistlib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def require(condition, message):
    if not condition:
        raise ValueError(message)


def evidence(record, label):
    require(isinstance(record, dict) and record.get('status') == 'passed', f'{label}: not passed')
    require(isinstance(record.get('evidence'), str) and record['evidence'].strip(), f'{label}: evidence required')


def validate_acceptance(data, matrix, metadata, architecture):
    require(data.get('schemaVersion') == 1, 'Unsupported acceptance schema')
    require(data.get('sourceCommit') == metadata['sourceCommit'], 'Acceptance commit differs from artifact')
    require(data.get('version') == metadata['version'], 'Acceptance version differs from artifact')
    ci = data.get('ci', {})
    require(ci.get('sourceCommit') == metadata['sourceCommit'] and ci.get('status') == 'passed', 'Successful CI for candidate commit required')
    require(re.fullmatch(r'https://github\.com/[^/]+/[^/]+/actions/runs/\d+', ci.get('runURL', '')), 'CI run URL required')
    require(set(ci.get('requiredChecks', [])) >= {'Native app and extension contracts', 'Existing integration contracts'}, 'Both CI tiers required')
    for check in matrix['requiredLicenseChecks']:
        evidence(data.get('licenses', {}).get(check), f'License {check}')
    devices = [d for d in data.get('devices', []) if d.get('architecture') == architecture]
    require(len(devices) == 1, f'Exactly one clean-device acceptance record required for {architecture}')
    device = devices[0]
    require(device.get('cleanDevice') is True and device.get('tester', '').strip(), 'Clean device and named tester required')
    os_version = device.get('macOS', '')
    require(re.fullmatch(r'\d+\.\d+(?:\.\d+)?', os_version) is not None, 'Recorded macOS version required')
    require(tuple(map(int, os_version.split('.'))) >= tuple(map(int, matrix['minimumMacOS'].split('.'))), 'Unsupported macOS version')
    require(device.get('artifactSHA256') == metadata['sha256'], 'Acceptance is for a different downloaded artifact')
    for check in matrix['requiredDesktopChecks']:
        evidence(device.get('desktopChecks', {}).get(check), f'{architecture} desktop {check}')
    for utility in matrix['requiredUtilities']:
        evidence(device.get('utilities', {}).get(utility), f'{architecture} utility {utility}')
    for module in matrix['requiredModules']:
        evidence(device.get('modules', {}).get(module), f'{architecture} module {module}')


def validate_support_matrix(matrix):
    defaults = (ROOT / 'home/.chezmoidata/10-modules.yaml').read_text()
    flags = dict(re.findall(r'^  (\w+):\n    enabled: (true|false)$', defaults, re.M))
    required, excluded = set(), set()
    for manifest in (ROOT / 'modules').glob('*/module.yaml'):
        text = manifest.read_text()
        identifier = re.search(r'^id: (.+)$', text, re.M)
        key = re.search(r'^dataKey: modules\.(.+)$', text, re.M)
        require(identifier is not None and key is not None, f'Unrecognized module manifest: {manifest}')
        require(key[1] in flags, f'Explicit checked-in module enablement required: {key[1]}')
        (required if flags[key[1]] == 'true' else excluded).add(identifier[1])
    require(required == set(matrix.get('requiredModules', [])), 'Support matrix omits enabled desktop/terminal modules')
    require(excluded == set(matrix.get('excludedModules', {})), 'Dormant exclusions differ from checked-in defaults')
    ids = {json.loads(p.read_text())['id'] for p in (ROOT / 'utility-catalog').glob('*/extension.json')}
    require(ids == set(matrix['requiredUtilities']), 'Support matrix differs from full utility catalog')


def verify_remote_ci(ci, commit):
    match = re.fullmatch(r'https://github\.com/([^/]+)/([^/]+)/actions/runs/(\d+)', ci.get('runURL', ''))
    require(match is not None, 'CI run URL required')
    owner, repository, run_id = match.groups()
    endpoint = f'repos/{owner}/{repository}/actions/runs/{run_id}'
    remote = json.loads(run('gh', 'api', endpoint))
    require(remote.get('head_sha') == commit and remote.get('status') == 'completed' and remote.get('conclusion') == 'success', 'Remote CI does not confirm successful exact candidate commit')
    require(remote.get('path') == '.github/workflows/validate.yml', 'CI evidence must come from the Validate workflow')
    pages = json.loads(run('gh', 'api', '--paginate', '--slurp', endpoint + '/jobs?per_page=100'))
    successful = {job['name'] for page in pages for job in page.get('jobs', []) if job.get('conclusion') == 'success'}
    require(successful >= {'Native app and extension contracts', 'Existing integration contracts'}, 'Remote CI lacks successful required tiers')


def run(*args):
    return subprocess.check_output(list(map(str, args)), text=True, stderr=subprocess.STDOUT).strip()


def validate_archive_binding(app, metadata, matrix):
    resources = app / 'Contents/Resources'
    plist = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    require(plist.get('DotfilesReleaseVersion') == metadata['version'], 'Archived plist release version differs')
    require(plist.get('CFBundleShortVersionString') == metadata['version'].split('-')[0], 'Archived plist short version differs')
    require(plist.get('LSMinimumSystemVersion') == metadata.get('minimumMacOS') == matrix['minimumMacOS'], 'Archived minimum macOS differs')
    archived_dependencies = json.loads((resources / 'dependencies.json').read_text())
    require(archived_dependencies == metadata.get('dependencies'), 'Archived dependencies differ from metadata')
    # Read only literal pin declarations; never run build-time download code in verification.
    pins = {}
    for node in ast.parse((ROOT / 'scripts/bundled-dependencies.py').read_text()).body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id in ['PANDOC_VERSION', 'PANDOC_SHA256']:
                    pins[target.id] = ast.literal_eval(node.value)
    require(len(archived_dependencies) == 1 and archived_dependencies[0].get('name') == 'pandoc', 'Expected exactly pinned Pandoc dependency')
    dep = archived_dependencies[0]; architecture = metadata['architecture']; version = pins['PANDOC_VERSION']
    require(dep.get('version') == version and dep.get('architecture') == architecture, 'Bundled dependency version/architecture differs from pins')
    require(dep.get('archiveSHA256') == pins['PANDOC_SHA256'][architecture], 'Bundled dependency source archive pin differs')
    require(dep.get('binaryURL') == f'https://github.com/jgm/pandoc/releases/download/{version}/pandoc-{version}-{architecture}-macOS.zip' and dep.get('source') == f'https://github.com/jgm/pandoc/tree/{version}' and dep.get('license') == 'GPL-2.0-or-later', 'Dependency source/license binding differs')
    package = resources / 'Utilities/dotfiles.markdown-clipboard.dotutility'
    require(dep.get('bundledSHA256') == hashlib.sha256((package / 'bin/pandoc').read_bytes()).hexdigest(), 'Signed bundled dependency digest differs')
    source_notices = ROOT / 'release/vendor/pandoc'
    bundled_notices = package / 'licenses/pandoc'
    expected = {p.relative_to(source_notices):p.read_bytes() for p in source_notices.rglob('*') if p.is_file()}
    actual = {p.relative_to(bundled_notices):p.read_bytes() for p in bundled_notices.rglob('*') if p.is_file()}
    require(expected and actual == expected, 'Bundled dependency notices differ from source')


def validate_source_materials(provenance, materials):
    require(provenance.get('completeness') == 'complete' and not provenance.get('missingEvidence'), 'Official Pandoc corresponding-source evidence remains incomplete; partial source materials do not authorize publication')
    require(materials is not None, 'Complete corresponding-source materials ZIP required')
    closure = provenance.get('resolvedSourceClosure', [])
    bindings = provenance.get('binaryBuildBindings', {})
    require(closure and set(bindings) == set(provenance['officialBinaryArchiveSHA256']), 'Resolved source closure and both binary build bindings required')
    with zipfile.ZipFile(materials) as source:
        manifests = [name for name in source.namelist() if name.endswith('/materials-manifest.json')]
        require(len(manifests) == 1, 'Exactly one source materials manifest required')
        manifest_name = manifests[0]; prefix = manifest_name.rsplit('/', 1)[0] + '/'
        record = json.loads(source.read(manifest_name))
        require(all(record.get(key) == value for key, value in provenance.items()), 'Source materials provenance differs from checked-in source record')
        files = record.get('files', {})
        require(files and set(source.namelist()) == {prefix + name for name in files} | {manifest_name}, 'Source material file inventory differs')
        for name, checksum in files.items():
            require(not name.startswith('/') and '..' not in Path(name).parts, 'Unsafe source material path')
            require(hashlib.sha256(source.read(prefix + name)).hexdigest() == checksum, 'Source material digest differs: ' + name)
        source_archive = record.get('assembledSourceArchive')
        require(files.get(source_archive) == provenance['sourceSHA256'], 'Pinned top-level source archive missing from materials')
        names = set()
        for package in closure:
            require(package.get('name') and package.get('version') and package.get('license') and package.get('sourceURL'), 'Resolved package identity/license/source required')
            require(package['name'] not in names, 'Duplicate resolved package source')
            names.add(package['name'])
            require(files.get(package.get('archive')) == package.get('sha256') and re.fullmatch(r'[0-9a-f]{64}', package.get('sha256', '')), 'Resolved dependency source archive missing or unbound')
        for architecture, binding in bindings.items():
            require(binding.get('archiveSHA256') == provenance['officialBinaryArchiveSHA256'][architecture], 'Source build binding differs from shipped binary pin')
            require(binding.get('sourceCommit') == provenance['sourceCommit'], 'Source build binding commit differs')
            require(binding.get('buildExecutionURL') and all(binding.get(key) for key in ['ghcVersion','cabalVersion','macOSSDK','indexState']), 'Exact binary build/toolchain/index provenance required')
            require(binding.get('freezeFile') in files and binding.get('planFile') in files, 'Recorded binary freeze/plan files required')
            require(set(binding.get('sourcePackages', [])) == names, 'Binary source package closure differs from assembled sources')


def verify_artifact(dist, args, matrix):
    dist = dist.resolve()
    metadata = json.loads((dist / 'build.json').read_text())
    require(metadata.get('sourceDirty') is False, 'Dirty-source builds cannot be release candidates')
    require(re.fullmatch(r'[0-9a-f]{40}', metadata.get('sourceCommit', '')), 'Full source commit required')
    require(run('git', '-C', ROOT, 'rev-parse', 'HEAD') == metadata['sourceCommit'], 'Checkout differs from build commit')
    require(not run('git', '-C', ROOT, 'status', '--porcelain'), 'Release verification requires a clean checkout')
    require(metadata.get('signing') == 'developer-id', 'Developer ID signing required')
    require(metadata['version'] == (ROOT / 'VERSION').read_text().strip(), 'VERSION differs from artifact')
    require(metadata.get('architecture') in matrix['architectures'], 'Unsupported architecture')
    require(metadata.get('supportMatrix') == matrix, 'Build support matrix differs from release policy')
    archive_name = metadata.get('archive', '')
    require(archive_name == f"Dotfiles-{metadata['version']}.zip", 'Unexpected archive filename')
    archive = dist / archive_name
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    require(digest == metadata.get('sha256'), 'Artifact checksum differs from build metadata')
    require(archive.with_suffix('.zip.sha256').read_text().strip() == f'{digest}  {archive.name}', 'Checksum file differs from artifact')
    # Verify what recipients extract, not a separately mutable build-directory app.
    with tempfile.TemporaryDirectory(prefix='dotfiles-release-verify-') as temporary:
        run('ditto', '-x', '-k', archive, temporary)
        app = Path(temporary) / 'Dotfiles.app'
        run('codesign', '--verify', '--deep', '--strict', app)
        signature = run('codesign', '-d', '--verbose=4', app)
        require('Authority=Developer ID Application:' in signature and 'TeamIdentifier=' in signature, 'Apple Developer ID certificate required')
        for binary in ['Contents/MacOS/dotfiles-control-center', 'Contents/MacOS/dotfiles-utility', 'Contents/MacOS/dotfiles-service-runner', 'Contents/Resources/Utilities/dotfiles.markdown-clipboard.dotutility/bin/pandoc', 'Contents/Resources/Utilities/dotfiles.markdown-clipboard.dotutility/bin/markdown-clipboard']:
            require(metadata['architecture'] in run('lipo', '-archs', app / binary).split(), f'Archived {binary} architecture differs from metadata')
        validate_archive_binding(app, metadata, matrix)
        resources = app / 'Contents/Resources'
        require(json.loads((resources / 'support-matrix.json').read_text()) == matrix, 'Archived support matrix differs')
        ids = {json.loads(p.read_text())['id'] for p in (resources / 'Utilities').glob('*/extension.json')}
        require(ids == set(matrix['requiredUtilities']), 'Archived catalog does not cover every required utility')
        for document in ['LICENSE', 'NOTICE', 'THIRD_PARTY_NOTICES.md']:
            require((resources / document).is_file(), f'Archived {document} required')
            require((resources / document).read_bytes() == (ROOT / document).read_bytes(), f'Archived {document} differs from source')
        if not args.candidate:
            require(re.fullmatch(r'\d+\.\d+\.\d+', metadata['version']), 'Stable publication requires a stable VERSION')
            source_provenance = json.loads((ROOT / 'release/vendor/pandoc-source/provenance.json').read_text())
            validate_source_materials(source_provenance, args.source_materials)
            require(metadata.get('notarized') is True, 'Recorded notarization required')
            receipt = json.loads((dist / 'notarization.json').read_text())
            require(receipt.get('status') == 'Accepted' and receipt.get('id'), 'Apple Accepted notarization receipt required')
            require(metadata.get('notarizationID') == receipt['id'], 'Notarization receipt differs from metadata')
            run('xcrun', 'stapler', 'validate', app)
            run('spctl', '--assess', '--type', 'execute', '--verbose', app)
            require(args.acceptance is not None, 'Clean-device acceptance JSON required for publication')
            acceptance = json.loads(args.acceptance.read_text())
            validate_acceptance(acceptance, matrix, metadata, metadata['architecture'])
            verify_remote_ci(acceptance['ci'], metadata['sourceCommit'])
    return metadata['architecture']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dist', type=Path, action='append', help='Repeat for each required architecture')
    parser.add_argument('--acceptance', type=Path)
    parser.add_argument('--source-materials', type=Path, help='Complete checksum-bound corresponding-source distribution ZIP')
    parser.add_argument('--candidate', action='store_true', help='Verify clean signed candidate before notarization; does not authorize publication')
    args = parser.parse_args()
    matrix = json.loads((ROOT / 'release/support-matrix.json').read_text())
    validate_support_matrix(matrix)
    destinations = args.dist or [ROOT / 'dist']
    if not args.candidate:
        require(len(destinations) == len(matrix['architectures']), 'Final release gate requires one --dist for every supported architecture')
    architectures = [verify_artifact(dist, args, matrix) for dist in destinations]
    if not args.candidate:
        require(len(set(architectures)) == len(architectures) and set(architectures) == set(matrix['architectures']), 'Final release must include every supported architecture exactly once')
    print('PASS: clean signed candidate' if args.candidate else 'PASS: all supported artifacts and recorded acceptance; manual publication remains explicit')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        sys.exit(f'Release blocked: {error}')
