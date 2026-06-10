# Command and Utility Reference

This repository is a chezmoi source state for a macOS workstation. Files under
`home/bin/` become commands in `~/bin`. Files under `home/dot_config/` are
installed below `~/.config/`.

## Installed Commands

These commands are installed into `~/bin`, which `home/dot_zshrc` adds to
`PATH`.

| Command | Purpose | Source |
| --- | --- | --- |
| `default-apps` | Inspect and change macOS default handlers for file extensions and URL schemes. | [`scripts/default-apps.sh`](scripts/default-apps.sh) |
| `defuddle-clipboard-url` | Read an http(s) URL from the clipboard, save Defuddle-cleaned HTML under `~/Downloads/defuddled-pages`, keep original CSS links by default, copy that HTML to the clipboard, and open the saved file. | [`home/bin/executable_defuddle-clipboard-url`](home/bin/executable_defuddle-clipboard-url) |
| `kit` | Speak text with KittenTTS, either from arguments or stdin, and optionally write WAV output. | [`home/bin/executable_kit`](home/bin/executable_kit) |
| `kit-watch` | Watch a text file with `fswatch` and read its contents with `kit` whenever it changes. | [`home/bin/executable_kit-watch`](home/bin/executable_kit-watch) |
| `lucide-icons-excalidraw` | Start the external Raycast development command for the Lucide Excalidraw picker. Additional arguments are passed to `npm run dev`. | [`home/bin/executable_lucide-icons-excalidraw.tmpl`](home/bin/executable_lucide-icons-excalidraw.tmpl) |
| `reload-colors` | Restart yabai and skhd, then reload tmux configuration when tmux is running. | [`home/bin/executable_reload-colors`](home/bin/executable_reload-colors) |
| `reset-yabai` | Reinstall and pin `yabai@7.1.16`, update its scripting-addition sudoers entry, and restart its service. This uses `sudo` and changes Homebrew packages and `/etc/sudoers.d/yabai`. | [`home/bin/executable_reset-yabai`](home/bin/executable_reset-yabai) |
| `serve_md` | Render a Markdown file or folder with Pandoc and serve it from a managed local Caddy site. | [`home/bin/executable_serve_md`](home/bin/executable_serve_md) |
| `tmux-session-picker` | Select and switch to an existing tmux session with `sesh` + `fzf`. | [`home/bin/executable_tmux-session-picker`](home/bin/executable_tmux-session-picker) |
| `tmux-sessionizer-zoxide` | Pick from existing tmux sessions or zoxide-ranked directories and connect via `sesh`. | [`home/bin/executable_tmux-sessionizer-zoxide`](home/bin/executable_tmux-sessionizer-zoxide) |
| `tmux-sessionizer` | Compatibility wrapper for `-s <index>` and interactive selection, backed by `sesh`. | [`home/bin/executable_tmux-sessionizer`](home/bin/executable_tmux-sessionizer) |
| `unescape-buffer` | Read escaped text from stdin and write unescaped newlines, tabs, carriage returns, quotes, and backslashes to stdout. Implemented in Node.js. | [`home/bin/executable_unescape-buffer`](home/bin/executable_unescape-buffer) |
| `unescape-string` | Read escaped text from stdin and write an unescaped version to stdout. Implemented with `sed`. | [`home/bin/executable_unescape-string`](home/bin/executable_unescape-string) |
| `watch-sync` | Watch the chezmoi source state with `fswatch` and apply it after changes. | [`home/bin/executable_watch-sync`](home/bin/executable_watch-sync) |
| `nearly-headless` | Show, print, or initialize the nearly-headless agent profile (HTML artifacts, headless hyperspaces). | [`home/bin/executable_nearly-headless`](home/bin/executable_nearly-headless) |
| `hyperspace-open-report` | Open `<project>/.hyperspace/<slug>.html` in the default browser. | [`home/bin/executable_hyperspace-open-report`](home/bin/executable_hyperspace-open-report) |
| `hyperspace` | Open project tmux sessions, manage agents, pin slots, connect via sesh. | [`home/bin/executable_hyperspace`](home/bin/executable_hyperspace) |
| `hyperspace-serve` | Serve `.hyperspace/` artifacts at `http://127.0.0.1:4200` (index + per-session routes). | [`home/bin/executable_hyperspace-serve`](home/bin/executable_hyperspace-serve) |

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

### Text Unescaping

```bash
printf 'line one\\nline two\\tvalue\\n' | unescape-buffer
printf 'line one\\nline two\\tvalue\\n' | unescape-string
```

### Markdown Preview Server

```bash
serve_md README.md
serve_md docs project-docs
serve_md --host docs.local --port 8080 ~/notes notes
serve_md status
serve_md stop
```

`serve_md` renders Markdown to `/tmp/serve-html/<name>/` with Pandoc, rewrites
local Markdown links to HTML links, and serves the rendered sites through a
small Caddy instance on `http://docs.localhost:7331/` by default.

### Defuddle HTML Capture

```bash
defuddle-clipboard-url
defuddle-clipboard-url --no-open
defuddle-clipboard-url --no-original-css
defuddle-clipboard-url --output-dir ~/Documents/ReadablePages https://example.com/article
```

`defuddle-clipboard-url` uses a globally installed `defuddle` command when
available, otherwise it runs `npx --yes defuddle`. It keeps the result as HTML;
it does not pass Defuddle's Markdown flag. By default it wraps the cleaned
content with the original page's stylesheet links and inline `<style>` blocks,
but does not keep the original scripts.

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

### Nearly-headless (HTML artifacts)

```bash
nearly-headless info
nearly-headless print-agents
nearly-headless tasks
nearly-headless init-project
nearly-headless init-project ~/my-project
hyperspace-open-report status
hyperspace-open-report pr-142 --project ~/dotfiles
hyperspace open dotfiles
hyperspace agent start dotfiles codex-main
hyperspace agent focus dotfiles codex-main
hyperspace agent status dotfiles
hyperspace connect 2
hyperspace serve start
hyperspace serve open
hyperspace serve stop
```

Local server: `http://127.0.0.1:4200/dotfiles/` edits `.hyperspace/live-doc.html` in place. Save runs `hyperspace-run-live-doc` (`codex exec`) — agent writes back into the same file. See `AGENTS.md` § Hyperspace live doc.

Profile docs: [`home/dot_agents/docs/nearly-headless.md`](home/dot_agents/docs/nearly-headless.md).
Task list: [`home/dot_agents/profiles/nearly-headless/TASKS.md`](home/dot_agents/profiles/nearly-headless/TASKS.md).

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
| [`focus_app.sh APP`](home/dot_config/skhd/executable_focus_app.sh) | Focus, cycle, toggle, or launch an application. `@browser` resolves the macOS HTTPS handler and `@editor` resolves the Markdown handler. |
| [`media_key.sh ACTION`](home/dot_config/skhd/executable_media_key.sh) | Send a macOS media key event. Supported actions are `brightness_down`, `brightness_up`, `mission_control`, `launchpad`, `dictation`, `do_not_disturb`, `previous`, `play_pause`, `next`, `mute`, `volume_down`, and `volume_up`. |
| [`open_terminal_window.sh`](home/dot_config/skhd/executable_open_terminal_window.sh) | Open a terminal window on the current yabai space. `TERMINAL_APP` defaults to `Ghostty`. The current skhd config does not bind this helper. |
| [`show_keys.sh`](home/dot_config/skhd/executable_show_keys.sh) | Toggle the `whichkey` keybinding overlay. |
| [`snap_window.sh left\|right`](home/dot_config/skhd/executable_snap_window.sh) | Warp the current window and resize it to half the display width. |
| [`toggle_ghostty_quick_terminal.sh`](home/dot_config/skhd/executable_toggle_ghostty_quick_terminal.sh) | Create or toggle a bottom-third Ghostty scratchpad named `quick_terminal`. |
| [`whichkey`](home/dot_config/skhd/executable_whichkey) | Compiled arm64 SwiftUI keybinding overlay launched by `show_keys.sh`. |

### yabai Helpers

Installed below `~/.config/yabai/`:

| Helper | Purpose |
| --- | --- |
| [`bookmark-space.sh SLOT`](home/dot_config/yabai/executable_bookmark-space.sh) | Save the current yabai space UUID in slot `1` through `5`. |
| [`jump-to-bookmark.sh SLOT`](home/dot_config/yabai/executable_jump-to-bookmark.sh) | Focus the space stored in slot `1` through `5`. |
| [`unbookmark-space.sh SLOT`](home/dot_config/yabai/executable_unbookmark-space.sh) | Clear a stored slot and remove its label prefix when possible. |
| [`list-bookmarks.sh`](home/dot_config/yabai/executable_list-bookmarks.sh) | Print bookmark slots and their current space metadata. |
| [`show-bookmarks.sh`](home/dot_config/yabai/executable_show-bookmarks.sh) | Display bookmarked spaces in a macOS notification. |
| [`close_empty_spaces.sh`](home/dot_config/yabai/executable_close_empty_spaces.sh) | Destroy empty yabai spaces while retaining at least one space. |

Bookmarks are stored at `~/.config/yabai/space-bookmarks.json`.

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
| `Ctrl+Alt+f`, `Ctrl+Alt+d`, `Ctrl+Alt+g` | Toggle float, stack west, or toggle BSP/stack layout. |
| `Alt+Cmd+[`, `Alt+Cmd+]`, `Alt+Cmd+Left/Right` | Move the current window between displays. |
| `Alt+Shift+1..5` | Jump to a bookmarked space. |
| `Alt+Shift+/` | Show bookmarked spaces. |
| `Alt+Shift+h/k` | Focus the previous or next space. |
| `Ctrl+Alt+Shift+1..5` | Move the current window to a numbered space. |
| `Ctrl+Alt+n` | Move the current window to a new labeled space. |
| `Alt+n` | Create and focus a new space. |
| `Alt+k` | Close empty spaces. |
| `Alt+Backtick`, `Alt+~`, `Alt+1..4` | Focus Ghostty, the default browser, the default Markdown editor, Teams, or Slack. Ghostty focus skips task windows titled like `nvim`, `vim`, `codex`, `claude`, or Codex's `Action Required` status. |
| `Hyper+d` | Defuddle the URL in the clipboard into cleaned HTML, keep original CSS links, save it under `~/Downloads/defuddled-pages`, copy it to the clipboard, and open it. |
| `Ctrl+Alt+w`, `Ctrl+Alt+z` | Close or minimize the current window. |
| `Alt+r` | Restart yabai and skhd. |
| `Alt+/` | Toggle the `whichkey` overlay. |

Hyperspace hyper bindings (`hyper+1-9` connect, `hyper++` pin, `hyper+-` unpin,
`hyper+space` search, `hyper+n` spotlight scratchpad) are in
[`home/dot_skhdrc`](home/dot_skhdrc). See [`hyperspace`](home/bin/executable_hyperspace).

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
| [`run_onchange_after_install-vscode-extensions.sh.tmpl`](home/.chezmoiscripts/run_onchange_after_install-vscode-extensions.sh.tmpl) | Install declared VS Code extensions with `code --install-extension --force` whenever the generated hook changes. |
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

Run its package commands from
`~/.local/share/raycast-extensions/raycast-lucide-excalidraw/`:

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start Raycast development mode. |
| `npm run build` | Build the Raycast command. |
| `npm run generate-library` | Generate `library/lucide-icons.excalidrawlib` from the Lucide API. |
| `npm run lint` | Run Raycast linting. |
| `npm run fix-lint` | Fix lint issues where possible. |
| `npm run publish` | Publish through the Raycast API. |

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
