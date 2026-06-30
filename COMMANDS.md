# Command and Utility Reference

This repository is a chezmoi source state for a macOS workstation. Files under
`home/bin/` become commands in `~/bin`. Files under `home/dot_config/` are
installed below `~/.config/`.

## Installed Commands

These commands are installed into `~/bin`, which `home/dot_zshrc` adds to
`PATH`.

| Command | Purpose | Source |
| --- | --- | --- |
| `projects` | Interactive project hub, create/switch/adopt spaces. | [`home/bin/executable_projects`](home/bin/executable_projects) |
| `projects-pick` | Same as `projects pick` (Hyper+p). | [`home/bin/executable_projects-pick`](home/bin/executable_projects-pick) |
| `bookmarks` | Legacy space bookmarks (superseded by `projects`). | [`home/bin/executable_bookmarks`](home/bin/executable_bookmarks) |
| `default-apps` | Inspect and change macOS default handlers for file extensions and URL schemes. | [`scripts/default-apps.sh`](scripts/default-apps.sh) |
| `gh-create-repo` | Edit repository settings as YAML, then run the matching `gh repo create` command. | [`home/bin/executable_gh-create-repo`](home/bin/executable_gh-create-repo) |
| `man-me` | Generate a categorized reference for personal commands, bins, shell functions, and desktop helpers. | [`home/bin/executable_man-me`](home/bin/executable_man-me) |
| `kit` | Speak text with KittenTTS, either from arguments or stdin, and optionally write WAV output. | [`home/bin/executable_kit`](home/bin/executable_kit) |
| `kit-watch` | Watch a text file with `fswatch` and read its contents with `kit` whenever it changes. | [`home/bin/executable_kit-watch`](home/bin/executable_kit-watch) |
| `lucide-icons-excalidraw` | Start the external Raycast development command for the Lucide Excalidraw picker. Additional arguments are passed to the Raycast extension's `npm run dev`. | [`home/bin/executable_lucide-icons-excalidraw.tmpl`](home/bin/executable_lucide-icons-excalidraw.tmpl) |
| `reload-colors` | Restart yabai and skhd, then reload tmux configuration when tmux is running. | [`home/bin/executable_reload-colors`](home/bin/executable_reload-colors) |
| `reset-yabai` | Reinstall and pin `yabai@7.1.16`, update its scripting-addition sudoers entry, and restart its service. This uses `sudo` and changes Homebrew packages and `/etc/sudoers.d/yabai`. | [`home/bin/executable_reset-yabai`](home/bin/executable_reset-yabai) |
| `tmux-session-picker` | Select and switch to an existing tmux session with `sesh` + `fzf`. | [`home/bin/executable_tmux-session-picker`](home/bin/executable_tmux-session-picker) |
| `tmux-sessionizer-zoxide` | Pick from existing tmux sessions or zoxide-ranked directories and connect via `sesh`. | [`home/bin/executable_tmux-sessionizer-zoxide`](home/bin/executable_tmux-sessionizer-zoxide) |
| `tmux-sessionizer` | Compatibility wrapper for `-s <index>` and interactive selection, backed by `sesh`. | [`home/bin/executable_tmux-sessionizer`](home/bin/executable_tmux-sessionizer) |
| `unescape-buffer` | Read escaped text from stdin and write unescaped newlines, tabs, carriage returns, quotes, and backslashes to stdout. Implemented in Node.js. | [`home/bin/executable_unescape-buffer`](home/bin/executable_unescape-buffer) |
| `unescape-string` | Read escaped text from stdin and write an unescaped version to stdout. Implemented with `sed`. | [`home/bin/executable_unescape-string`](home/bin/executable_unescape-string) |
| `watch-sync` | Watch the chezmoi source state with `fswatch` and apply it after changes. | [`home/bin/executable_watch-sync`](home/bin/executable_watch-sync) |

`default-apps` is installed as a symlink by
[`home/bin/symlink_default-apps.tmpl`](home/bin/symlink_default-apps.tmpl).

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
parses `man-me:` metadata comments from the command and helper source files,
then falls back to discovered executable names when metadata is absent.
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
`--voice-ref`.

## Shell Commands

[`home/dot_config/zsh/zshrc.commands`](home/dot_config/zsh/zshrc.commands)
defines these shell functions:

| Function | Usage | Purpose |
| --- | --- | --- |
| `daemon` | `daemon NAME COMMAND [ARG ...]` | Run a background command with `nohup`, write `/tmp/NAME.log` and `/tmp/NAME.pid`, and create a `daemon-NAME` tmux session that tails the log. |
| `tms` | `tms [SESSION] [DIRECTORY]` | Create a detached tmux session without switching to it. The defaults are the current directory name and current directory. |

[`home/dot_zshrc`](home/dot_zshrc) adds the `y [ARG ...]` shell function, which
runs Yazi and changes the parent shell to Yazi's final directory on exit.

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
`tmux-session-picker`; both use `sesh` under the hood.
`Alt+h`, `Alt+t`, `Alt+n`, and `Alt+s` use `tmux-sessionizer -s 0..3`, and this repository
includes a `tmux-sessionizer` wrapper that maps those slots to `sesh`.

## Repository Commands

Run `./bootstrap.sh` on a new Mac. It installs Homebrew when needed, installs
the `Brewfile`, and delegates the chezmoi apply to `./install.sh`.

Run `./install.sh [CHEZMOI APPLY ARG ...]` to apply this checkout. Arguments are
passed through to `chezmoi apply`; for example:

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
| `make test-source-state` | Run chezmoi source-state tests. |
| `make test-install` | Run disposable installer tests. |
| `make test-integration` | Run workstation integration tests. |
| `make install`, `make apply`, `make compile`, `make sync` | Apply the chezmoi source state. |
| `make apply-debug` | Apply the source state with verbose chezmoi output. |
| `make diff` | Preview chezmoi-managed changes. |
| `make watch` | Run `watch-sync`. |
| `make reload` | Run `reload-colors`. |
| `make clean` | Remove top-level `*.tmp` and `*.log` files. |

The test runner is [`tests/run_all_tests.sh`](tests/run_all_tests.sh). Its
individual suites are `test_colorscheme.sh`, `test_configs.sh`,
`test_source_state.sh`, `test_default_apps.sh`, `test_install.sh`, and
`test_integration.sh`.

## Desktop Helpers

These helpers are installed for skhd and yabai. They are implementation
details, but each can also be run directly from its installed path.

### skhd Helpers

Installed below `~/.config/skhd/`:

| Helper | Purpose |
| --- | --- |
| [`app-mru.sh`](home/dot_config/skhd/executable_app-mru.sh) | Track and cycle application windows in most-recently-used order. Updated on `window_focused` via yabai. |
| [`focus_app.sh APP`](home/dot_config/skhd/executable_focus_app.sh) | Focus, MRU-cycle, or launch an application. `@browser` resolves the macOS HTTPS handler and `@editor` uses `EDITOR_APP` (defaults to `VSCodium`). |
| [`hotkeys`](home/bin/executable_hotkeys) | Miscellaneous skhd actions. `hotkeys zen toggle` flips zen mode, where `Alt+1` and terminal focus keep working but `Alt+2..4` do nothing. |
| [`media_key.sh ACTION`](home/dot_config/skhd/executable_media_key.sh) | Send a macOS media key event. Supported actions are `brightness_down`, `brightness_up`, `mission_control`, `launchpad`, `dictation`, `do_not_disturb`, `previous`, `play_pause`, `next`, `mute`, `volume_down`, and `volume_up`. |
| [`open_terminal_window.sh`](home/dot_config/skhd/executable_open_terminal_window.sh) | Open a terminal window on the current yabai space. `TERMINAL_APP` defaults to `Ghostty`. The active binding uses `hotkeys terminal new`. |
| [`show_keys.sh`](home/dot_config/skhd/executable_show_keys.sh) | Toggle the `whichkey` keybinding overlay. |
| [`notify.sh TITLE MESSAGE`](home/dot_config/skhd/executable_notify.sh) | Show a macOS notification from skhd or yabai helpers. Uses `terminal-notifier` when available. |
| [`snap_window.sh left\|right`](home/dot_config/skhd/executable_snap_window.sh) | Warp the current window and resize it to half the display width. |
| [`toggle_ghostty_quick_terminal.sh`](home/dot_config/skhd/executable_toggle_ghostty_quick_terminal.sh) | Create or toggle a bottom-third Ghostty scratchpad named `quick_terminal`. |
| [`whichkey`](home/dot_config/skhd/executable_whichkey) | Compiled arm64 SwiftUI keybinding overlay launched by `show_keys.sh`. |

### yabai Helpers

Installed below `~/.config/yabai/`:

| Helper | Purpose |
| --- | --- |
| [`projectdeck`](scripts/projectdeck/ProjectDeck.swift) | SwiftUI floating project picker. Built to `~/.config/yabai/projectdeck` on `make install`. |
| [`projects`](home/dot_config/yabai/executable_projects) | Project store and actions (`pick`, `new`, `adopt`, `focus-project`, `focus-space`, `cycle`, etc.). |
| [`bookmarks`](home/dot_config/yabai/executable_bookmarks) | Legacy pinned spaces (superseded by `projects`). |
| [`float-prefs`](home/dot_config/yabai/executable_float-prefs) | Toggle float for the focused window and remember it per app/title via yabai `manage=off` rules. |
| [`close_empty_spaces.sh`](home/dot_config/yabai/executable_close_empty_spaces.sh) | Destroy empty yabai spaces while retaining at least one space. |

Projects are stored at `~/.config/yabai/projects.json`.
Bookmarks are stored at `~/.config/yabai/space-bookmarks.json`.
Floating window preferences are stored at `~/.config/yabai/floating-windows.json`.

## Desktop Shortcuts

[`home/dot_skhdrc`](home/dot_skhdrc) wires the desktop helpers and yabai
operations to these shortcuts:

| Shortcut | Action |
| --- | --- |
| `Alt+Tab`, `Alt+Shift+Tab` | Cycle stacked windows forward or backward. |
| `Ctrl+Alt+Left/Right`, `Ctrl+Alt+h/k` | Snap a window to the left or right half. |
| `Ctrl+Alt+Shift+Arrows`, `Ctrl+Alt+Shift+h/k/u/j` | Swap windows by direction. |
| `Ctrl+Alt+Cmd+Arrows`, `Ctrl+Alt+Cmd+h/k/u/j` | Resize the current window by 100 pixels. |
| `Ctrl+Alt+Return` | Toggle full-screen zoom. |
| `Ctrl+Alt+s`, `Ctrl+Alt+b`, `Ctrl+Alt+o`, `Ctrl+Alt+x/y` | Toggle split, balance, rotate, or mirror the layout. |
| `Ctrl+Alt+f`, `Ctrl+Alt+d`, `Ctrl+Alt+g` | Toggle remembered float (per app/title), stack west, or toggle BSP/stack layout. |
| `Alt+Cmd+[`, `Alt+Cmd+]`, `Alt+Cmd+Left/Right` | Move the current window between displays. |
| `Hyper+p` / `Hyper+e` | ProjectDeck floating picker (switch, create, adopt, spaces, detach, delete). |
| `Hyper+n` | Quick create project via ProjectDeck. |
| `Hyper+1..5` | Focus project shortcut → last-used space in that project. |
| `Hyper+Shift+1..5` | Adopt current space into project shortcut (slot must already be assigned). |
| `Hyper+a` | Adopt current space into the last-focused project. |
| `Hyper+Shift+Backspace` | Detach current space from its project (no confirm). |
| `Hyper+[` / `Hyper+]` | Cycle prev/next space in the project context. |
| `Alt+Shift+=`, then `1..9` | Manually remap a space shortcut (optional). |
| `Alt+Shift+-`, then `1..9` | Clear a space shortcut in the project context. |
| `Alt+Shift+1..9` | Jump to a space shortcut in the project context. |
| `Alt+Shift+h` / `Alt+Shift+k` | Cycle prev/next within the project context. |
| `Alt+Shift+/` | Show project notification summary (`projects show`). |
| `Ctrl+Alt+n` | Move the current window to a new labeled space. |
| `Alt+n` | Create and focus a new space. |
| `Alt+k` | Close empty spaces. |
| `Alt+Backtick`, `Alt+1..4` | Focus Ghostty, the default browser, VSCodium (`EDITOR_APP`), Teams, or Slack. Repeat to MRU-cycle that app's windows only. |
| `Alt+Shift+Backtick` | Create a new terminal window on the focused space. |
| `Alt+Shift+Backslash` | Toggle zen mode. In zen mode, terminal focus and `Alt+1` browser focus still work; `Alt+2..4` are disabled. |
| `Ctrl+Alt+w`, `Ctrl+Alt+z` | Close or minimize the current window. |
| `Alt+r` | Restart yabai and skhd. |
| `Alt+/` | Toggle the `whichkey` overlay. |

Experimental hyper bindings, including hyperspace session slots and the
Spotlight scratchpad shortcut, are kept in
[`home/dot_config/skhd/modules/hyperspace.skhdrc`](home/dot_config/skhd/modules/hyperspace.skhdrc)
and are not loaded by default.

## Configuration Utilities

| Source | Purpose |
| --- | --- |
| [`home/dot_config/colorschemes/executable_catppuccin-mocha.sh`](home/dot_config/colorschemes/executable_catppuccin-mocha.sh) | Export the shared Catppuccin Mocha color palette, border colors, and `COLORS_JSON`. |
| [`home/dot_config/colorschemes/symlink_colors.sh`](home/dot_config/colorschemes/symlink_colors.sh) | Select `catppuccin-mocha.sh` as `~/.config/colorschemes/colors.sh`. |
| [`home/dot_config/tmux/executable_colors.sh`](home/dot_config/tmux/executable_colors.sh) | Source the selected colorscheme for tmux-related scripts. |
| [`home/dot_config/tmux/colors.conf`](home/dot_config/tmux/colors.conf) | Apply the Catppuccin Mocha palette to tmux. |
| [`home/dot_config/yazi/init.lua`](home/dot_config/yazi/init.lua) | Keep zoxide's directory database updated while navigating in Yazi. |
| [`home/dot_config/yazi/keymap.toml`](home/dot_config/yazi/keymap.toml) | Add Yazi shortcuts: `!` opens a shell, `Esc` closes input, and `g r` jumps to the current Git root. |

The main [`home/dot_yabairc`](home/dot_yabairc) configures BSP tiling, padding,
window rules, fixed space labels, optional scripting-addition loading, and
JankyBorders startup. [`home/dot_tmux.conf`](home/dot_tmux.conf) configures tmux
and is documented further in [`TMUX_GUIDE.md`](TMUX_GUIDE.md).

## Chezmoi Automation

| Hook | Purpose |
| --- | --- |
| [`run_onchange_after_install-vscodium-extensions.sh.tmpl`](home/.chezmoiscripts/run_onchange_after_install-vscodium-extensions.sh.tmpl) | Install declared VSCodium extensions with `codium --install-extension --force` whenever the generated hook changes. |
| [`run_once_install-vscodium-cli.sh.tmpl`](home/.chezmoiscripts/run_once_install-vscodium-cli.sh.tmpl) | Symlink the `codium` CLI into `~/.local/bin` after VSCodium is installed. |
| [`run_after_sync-chrome-extensions.sh.tmpl`](home/.chezmoiscripts/run_after_sync-chrome-extensions.sh.tmpl) | Build declared Chrome extension repositories after their Git revision changes or their unpacked manifest is missing. |
| [`run_after_sync-external-projects.sh.tmpl`](home/.chezmoiscripts/run_after_sync-external-projects.sh.tmpl) | Install and set up declared external project repositories after their Git revision changes or generated paths go missing. |

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

`raycast-lucide-excalidraw` is declared as an external project repo
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
