#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
xcrun swiftc "$root/src/main.swift" -o "$tmp/worker"
"$tmp/worker" --self-test "$(command -v pandoc)"

# Exercise launchd lifecycle in a temporary HOME with launchctl mocked.
mkdir -p "$tmp/home/.config/markdown-clipboard" "$tmp/bin"
cp "$root/src/main.swift" "$tmp/home/.config/markdown-clipboard/main.swift"
cat > "$tmp/bin/launchctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HOME/launchctl.calls"
MOCK
chmod +x "$tmp/bin/launchctl"
HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$root/bin/markdown-clipboard" start
python3 - "$tmp/home" <<'CHECK'
import pathlib, plistlib, sys
home = pathlib.Path(sys.argv[1])
plist = home / 'Library/LaunchAgents/com.dotfiles.markdown-clipboard.plist'
config = plistlib.loads(plist.read_bytes())
assert config['KeepAlive'] and config['RunAtLoad']
assert pathlib.Path(config['ProgramArguments'][0]).is_file()
assert pathlib.Path(config['ProgramArguments'][1]).is_file()
assert 'bootstrap gui/' in (home / 'launchctl.calls').read_text()
CHECK
HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$root/bin/markdown-clipboard" stop
[[ ! -e "$tmp/home/Library/LaunchAgents/com.dotfiles.markdown-clipboard.plist" ]]
[[ ! -e "$tmp/home/.local/state/markdown-clipboard/worker" ]]
echo 'PASS: install and teardown lifecycle'
