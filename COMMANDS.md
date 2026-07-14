# Command and Utility Reference

This repository is a chezmoi source state for a macOS workstation. Files under
`home/bin/` are parent integration points that become commands or symlinks in
`~/bin`. Files under `home/dot_config/` are installed below `~/.config/`.

## Installed Commands

These commands are installed into `~/bin`, which `home/dot_zshrc` adds to
`PATH`.

| Command | Purpose | Source |
| --- | --- | --- |
| `projects` | Disabled by default; when explicitly enabled, installs the project hub. The source CLI remains manually runnable. | [`modules/projects/bin/projects`](modules/projects/bin/projects) |
| `projects-pick` | Disabled companion for `projects pick`. | [`modules/projects/bin/projects-pick`](modules/projects/bin/projects-pick) |
| `bookmarks` | Legacy space bookmarks (superseded by `projects`). | [`modules/space-display/bin/bookmarks`](modules/space-display/bin/bookmarks) |
| `default-apps` | Inspect and change macOS default handlers for file extensions and URL schemes. | [`adhipk/macos-default-apps`](https://github.com/adhipk/macos-default-apps) |
| `dotfiles-control-center` | Open the native module, dependency, and backed-up uninstall manager. | [`modules/dotfiles-control-center/bin/dotfiles-control-center`](modules/dotfiles-control-center/bin/dotfiles-control-center) |
| `dotfiles-deps` | Aggregate dependency status, manager update checks, reproducible snapshots, and safe immutable Git-pin enforcement. | [`modules/dependencies/bin/dotfiles-deps`](modules/dependencies/bin/dotfiles-deps) |
| `dotfiles-module` | Validate modules and plan or execute enable, disable, uninstall, and purge lifecycle actions. | [`modules/module-lifecycle/bin/dotfiles-module`](modules/module-lifecycle/bin/dotfiles-module) |
| `dotfiles-uninstall` | Plan, execute, or restore a backed-up whole-system dotfiles removal. | [`modules/system-uninstall/bin/dotfiles-uninstall`](modules/system-uninstall/bin/dotfiles-uninstall) |
| `gh-create-repo` | Edit repository settings as YAML, then run the matching `gh repo create` command. | [`adhipk/gh-create-repo`](https://github.com/adhipk/gh-create-repo) |
| `man-me` | Generate a categorized reference for personal commands, bins, shell functions, and desktop helpers. | [`home/bin/executable_man-me`](home/bin/executable_man-me) |
| `kit` | Speak text with KittenTTS, either from arguments or stdin, and optionally write WAV output. | [`adhipk/kittentts-cli`](https://github.com/adhipk/kittentts-cli) |
| `kit-watch` | Watch a text file with `fswatch` and read its contents with `kit` whenever it changes. | [`adhipk/kittentts-cli`](https://github.com/adhipk/kittentts-cli) |
| `lucide-icons-excalidraw` | Start the external Raycast development command for the Lucide Excalidraw picker. Additional arguments are passed to the Raycast extension's `npm run dev`. | [`home/bin/executable_lucide-icons-excalidraw.tmpl`](home/bin/executable_lucide-icons-excalidraw.tmpl) |
| `reload-colors` | Restart yabai and skhd, then reload tmux configuration when tmux is running. | [`home/bin/executable_reload-colors`](home/bin/executable_reload-colors) |
| `reset-yabai` | Reinstall and pin the yabai formula declared by `Brewfile`, then delegate checksum-scoped scripting-addition setup. This uses `sudo` and changes Homebrew packages and `/etc/sudoers.d/yabai`. | [`modules/space-display/bin/reset-yabai`](modules/space-display/bin/reset-yabai) |
| `shortcut-catalog` | Regenerate or verify deterministic JSON/Markdown from rendered desired-state skhd bindings and module owners. | [`modules/shortcut-guide/bin/shortcut-catalog`](modules/shortcut-guide/bin/shortcut-catalog) |
| `setup-yabai-sa` | Authorize the currently installed yabai binary with a checksum-scoped sudoers rule, load its scripting addition, and restart the service after the required SIP setup. | [`modules/space-display/bin/setup-yabai-sa`](modules/space-display/bin/setup-yabai-sa) |
| `todo` | Open Tuxedo on `./todo.txt`, or run a Tuxedo CLI command against the current working directory's task file with serialized agent writes. | [`adhipk/tuxedo-project-todo`](https://github.com/adhipk/tuxedo-project-todo) |
| `tmux-session-picker` | Open sesh's built-in interactive picker for existing tmux sessions. | [`modules/tmux-sessions/bin/tmux-session-picker`](modules/tmux-sessions/bin/tmux-session-picker) |
| `tmux-session-template` | Apply and navigate the standard `terminal:0`, `codex:1`, `nvim:2`, `tuxedo:3`, `awrit:4` tmux window types. The canonical Awrit slot is lazy; only explicit Awrit `new`/`duplicate` actions start its native renderer in the pane. The new-session hook calls guarded `auto`, scratchpads call `ensure`, and `duplicate` keeps the source pane's directory. | [`modules/terminal-window-types/bin/tmux-session-template`](modules/terminal-window-types/bin/tmux-session-template) |
| `tmux-workspace` | Validate, plan, open, apply, or explicitly repair import-free React-like `.tmux.tsx` session layouts while preserving healthy running panes. | [`modules/tmux-sessions/bin/tmux-workspace`](modules/tmux-sessions/bin/tmux-workspace) |
| `tmux-sessionizer-zoxide` | Open sesh's built-in picker for existing tmux sessions, configured sessions, and zoxide-ranked directories. | [`modules/tmux-sessions/bin/tmux-sessionizer-zoxide`](modules/tmux-sessions/bin/tmux-sessionizer-zoxide) |
| `tmux-sessionizer` | Compatibility wrapper for `-s <index>` and sesh's built-in interactive picker. | [`modules/tmux-sessions/bin/tmux-sessionizer`](modules/tmux-sessions/bin/tmux-sessionizer) |
| `unescape-buffer` | Read escaped text from stdin and write unescaped newlines, tabs, carriage returns, quotes, and backslashes to stdout. Implemented in Node.js. | [`adhipk/unescape-cli`](https://github.com/adhipk/unescape-cli) |
| `unescape-string` | Read escaped text from stdin and write an unescaped version to stdout. Implemented with `sed`. | [`adhipk/unescape-cli`](https://github.com/adhipk/unescape-cli) |
| `watch-sync` | Watch the chezmoi source state with `fswatch` and apply it after changes. | [`home/bin/executable_watch-sync`](home/bin/executable_watch-sync) |

The five GitHub utility projects in [External Projects](#external-projects) own
their command implementations, behavior tests, releases, and standalone
install/uninstall scripts. Chezmoi owns their pinned checkouts and conditional
`~/bin` symlinks; it does not run the upstream installers or copy the commands.

### default-apps

```bash
default-apps
default-apps list
default-apps get .md .txt
default-apps .pdf
default-apps get ./notes/example.md
default-apps set .md Obsidian
default-apps set .md /Applications/Obsidian.app
default-apps set .md md.obsidian
default-apps set https: Safari
default-apps --help
```

`set` accepts an application name, an application path, or a bundle ID. It
requires `duti`, which is installed from the `Brewfile`.

### man-me

```bash
man-me
man-me hotkeys
man-me tmux
man-me --category terminal
man-me --source "$PWD"
man-me --all
```

`man-me` prints a generated local command reference grouped by category. It
parses `man-me:` metadata comments from command sources and parent-owned module
catalog files, then falls back to discovered executable names when metadata is
absent.
Positional arguments run a free-text search across command names, usage,
descriptions, paths, and tags; `man-me hotkeys` shows the keyboard shortcut and
skhd helper surface. It uses `rg` when available, falls back to `fzf` or shell
matching, uses installed paths by default, switches to source mode when run from
this checkout, and includes an `--all` option for missing catalog entries.

### gh-create-repo

```bash
gh-create-repo
```

The command opens a temporary `gh-repo-create.yml` in `$VISUAL`, `$EDITOR`, or
`nvim`. After you save and quit, it validates the YAML and runs `gh repo create`
with the selected visibility, description, README, gitignore, license, source,
remote, and push options. It requires `gh` and `yq`, both installed from the
`Brewfile`.

### todo.txt

```bash
todo
todo ls --json
todo add "(B) 2026-07-10 Implement the outcome +dotfiles @agent id:UUID owner:codex"
todo do 1
todo archive
```

With no arguments, `todo` opens Tuxedo's TUI on `./todo.txt`. Arguments are
passed to Tuxedo's todo.txt-compatible CLI with `TODO_DIR`, `TODO_FILE`, and
`DONE_FILE` resolved from the current working directory. The wrapper initializes
that directory's task files and holds an agent-write lock around CLI operations.
Completed entries stay in `todo.txt` until `todo archive` is run explicitly.
The command implementation and its locking tests live in the pinned
`tuxedo-project-todo` checkout; these dotfiles own only the two links used by
`todo` and native `chezmoi todo` dispatch.

### Text Unescaping

```bash
printf 'line one\\nline two\\tvalue\\n' | unescape-buffer
printf 'line one\\nline two\\tvalue\\n' | unescape-string
```

### Text To Speech

```bash
kit "Read this aloud"
kit -v Luna -s 1.1 "Read this with Luna"
kit --backend chatterbox --voice-ref ~/voices/reference.wav "Read this with Chatterbox Turbo"
kit-watch notes.md
kit-watch --tail notes.md
kit-watch draft.md -- -v Bella --stream-threshold 100
kit-watch --tail draft.md -- --backend chatterbox --voice-ref ~/voices/reference.wav
kit-watch --no-initial notes.md
```

`kit-watch --tail FILE` reads the whole file once on startup, then reads only
newly appended text after each change. Combine it with `--no-initial` to start
watching at the current end of the file.

`kit --backend chatterbox` runs Resemble AI Chatterbox Turbo lazily through
`uv` and keeps KittenTTS as the default backend. Chatterbox is intended for
higher quality voice-cloned readback and accepts a reference WAV with
`--voice-ref`. Command behavior and model integration are tested in the
`kittentts-cli` project; the local `kit-tts` module tests only the ChezMoi link
and removal boundary.

## Shell Commands

[`home/dot_config/zsh/zshrc.commands`](home/dot_config/zsh/zshrc.commands)
defines these shell functions:

| Function | Usage | Purpose |
| --- | --- | --- |
| `daemon` | `daemon NAME COMMAND [ARG ...]` | Run a background command with `nohup`, write `/tmp/NAME.log` and `/tmp/NAME.pid`, and create a `daemon-NAME` tmux session that tails the log. |
| `tms` | `tms [SESSION] [DIRECTORY]` | Create a detached tmux session without switching to it. The defaults are the current directory name and current directory. |

[`home/dot_zshrc`](home/dot_zshrc) adds the `y [ARG ...]` shell function, which
runs Yazi and changes the parent shell to Yazi's final directory on exit. Use
the `todo` wrapper so Tuxedo resolves task files from the active directory.

It also defines convenience aliases:

| Alias | Expands to |
| --- | --- |
| `python` | `python3` |
| `ports` | `sudo lsof -i -n -P \| grep LISTEN` |
| `ta` | `tmux attach -t` |
| `tad` | `tmux attach -d -t` |
| `ts` | `tmux new-session -s` |
| `tl` | `tmux list-sessions` |
| `tksv` | `tmux kill-server` |
| `tkss` | `tmux kill-session -t` |
| `roigin` | `origin` |

The shell binds `Alt+f` to `tmux-sessionizer-zoxide` and `Alt+e` to
`tmux-session-picker`; both open sesh's built-in picker instead of maintaining
separate `sesh list | fzf` pipelines. Chezmoi installs the shared sesh settings
at `~/.config/sesh/sesh.toml`.
`Alt+h`, `Alt+t`, `Alt+n`, and `Alt+s` use `tmux-sessionizer -s 0..3`, and this repository
includes a `tmux-sessionizer` wrapper that maps those slots to `sesh`.

Ordinary sessions created by raw `tmux`, `ts`, `tms`, or `sesh` receive the
same four-window template as the terminal scratchpads: `terminal` at `0`,
`codex` at `1`, `nvim` at `2`, and `tuxedo` at `3`. A session created with an explicit command
is preserved as-is. Compound/orchestrated creators that add their own windows
or queue index-targeted tmux commands must opt out on their `new-session` call
with `-e DOTFILES_TMUX_TEMPLATE=skip`; `hs-*` sessions are also excluded.

`tmux-workspace open project --root DIR` builds the managed project layout from
`~/.config/tmux/layouts/project.tmux.tsx`. The custom Bun JSX runtime supports
local reusable components plus `Session`, `Window`, `Terminal`, `Codex`,
`Nvim`, `Cols`, `Rows`, and `Pane` without React or a package install. Repeated
`apply` is non-destructive; structural drift requires `repair --yes`, and a
same-named unmanaged session requires explicit `--adopt`. Layout files are
trusted local code: component definitions run during load, while pane `run`
commands start only when their pane is created.

## Repository Commands

Run `./bootstrap.sh` on a new Mac. It installs Homebrew when needed, installs
the `Brewfile` (including Bun, Python, Tuxedo, and the Codex CLI/app), delegates the
chezmoi apply to `./install.sh`, installs the TPM-managed tmux plugins and
repo-owned command center, clones and pins declared utility projects under
`~/projects`, builds the shortcut guide, and starts the yabai and skhd launch
services.

Run `./install.sh [CHEZMOI APPLY ARG ...]` to apply this checkout. Arguments are
passed through to `chezmoi apply`. A real apply also installs declared tmux
plugins, reloads an existing tmux server, signals every running Ghostty process
(including the scratchpad instance) to reload its configuration, and rebuilds
the shortcut guide. For example:

```bash
./install.sh --dry-run
DOTFILES_DEBUG=1 ./install.sh
```

[`Makefile`](Makefile) provides these wrappers:

| Command | Purpose |
| --- | --- |
| `make` or `make help` | List available targets. |
| `make test` | Run all test suites. |
| `make test-colorscheme` | Run colorscheme tests. |
| `make test-configs` | Run skhd and yabai configuration tests. |
| `make test-todo` | Run canonical todo.txt wrapper and concurrency tests. |
| `make test-tmux-session-template` | Run the isolated tmux template lifecycle tests. |
| `make test-tmux-workspace` | Run the React-like layout lifecycle tests. |
| `make test-tmux-which-key` | Build and exercise the repo-owned tmux command center. |
| `make test-tmux-persistence` | Run an isolated Resurrect save/kill/restore round-trip. |
| `make test-whichkey` | Build and exercise the shortcut-guide parser and search model. |
| `make test-shortcut-guide` | Validate the transportable shortcut-guide module and deterministic generated catalog. |
| `make test-control-center` | Validate the native control-center boundary and command execution safety. |
| `make test-source-state` | Run chezmoi source-state tests. |
| `make test-install` | Run disposable installer tests. |
| `make test-integration` | Run workstation integration tests. |
| `make install`, `make apply`, `make compile`, `make sync` | Apply chezmoi source state, install tmux plugins, create `~/projects`, and build the shortcut guide. |
| `make apply-debug` | Apply the source state with verbose chezmoi output. |
| `make diff` | Preview chezmoi-managed changes. |
| `make watch` | Run `watch-sync`. |
| `make reload` | Run `reload-colors`. |
| `make build-projectdeck`, `make build-whichkey` | Build and install the native project picker or shortcut guide. |
| `make shortcuts-update`, `make shortcuts-check` | Regenerate or read-only verify the checked shortcut JSON and Markdown. |
| `make clean` | Remove top-level `*.tmp` and `*.log` files. |

The test runner is [`tests/run_all_tests.sh`](tests/run_all_tests.sh). Its
individual suites are `test_colorscheme.sh`, `test_configs.sh`,
`test_projects.sh`, `test_todo.sh`, `test_tmux_session_template.sh`, `test_tmux_workspace.sh`, `test_tmux_which_key.sh`, `test_tmux_persistence.sh`, `test_tmux_border_accent.sh`, `test_tmux_yazi_pane.sh`,
`test_whichkey.sh`, `test_source_state.sh`,
`test_default_apps.sh`, `test_install.sh`, and `test_integration.sh`.

## Desktop Helpers

These helpers are installed for skhd and yabai. They are implementation
details, but each can also be run directly from its installed path.

### skhd Helpers

Installed below `~/.config/skhd/`:

| Helper | Purpose |
| --- | --- |
| [`app-mru.sh`](modules/app-focus/bin/app-mru.sh) | Track and cycle non-scratchpad application windows in most-recently-used order. Updated on `window_focused` via yabai. |
| [`focus_app.sh APP`](modules/app-focus/bin/focus_app.sh) | Focus, MRU-cycle, or launch an application. `@browser` resolves the macOS HTTPS handler, `@editor` uses the standard app-focus TOML default, and terminal fallback creates a normal window instead of activating a scratchpad. |
| [`hotkeys`](modules/app-focus/bin/hotkeys) | Route the app-focus, presentation, zen, and normal-terminal actions. Zen mode blocks the configured slots `3..5`; terminal, browser, and editor focus remain active. New terminal windows are pinned back to the originating yabai display and space. |
| [`media_key.sh ACTION`](home/dot_config/skhd/executable_media_key.sh) | Send a macOS media key event. Supported actions are `brightness_down`, `brightness_up`, `mission_control`, `launchpad`, `dictation`, `do_not_disturb`, `previous`, `play_pause`, `next`, `mute`, `volume_down`, and `volume_up`. |
| [`open_terminal_window.sh`](home/dot_config/skhd/executable_open_terminal_window.sh) | Open a terminal window on the current yabai space. `TERMINAL_APP` defaults to `Ghostty`. The active binding uses `hotkeys terminal new`. |
| [`show_keys.sh`](modules/shortcut-guide/bin/show_keys.sh) | Open, close, or toggle the interactive shortcut guide. It lazily rebuilds the native app when its source is newer or the installed binary is missing. |
| [`notify.sh TITLE MESSAGE`](home/dot_config/skhd/executable_notify.sh) | Show a macOS notification from skhd or yabai helpers. Uses `terminal-notifier` when available. |
| [`snap_window.sh left\|right`](modules/window-layout/bin/snap_window.sh) | Warp the current window and resize it to half the display width. |
| [`toggle_ghostty_quick_terminal.sh`](modules/scratchpads/bin/toggle_ghostty_quick_terminal.sh) | Create or toggle a bottom-third Ghostty scratchpad named `quick_terminal`. |
| [`scratchpads`](modules/scratchpads/bin/scratchpads) | Manage one floating Ghostty terminal scratchpad while switching between separate tmux sessions. Scratchpads are borderless, opaque black panels with balanced terminal padding, rounded corners, and a native shadow; normal Ghostty windows keep the global transparency and tmux-colored border. `scratchpads open codex` targets `dotfiles`; `scratchpads open projects` targets `projects`. Both tmux sessions keep `terminal` at window `0`, `codex` at `1`, `nvim` at `2`, `tuxedo` at `3`, and lazy `awrit` at `4` when the optional terminal-window-types module is enabled. |
| [`tmux-border-accent`](modules/appearance-pip/bin/tmux-border-accent) | Start JankyBorders with the tiled-layout geometry, synchronize normal focused Ghostty borders with their tmux session accent, and keep exact yabai scratchpad window IDs transparent. |
| [`tmux-workspace`](modules/tmux-sessions/bin/tmux-workspace) | Reconcile stable session/window/pane IDs from managed `.tmux.tsx` layouts. New sessions skip the automatic template; healthy panes and their commands survive repeated applies. |
| [`tmux-yazi-pane`](modules/tmux-yazi/bin/tmux-yazi-pane) | Toggle one marked full-height Yazi side pane per tmux window. |
| [`whichkey`](modules/shortcut-guide/app/WhichKey.swift) | Module-owned SwiftUI shortcut browser. It parses rendered desired-state skhd bindings, searches by key chord or text, exports ownership metadata, and keeps raw commands in a separate detail pane. Built locally to `~/.config/skhd/whichkey`. |

### yabai Helpers

Installed below `~/.config/yabai/`:

| Helper | Purpose |
| --- | --- |
| [`projectdeck`](modules/projects/projectdeck/ProjectDeck.swift) | Dormant SwiftUI project-context picker. Build it explicitly with `make build-projectdeck`; normal install/bootstrap does not activate it. |
| [`projects`](modules/projects/bin/projects) | Source CLI for dormant project-context actions (`pick`, `new`, `adopt`, `focus-project`, `focus-space`, `cycle`, etc.). It is not installed while the module is disabled. |
| [`bookmarks`](modules/space-display/bin/bookmarks-store) | Legacy pinned spaces (superseded by `projects`). |
| [`float-prefs`](modules/window-layout/bin/float-prefs) | Toggle float for the focused window and remember it per app/title via yabai `manage=off` rules. |
| [`tile-pip-window`](modules/appearance-pip/bin/tile-pip-window) | Turn macOS Picture-in-Picture windows into normal managed yabai tiles. |
| [`create-space`](modules/space-display/bin/create-space) | Create and focus a space, optionally moving a focused non-scratchpad window. |
| [`display-move`](modules/space-display/bin/display-move) | Move the focused window to the previous or next display and preserve focus. |
| [`close_empty_spaces.sh`](modules/space-display/bin/close-empty-spaces) | Destroy empty yabai spaces while retaining at least one space. |

Dormant project data is preserved at `~/.config/yabai/projects.json`; no global shortcut or focus signal updates it.
Bookmarks are stored at `~/.config/yabai/space-bookmarks.json`.
Floating window preferences are stored at `~/.config/yabai/floating-windows.json`.

## Desktop Shortcuts

[`home/dot_skhdrc.tmpl`](home/dot_skhdrc.tmpl) wires the desktop helpers and yabai
operations to these shortcuts:

| Shortcut | Action |
| --- | --- |
| `Alt+Tab`, `Alt+Shift+Tab` | Cycle stacked windows forward or backward. |
| `Ctrl+Alt+Left/Right`, `Ctrl+Alt+h/k` | Snap a window to the left or right half. |
| `Ctrl+Alt+Shift+Arrows`, `Ctrl+Alt+Shift+h/k/u/j` | Swap windows by direction. |
| `Alt+Shift+Arrows`, `Alt+Shift+h/k/u/j` | Resize the current macOS window by 100 pixels. |
| `Ctrl+Alt+Return` | Toggle full-screen zoom. |
| `Ctrl+Alt+s`, `Ctrl+Alt+b`, `Ctrl+Alt+o`, `Ctrl+Alt+x/y` | Toggle split, balance, rotate, or mirror the layout. |
| `Ctrl+Alt+f`, `Ctrl+Alt+d`, `Ctrl+Alt+g` | Toggle remembered float (per app/title), stack west, or toggle BSP/stack layout. |
| `Alt+Shift+[` / `Alt+Shift+]` | Move the current window to the previous or next display. |
| Hyper | Reserved and intentionally unbound; ProjectDeck/project-context shortcuts are dormant. |
| `Ctrl+Alt+n` | Move the current window to a new labeled space. |
| `Alt+n` | Create and focus a new space, moving the focused non-scratchpad window there only when another non-scratchpad window remains on the current space. |
| `Alt+k` | Close empty spaces. |
| `Alt+Backtick`, `Alt+1..4` | Focus Ghostty, the default browser, the configured editor, Teams, or Slack. Repeat to MRU-cycle that app's non-scratchpad windows only. |
| `Fn+Comma` | Open the opaque black terminal scratchpad and switch its tmux client to `dotfiles`, with `terminal`, `codex`, `nvim`, `tuxedo`, and `awrit` windows. |
| `Fn+1` | Open the same opaque black terminal scratchpad and switch its tmux client to `projects`, with `terminal`, `codex`, `nvim`, `tuxedo`, and `awrit` windows. |
| `Cmd+Backtick`, `Cmd+1`, `Cmd+2`, `Cmd+3` in Ghostty | Cycle `terminal`, `codex`, `nvim`, or `tuxedo` tmux windows by type, including renamed duplicates. |
| `Cmd+B`, `Cmd+Shift+B` in Ghostty | Toggle one Yazi side pane or open/select its dedicated tmux window in the active directory. |
| `Right Cmd+D` in Ghostty | Duplicate the current typed tmux window in the same directory; copies receive `terminal-2`, `codex-2`, `nvim-2`, `tuxedo-2`, and advancing suffixes. |
| `Right Cmd+R/S/Space` in Ghostty | Rename the current window, open sesh, or open the tmux command center. The same right-side chords pass through normally outside Ghostty. |
| `Ctrl+0/1/2/3` in tmux | Cycle windows tagged as `terminal`, `codex`, `nvim`, or `tuxedo`, including manually renamed duplicates. |
| `Ctrl+Shift+0/1/2/3` in tmux | Create a `terminal`, `codex`, `nvim`, or `tuxedo` window in the current pane's directory and switch to it. |
| `Ctrl+4..9` in tmux | Select the exact tmux window index. |
| `Ctrl+A L` in tmux | Switch through tmux's per-client session history; session closure keeps clients attached to a surviving session rather than detaching them. |
| `Ctrl+A Space` in tmux | Open the repo-owned command center for sessions, windows, panes, persistence, copy mode, and declarative layouts. |
| `Alt+Shift+Backtick` | Create a new terminal window on the focused space. |
| `Alt+Shift+Backslash` | Toggle zen mode. Terminal focus plus `Alt+1` browser and `Alt+2` editor focus still work; the configured slots `3..5` are disabled (`Alt+5` is currently unbound). |
| `Ctrl+Alt+w`, `Ctrl+Alt+z` | Close or minimize the current window. |
| `Alt+r` | Restart yabai and skhd. |
| `Alt+/` | Toggle the non-activating shortcut guide. A bare key finds every shortcut ending in it. Internal controls use otherwise-unbound Option chords: `Option+Up/Down` browse, `Option+Left/Right` categories, `Option+F/P` text/key search, `Option+C` clear, and `Esc` or `Option+/` close. |

Experimental hyper bindings, including hyperspace session slots and the
Spotlight scratchpad shortcut, are kept in
[`modules/hyperspace/targets/hyperspace.skhdrc`](modules/hyperspace/targets/hyperspace.skhdrc)
and are not loaded by default.

## Configuration Utilities

| Source | Purpose |
| --- | --- |
| [`home/dot_config/colorschemes/executable_catppuccin-mocha.sh`](home/dot_config/colorschemes/executable_catppuccin-mocha.sh) | Export the shared Catppuccin Mocha color palette, border colors, and `COLORS_JSON`. |
| [`home/dot_config/colorschemes/symlink_colors.sh`](home/dot_config/colorschemes/symlink_colors.sh) | Select `catppuccin-mocha.sh` as `~/.config/colorschemes/colors.sh`. |
| [`home/dot_config/tmux/executable_colors.sh`](home/dot_config/tmux/executable_colors.sh) | Source the selected colorscheme for tmux-related scripts. |
| [`home/dot_config/tmux/colors.conf`](home/dot_config/tmux/colors.conf) | Apply the Catppuccin Mocha palette to tmux. |
| [`modules/tmux-sessions/config/sesh.toml`](modules/tmux-sessions/config/sesh.toml) | Configure the built-in sesh picker shared by Ghostty, tmux, and shell session selectors. |
| [`home/dot_config/yazi/init.lua`](home/dot_config/yazi/init.lua) | Keep zoxide's directory database updated while navigating in Yazi. |
| [`home/dot_config/yazi/keymap.toml`](home/dot_config/yazi/keymap.toml) | Add Yazi shortcuts: `!` opens a shell, `Esc` closes input, and `g r` jumps to the current Git root. |

The main [`home/dot_yabairc.tmpl`](home/dot_yabairc.tmpl) composes modular BSP
tiling, appearance, fixed-space, signal, and scripting-addition policy.
[`home/dot_tmux.conf.tmpl`](home/dot_tmux.conf.tmpl) configures tmux
and is documented further in [`TMUX_GUIDE.md`](TMUX_GUIDE.md).

## Chezmoi Automation

| Hook | Purpose |
| --- | --- |
| [`run_onchange_after_install-vscodium-extensions.sh.tmpl`](home/.chezmoiscripts/run_onchange_after_install-vscodium-extensions.sh.tmpl) | Install declared VSCodium extensions with `codium --install-extension --force` whenever the generated hook changes. |
| [`run_once_install-vscodium-cli.sh.tmpl`](home/.chezmoiscripts/run_once_install-vscodium-cli.sh.tmpl) | Symlink the `codium` CLI into `~/.local/bin` after VSCodium is installed. |
| [`run_after_sync-chrome-extensions.sh.tmpl`](home/.chezmoiscripts/run_after_sync-chrome-extensions.sh.tmpl) | Build declared Chrome extension repositories after their Git revision changes or their unpacked manifest is missing. |
| [`run_after_sync-external-projects.sh.tmpl`](home/.chezmoiscripts/run_after_sync-external-projects.sh.tmpl) | Run only explicitly declared setup commands after an external project's Git revision changes or generated paths go missing. |

[`home/.chezmoidata.toml`](home/.chezmoidata.toml) contains the extension
inventory. [`home/.chezmoiexternal.toml.tmpl`](home/.chezmoiexternal.toml.tmpl)
clones declared Chrome extension repositories into
`~/.local/share/chrome-extensions/` and generic external projects into their
declared paths.

## Source-Only Utilities

These scripts are present in the repository but are not installed by chezmoi:

| Command | Purpose |
| --- | --- |
| [`commands/mark`](commands/mark) `TEXT` | Append a line to `~/notes/marks.md`. |
| [`commands/show_mark`](commands/show_mark) | Print `~/notes/marks.md` when it exists. |

## External Projects

Five reusable command projects are declared as ChezMoi `git-repo` externals and
locked to immutable commits. The project repositories own implementation,
behavior tests, releases, and standalone lifecycle; the dotfiles modules own
only catalog metadata, conditional path adapters, and parent lifecycle tests.

| GitHub project | Pinned checkout | Commands | Parent adapter |
| --- | --- | --- | --- |
| [`adhipk/kittentts-cli`](https://github.com/adhipk/kittentts-cli) | `~/projects/kittentts-cli` | `kit`, `kit-watch` | [`modules/kit-tts`](modules/kit-tts) |
| [`adhipk/tuxedo-project-todo`](https://github.com/adhipk/tuxedo-project-todo) | `~/projects/tuxedo-project-todo` | `todo`, `chezmoi-todo` | [`modules/todo`](modules/todo) |
| [`adhipk/macos-default-apps`](https://github.com/adhipk/macos-default-apps) | `~/projects/macos-default-apps` | `default-apps` | [`modules/macos-default-apps`](modules/macos-default-apps) |
| [`adhipk/gh-create-repo`](https://github.com/adhipk/gh-create-repo) | `~/projects/gh-create-repo` | `gh-create-repo` | [`modules/gh-create-repo`](modules/gh-create-repo) |
| [`adhipk/unescape-cli`](https://github.com/adhipk/unescape-cli) | `~/projects/unescape-cli` | `unescape-buffer`, `unescape-string` | [`modules/unescape-cli`](modules/unescape-cli) |

The exact pins live in [`home/.chezmoidata.toml`](home/.chezmoidata.toml) and
the central dependency inventory. Disabling or uninstalling one of these
modules removes its ChezMoi-owned links without running the project's
uninstaller. Whole-system dotfiles removal follows the same boundary: managed
links are removed and the useful project checkouts under `~/projects` remain.

### Other external projects

`raycast-lucide-excalidraw` is also declared as an external project repo
in [`home/.chezmoidata.toml`](home/.chezmoidata.toml). Chezmoi clones it into
`~/.local/share/raycast-extensions/raycast-lucide-excalidraw`, installs its npm
dependencies, and runs its setup command during bootstrap.

Run the Raycast extension package commands from
`~/.local/share/raycast-extensions/raycast-lucide-excalidraw/projects/raycast-extension/`:

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start Raycast development mode. |
| `npm run build` | Build the Raycast command. |
| `npm run lint` | Run Raycast linting. |
| `npm run fix-lint` | Fix lint issues where possible. |
| `npm run publish` | Publish through the Raycast API. |

Run `npm --prefix ~/.local/share/raycast-extensions/raycast-lucide-excalidraw/projects/excalidraw-library run generate`
to regenerate `projects/excalidraw-library/library/lucide-icons.excalidrawlib`.

The declared Chrome external is `gemma-gem`, an unpacked browser extension
built from source into
`~/.local/share/chrome-extensions/gemma-gem/.output/chrome-mv3-dev`. After the
external has been cloned, its package commands include:

| Command | Purpose |
| --- | --- |
| `pnpm dev`, `pnpm dev:firefox` | Start WXT development mode for Chrome or Firefox. |
| `pnpm build`, `pnpm build:prod`, `pnpm build:firefox` | Build development, production, or Firefox variants. |
| `pnpm zip`, `pnpm zip:firefox` | Package Chrome or Firefox builds. |
| `pnpm compile` | Run TypeScript checking without emitting files. |
| `pnpm postinstall` | Prepare WXT metadata. This runs automatically after dependency installation. |
