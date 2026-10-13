#!/usr/bin/env bash
# Explicit candidate operation; never invoked by personal bootstrap.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
: "${DOTFILES_NOTARY_PROFILE:?Set an existing notarytool Keychain profile}"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-notary.XXXXXX")"
trap 'rm -rf "$temporary"' EXIT
# Snapshot first, then verify and submit that exact archive. Never staple mutable dist app.
cp "$root/dist/build.json" "$temporary/build.json"
version="$(cat "$root/VERSION")"
cp "$root/dist/Dotfiles-$version.zip" "$temporary/"
cp "$root/dist/Dotfiles-$version.zip.sha256" "$temporary/"
python3 - "$root/dist" "$temporary" <<'PY_SOURCE'
import json,shutil,sys
from pathlib import Path
source=Path(sys.argv[1]);destination=Path(sys.argv[2])
metadata=json.loads((destination/'build.json').read_text())
for dependency in metadata.get('dependencies',[]):
    if dependency.get('producer')=='dotfiles-pinned-source-build':
        name=dependency.get('sourceMaterialsArchive','')
        if name!=f"pandoc-own-source-{metadata['architecture']}.zip":raise SystemExit('Unexpected source sidecar filename')
        shutil.copy2(source/name,destination/name)
PY_SOURCE
python3 "$root/scripts/verify-release.py" --candidate --dist "$temporary"
version="$(cat "$root/VERSION")"
archive="$temporary/Dotfiles-$version.zip"
xcrun notarytool submit "$archive" --keychain-profile "$DOTFILES_NOTARY_PROFILE" --wait --output-format json > "$root/dist/notarization.json"
python3 - "$root/dist/notarization.json" <<'PY'
import json,sys
receipt=json.load(open(sys.argv[1]))
if receipt.get('status')!='Accepted' or not receipt.get('id'):
    raise SystemExit('Apple did not accept notarization; inspect dist/notarization.json')
PY
ditto -x -k "$archive" "$temporary/extracted"
xcrun stapler staple "$temporary/extracted/Dotfiles.app"
xcrun stapler validate "$temporary/extracted/Dotfiles.app"
spctl --assess --type execute --verbose "$temporary/extracted/Dotfiles.app"
ditto -c -k --sequesterRsrc --keepParent "$temporary/extracted/Dotfiles.app" "$archive"
if [[ -e "$root/dist/Dotfiles.app" ]]; then mv "$root/dist/Dotfiles.app" "$temporary/previous-app"; fi
ditto "$temporary/extracted/Dotfiles.app" "$root/dist/Dotfiles.app"
cp "$archive" "$root/dist/Dotfiles-$version.zip"
cp "$temporary/build.json" "$root/dist/build.json"
python3 - "$root/dist/Dotfiles-$version.zip" "$root/dist/build.json" "$root/dist/notarization.json" <<'PY'
import hashlib,json,sys
from pathlib import Path
archive=Path(sys.argv[1]);metadata=Path(sys.argv[2]);d=json.loads(metadata.read_text())
d['sha256']=hashlib.sha256(archive.read_bytes()).hexdigest();d['notarized']=True
d['notarizationID']=json.loads(Path(sys.argv[3]).read_text())['id']
archive.with_suffix('.zip.sha256').write_text(f"{d['sha256']}  {archive.name}\n")
metadata.write_text(json.dumps(d,indent=2)+'\n')
PY
