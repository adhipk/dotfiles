# External Projects

Tools in this repository often start as small scripts under `home/bin/` or
`scripts/`. When they grow into real projects — CLIs, browser apps, Raycast
extensions, libraries — they belong in their own Git repositories. Dotfiles
should only **declare**, **clone**, **build**, and **wire** them on a machine.

This document describes the two-step pattern:

1. **Track separately** — register the tool as an external project while source
   may still live in dotfiles or in a sibling checkout.
2. **Extract** — move implementation into the dedicated repo; leave shims and
   machine wiring here.

## What stays in dotfiles

Keep only machine setup and thin integration:

- Shell, window manager, editor, keyboard, and theme configuration
- Chezmoi inventory in `home/.chezmoidata.toml`
- Shims in `home/bin/` that `exec` into installed project binaries
- Symlinks into small repo-local scripts when appropriate
  (`home/bin/symlink_default-apps.tmpl` → `scripts/default-apps.sh`)
- skhd/yabai/tmux bindings that *call* external commands
- Personal agent defaults under `home/dot_agents/` that are not product code

Do **not** keep growing application source, server runtimes, HTML component
libraries, or product documentation in dotfiles once the tool has a named
project boundary.

## When to split

Treat a helper as an external project when any of these apply:

- It has its own build step (`pnpm build`, `make`, compiled output)
- It is useful outside your macOS setup (other people, CI, other machines)
- It has tests, releases, or multiple contributors
- It exceeds a few hundred lines or spans multiple files/directories
- Another tool depends on it as a library (for example `agent-comms`)

Small one-off ergonomics (`reload-colors`, `watch-sync`, skhd helpers) can
stay in dotfiles indefinitely.

## Phase 1 — Track separately

Register the project before or during extraction so dotfiles already knows
where the tool lives and how to install it.

### 1. Pick a checkout path

Use a stable path under `$HOME`:

| Kind | Typical path |
| --- | --- |
| CLI / app | `~/.local/share/<name>` |
| Raycast extension | `~/.local/share/raycast-extensions/<name>` |
| Chrome extension source | `~/.local/share/chrome-extensions/<name>` |
| Shared library | `~/.local/share/<name>` or publish to a package registry |

Existing examples:

```text
~/.local/share/nearly-headless
~/.local/share/raycast-extensions/raycast-lucide-excalidraw
~/.local/share/chrome-extensions/gemma-gem
```

### 2. Declare it in `home/.chezmoidata.toml`

**CLI / app / library** — `[[externalProjects]]`:

```toml
[[externalProjects]]
name = "my-tool"
url = "git@github.com:adhipk/my-tool.git"
refreshPeriod = "24h"
path = ".local/share/my-tool"
requiredExecutables = ["node", "pnpm"]
rerunWhenMissingPaths = [
    "node_modules",
    "bin/my-tool",
]
setupCommands = [
    "pnpm install --frozen-lockfile",
    "pnpm build",
]
```

**Chrome extension built from source** — `[[chromeExtensions]]`:

```toml
[[chromeExtensions]]
name = "my-extension"
url = "git@github.com:adhipk/me-my-extension.git"
refreshPeriod = "168h"
packageManager = "pnpm"
installCommand = "pnpm install --frozen-lockfile"
buildCommand = "pnpm build"
unpackedPath = ".output/chrome-mv3-dev"
```

Chezmoi clones both kinds through `home/.chezmoiexternal.toml.tmpl` as
`git-repo` externals. You do not edit that template per project — add entries
to `.chezmoidata.toml` only.

### 3. Rely on the generic setup hooks

After `chezmoi apply`, these scripts run automatically:

| Hook | Purpose |
| --- | --- |
| `run_after_sync-external-projects.sh.tmpl` | Runs `setupCommands` when the Git revision changes or expected build outputs are missing |
| `run_after_sync-chrome-extensions.sh.tmpl` | Installs and builds declared Chrome extensions |

Both store revision stamps under
`~/.local/state/chezmoi/external-projects/` and
`~/.local/state/chezmoi/chrome-extensions/` so rebuilds are idempotent.

### 4. Add a shim command in dotfiles

Dotfiles installs `home/bin/executable_<name>` as `~/bin/<name>`. For external
projects, the shim should only locate and exec the project binary:

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${MY_TOOL_PROJECT_DIR:-$HOME/.local/share/my-tool}"
BIN="${MY_TOOL_BIN:-$PROJECT_DIR/bin/my-tool}"

if [ -x "$BIN" ]; then
  exec "$BIN" "$@"
fi

cat >&2 <<EOF
my-tool is not installed.

Expected binary:
  $BIN

Source repository:
  git@github.com:adhipk/my-tool.git

After chezmoi apply, run:
  cd $PROJECT_DIR
  pnpm install --frozen-lockfile
  pnpm build
EOF
exit 127
```

Reference implementation: `home/bin/executable_nearly-headless`.

Optional compatibility aliases can forward to the shim:

```bash
#!/usr/bin/env bash
set -euo pipefail
exec nearly-headless "$@"
```

Reference: `home/bin/executable_headless-artifacts`.

### 5. Document the command

Add a row to [COMMANDS.md](COMMANDS.md) noting that dotfiles installs a shim
and where the real project lives.

### 6. Add source-state tests

Extend `tests/test_source_state.sh` so regressions are caught:

- `.chezmoidata.toml` contains the project name and Git URL
- Shim file exists and references the external checkout path
- Generic external hooks still exist (no per-project hook scripts)

Run `make test` before merging.

### 7. Local development before the repo exists

While prototyping inside dotfiles:

- Keep source in a dedicated directory (for example `extensions/my-tool/`) and
  add that path to `.gitignore` if it is a full Git checkout
- Point the shim's `PROJECT_DIR` override at the prototype:
  `MY_TOOL_PROJECT_DIR=$PWD/extensions/my-tool my-tool …`
- Once the remote exists, declare it in `.chezmoidata.toml` and clone through
  chezmoi instead of vendoring source in dotfiles

## Phase 2 — Extract the implementation

When the tool is registered (Phase 1), move all product code into its repository
and delete it from dotfiles.

### Extraction checklist

```text
[ ] Create GitHub repository (git@github.com:adhipk/<name>.git)
[ ] Move implementation, tests, README, and product docs into the new repo
[ ] Add install/build instructions and a stable CLI entrypoint (bin/<name>)
[ ] Point home/.chezmoidata.toml at the new remote (if not already)
[ ] Replace dotfiles implementation with a shim (Phase 1 step 4)
[ ] Move or drop compatibility aliases; keep old names as thin forwards if needed
[ ] Remove extracted source from dotfiles (do not leave duplicate copies)
[ ] Keep skhd/tmux/yabai bindings here only if they are machine-specific wiring
[ ] Update COMMANDS.md and product docs in the external repo
[ ] Update tests/test_source_state.sh
[ ] Run make test and chezmoi apply on a clean temp home
[ ] On other machines: chezmoi update -v
```

### What moves vs what stays

| Moves to external repo | Stays in dotfiles |
| --- | --- |
| Application/server source | `executable_<name>` shim |
| Build config (`package.json`, `Makefile`, …) | `.chezmoidata.toml` declaration |
| Product README and architecture docs | skhd lines that invoke the command |
| HTML templates, components, skills tied to the product | Personal `~/.agents` defaults unrelated to the product |
| Unit/integration tests for the tool | Brewfile entries for runtime deps (`node`, `pnpm`, …) |
| Published CLI binary or `dist/` output | Machine config the tool reads (`~/.config/<name>/`) if it is user-specific |

Draw explicit boundaries before moving files. Example boundaries already
documented in this repo:

- **Nearly-headless** — browser task workspace, artifact server, live-doc UI.
  See `home/dot_agents/docs/nearly-headless.md`.
- **Hyperspace** — tmux workspace manager only. See
  `home/dot_agents/docs/tmux-session-manager.md`.

Those two projects must not share implementation trees after extraction.

### Rename and path cleanup

Prefer neutral names in the external repo even if dotfiles kept legacy names
during prototyping:

| Legacy in dotfiles | External project |
| --- | --- |
| `hyperspace_server.mjs`, `hyperspace-serve` | `nearly-headless serve` |
| `~/.config/hyperspaces/` (server/runtime) | `~/.config/nearly-headless/` |
| `hyperspace` CLI | tmux manager in `adhipk/hyperspace` (separate repo) |

Keep old command names as compatibility shims for one release cycle when
renaming user-facing entrypoints.

### Wiring-only templates

Some commands need a fixed path to an external checkout but add no logic.
Use a chezmoi template shim:

```bash
#!/usr/bin/env bash
set -euo pipefail

EXTENSION_DIR="$HOME/.local/share/raycast-extensions/my-extension"
if [ ! -d "$EXTENSION_DIR" ]; then
  echo "Checkout missing: $EXTENSION_DIR" >&2
  echo "Run chezmoi apply or ./bootstrap.sh" >&2
  exit 1
fi
cd "$EXTENSION_DIR"
exec npm run dev -- "$@"
```

Reference: `home/bin/executable_lucide-icons-excalidraw.tmpl`.

### Verify extraction

```bash
make test
chezmoi -S "$PWD" diff
chezmoi -S "$PWD" apply

# Shim resolves to external binary
which my-tool
my-tool --help

# External checkout builds on revision change
cd ~/.local/share/my-tool && git pull
chezmoi apply   # reruns setupCommands when HEAD changes
```

## Current inventory

| Project | Remote | Dotfiles role | Extraction status |
| --- | --- | --- | --- |
| nearly-headless | `git@github.com:adhipk/nearly-headless.git` | Shim + agent profile/docs; server still partially in `home/dot_config/hyperspaces/` | In progress |
| raycast-lucide-excalidraw | `git@github.com:adhipk/raycast-lucide-excalidraw.git` | External + dev shim | Extracted |
| gemma-gem | `https://github.com/kessler/gemma-gem.git` (fork planned) | Chrome external; local work under `extensions/` (gitignored) | Track separately → fork |
| hyperspace | (planned `adhipk/hyperspace`) | Full CLI in `home/bin/executable_hyperspace` | Not yet extracted |
| agent-comms | (planned) | Prototype under `extensions/gemma-gem/agent-comms/` | Not yet extracted |
| default-apps | dotfiles `scripts/default-apps.sh` | Symlink from `~/bin` | Optional extract |

Update this table when a project crosses Phase 1 or Phase 2.

## Quick reference — files to touch

| Step | Files |
| --- | --- |
| Declare external | `home/.chezmoidata.toml` |
| Clone on apply | `home/.chezmoiexternal.toml.tmpl` (generic; rarely edited) |
| Build after clone | `run_after_sync-external-projects.sh.tmpl` or `run_after_sync-chrome-extensions.sh.tmpl` (generic) |
| Install command | `home/bin/executable_<name>` or `home/bin/executable_<name>.tmpl` |
| Tests | `tests/test_source_state.sh` |
| User docs | `COMMANDS.md`, project README in external repo |

## Related docs

- [README.md](README.md) — repository layout and bootstrap
- [COMMANDS.md](COMMANDS.md) — installed commands and shortcuts
- `home/dot_agents/docs/nearly-headless.md` — nearly-headless product boundary
- `home/dot_agents/docs/tmux-session-manager.md` — hyperspace product boundary
