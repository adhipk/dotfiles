# System Behaviors Reference

Audit of every utility binary in this repository that mutates state outside the
repo: yabai/skhd/tmux mutations, macOS `defaults`/`osascript`/notifications,
sudo and services, files written under `$HOME` and `/tmp`, processes spawned or
killed, and network calls. Each section also lists the utility's configuration
inputs — the knobs that can be surfaced through `dotfiles-settings` via the
settings-fragment contract (see modules/settings/README.md).

Regenerate by re-auditing after behavior changes; keep sections in the
`## <name>` / `Source:` / `Invoked by:` / `System behaviors:` /
`Configuration inputs:` format so tooling can parse them.


Repo: `/Users/adhipkashyap/dotfiles` (chezmoi source, `.chezmoiroot=home`). `home/bin/executable_*.tmpl` and
`home/dot_config/skhd/executable_*.tmpl` are thin `includeTemplate` wrappers; real sources live under
`modules/<id>/bin/` and are audited here. Installed paths: `~/bin/<name>` and `~/.config/skhd/<name>` /
`~/.config/yabai/<name>`.

---

## hotkeys

Source: `modules/app-focus/bin/hotkeys` → installed `~/bin/hotkeys`

Invoked by:
- skhd `alt-1..4` → `hotkeys app-focus SLOT "<app>"` (apps from chezmoi `.preferences.appSlots.slot1..4`)
- skhd `alt-\` → `hotkeys presentation toggle`; `alt+shift-\` → `hotkeys zen toggle`
- skhd `alt+shift-`` → `hotkeys terminal new`
- `focus_app.sh` calls `~/bin/hotkeys terminal new` when the target app equals the configured terminal
- CLI: `app-focus SLOT APP`, `presentation toggle`, `zen on|off|toggle|status`, `terminal new`

System behaviors:
- Writes mode state files `presentation_mode` / `zen_mode` (contents "on"/"off") under the state directory (default `~/.config/skhd/`); `mkdir -p` of that dir.
- Sends macOS notifications on mode changes via the configured notify command (default `~/.config/skhd/notify.sh` → terminal-notifier or `osascript display notification`).
- Zen mode silently blocks app-focus slots listed in `zen_blocked_slots` (default 3 4 5).
- `terminal new`: queries yabai for current space/display; creates a temporary yabai rule (`temp_terminal_rule_$$`) pinning the terminal app to the current space, then removes it; spawns a terminal process — Ghostty via `env -u ZDOTDIR open -n -a`, iTerm2/Terminal via `osascript`, kitty via direct binary, otherwise `open -n -a`; then moves/focuses the new window via `yabai -m window --space/--focus`, `display --focus`, `space --focus`.
- Writes lock/cooldown files in `/tmp`: `open_terminal_window.lock` (dir, removed on exit; stale locks >10s force-removed) and `/tmp/open_terminal_window.last_ms` (1200 ms debounce).
- Delegates `app-focus` to `~/.config/skhd/focus_app.sh`.

Configuration inputs:
- Env: `APP_FOCUS_CONFIG_LIB`, `APP_FOCUS_CONFIG_FILE`, `APP_FOCUS_YQ_BIN`, `ZEN_BLOCKED_SLOTS`, `TERMINAL_APP`, `APP_FOCUS_NOTIFY_COMMAND`
- Config file: `~/.config/app-focus/config.toml` (keys: `apps.terminal`, `modes.state_directory`, `modes.zen_blocked_slots`, `integrations.notification_command`); defaults in `modules/app-focus/config/defaults.toml`
- Hardcoded worth exposing: cooldown 1200 ms, stale-lock 10 s, per-terminal launch strategies, `/tmp` lock paths.

---

## focus_app.sh

Source: `modules/app-focus/bin/focus_app.sh` → installed `~/.config/skhd/focus_app.sh`

Invoked by:
- skhd `alt-`` → `focus_app.sh "<terminalApp>"` (chezmoi `.preferences.terminalApp`)
- `~/bin/hotkeys app-focus SLOT APP` (alt-1..4)
- CLI: `focus_app.sh [--single-window|--presentation] APP|@browser|@editor`

System behaviors:
- Reads presentation-mode state file; when "on", forces single-window (no MRU cycling) behavior.
- `@browser`: resolves the macOS default HTTPS handler at call time via `osascript -l JavaScript` (NSWorkspace); launch command is `open https://google.com` (actually opens that URL in the browser if no window exists — a network-visible side effect).
- `@editor`: resolves `EDITOR_APP` / config `.apps.editor` (default VSCodium); launches via `open -a`.
- Launches apps via `eval "$LAUNCH_CMD"` (`open -a "APP"`) when no eligible window exists; routes terminal-app requests to `~/bin/hotkeys terminal new`.
- All focusing/cycling side effects delegated to sourced `app-mru.sh` (yabai space/display/window focus + MRU state files, see below).

Configuration inputs:
- Env: `APP_FOCUS_CONFIG_LIB`, `TERMINAL_APP`, `EDITOR_APP`
- Config keys: `.apps.terminal`, `.apps.editor`, `.modes.state_directory` (`~/.config/app-focus/config.toml`)
- Hardcoded worth exposing: probe URL `https://google.com` for browser resolution; `@browser` launch opens google.com.

---

## app-mru.sh

Source: `modules/app-focus/bin/app-mru.sh` → installed `~/.config/skhd/app-mru.sh` (also sourced as a library by focus_app.sh)

Invoked by:
- yabai signal (from `modules/app-focus/targets/yabai-signals.sh.tmpl`, wired into `~/.yabairc`): `yabai -m signal --add label=app_mru_update event=window_focused action="$HOME/.config/skhd/app-mru.sh update"` — runs on **every window focus event**
- `focus_app.sh` (sourced; `app_mru_cycle`)
- CLI: `update`, `cycle APP [LAUNCH_CMD] [PRESENTATION_MODE]`, `list APP`

System behaviors:
- Maintains per-app MRU stack files under `~/.config/skhd/app-mru/<app>.ids` (default; `mkdir -p`, rewrite on every update/cycle). Slashes in app names mapped to `_`.
- Writes/removes a focus-suppression file `.suppress-focus` (atomic tmp + `mv`) with a 2-second expiry to ignore self-triggered focus events.
- yabai reads: `query --windows`, `--windows --window`, `--spaces --space`, `--displays --display`.
- yabai mutations when cycling: `yabai -m space --focus`, `yabai -m display --focus`, `yabai -m window --focus`.
- Launches apps: `eval "$LAUNCH_CMD"` or `open -a "$app"` when the stack is empty.
- Requires yabai + jq; exits with stderr message otherwise.

Configuration inputs:
- Env: `APP_FOCUS_CONFIG_LIB`, `APP_MRU_DIR`, `APP_MRU_SUPPRESS_FOCUS_FILE`
- Config key: `.modes.state_directory` (state root)
- Hardcoded worth exposing: 2 s suppression window; eligibility filter (excludes minimized/hidden/scratchpad windows).

---

## focus-open-tmux-window.sh

Source: `modules/app-focus/bin/focus-open-tmux-window.sh` → installed `~/.config/skhd/focus-open-tmux-window.sh`

Invoked by:
- skhd `fn-1 … fn-9` → `focus-open-tmux-window.sh N`; `fn-tab` → `focus-open-tmux-window.sh cycle`

System behaviors:
- Read-only yabai queries (`--windows`, `--windows --window`) filtering Ghostty non-scratchpad windows titled `^tmux( · .+)?$`, sorted by window id.
- Single mutation: `yabai -m window --focus <id>` (slot N = Nth window in creation order; cycle = next after current).
- No files written, no processes spawned.

Configuration inputs:
- None (no env/config). Hardcoded worth exposing: app match `Ghostty`, title regex `^tmux( · .+)?$`, slot range 1–9.

---

## scratchpads

Source: `modules/scratchpads/bin/scratchpads` (1396 lines) → installed `~/bin/scratchpads`

Invoked by:
- skhd `fn-p` → `scratchpads open sessions`
- Declared external window-transport API: other modules (dotfiles-manager etc.) call `scratchpads open command LABEL PROFILE CWD COMMAND`
- yabai rules generated by `scratchpads rules` are embedded in the yabai config
- CLI: `open quick|projects|sessions|command …`, `tmux projects|nvim|sessions`, `close`, `debug`, `rules`

System behaviors:
- Appends a log to `/tmp/scratchpads_${USER}.log` (every action; `debug` tees state into it).
- Concurrency locks: `mkdir` lock dirs `${TMPDIR:-/tmp}/scratchpads_${USER}_open_<label>.lock` with `pid` file; stale locks reclaimed by PID liveness check; removed on exit.
- Extensive yabai mutations: `window --scratchpad <label>`, `--grid` (codex `10:10:1:1:8:8`, bottom `6:1:0:4:1:2`), `--toggle <label>`, `--toggle shadow`, `--space`, `--focus`, `--close`, `space --focus`, `display --focus`, `window --focus recent`. `rules` prints `yabai -m rule --add/--remove` lines for labels `scratchpad_<label>` matching Ghostty windows titled `scratchpad:<label>`.
- Spawns Ghostty processes: `env -u ZDOTDIR -u TMUX -u TMUX_PANE open -n -a Ghostty --args --working-directory=… --title=scratchpad:<label> --background=#000000 …` (Linux path uses `ghostty +new-window`).
- osascript automation of Ghostty: closes the front window (`tell application "Ghostty" … close window`), and **types commands into a Ghostty terminal** (`input text … send key "enter"`) to run arbitrary command text in a matched window.
- Closes windows: focuses then AppleScript-closes (Ghostty) or `yabai -m window --close` by id; kills duplicate scratchpad windows.
- tmux mutations: creates/ensures sessions (`projects`, `session-manager`) with `tmux new-session -d`, creates windows, `select-window`, `switch-client`, `attach` (via `exec`), sets global options `@scratchpads_terminal_client` / `@scratchpads_terminal_target` and per-session spotlight styling options (`status-position top`, custom status formats).
- Calls helpers: `~/bin/tmux-session-template ensure`, `~/bin/tmux-hub open` (with `TMUX_HUB_SESSION`, `TMUX_HUB_NO_SWITCH=1`), `~/bin/tmux-border-accent suppress-scratchpads <win_id>`.
- Validates `open command` args (label `^[A-Za-z0-9_-]+$`, profile codex|bottom, cwd must exist) — but the COMMAND argument is executed verbatim in the spawned terminal.

Configuration inputs:
- Env: `SCRATCHPADS_CONFIG_LIB`, `SCRATCHPADS_CONFIG_FILE`, `SCRATCHPADS_YQ_BIN`, `SCRATCHPAD_LOG_FILE`, `TMUX_SESSIONIZER_CMD`, `SCRATCHPAD_TERMINAL_LABEL`, `SCRATCHPAD_PROJECTS_DIR`, `SCRATCHPAD_PROJECTS_TMUX_SESSION`, `SCRATCHPAD_SESSION_MANAGER_LABEL`, `SCRATCHPAD_SESSION_MANAGER_TMUX_SESSION`, `TMUX_HUB_CMD`, `SCRATCHPADS_COMMAND`, `SCRATCHPAD_LOCK_ROOT`
- Config file: `~/.config/scratchpads/config.toml` (keys: `paths.projects`, `tmux.terminal_label`, `tmux.projects_session`, `tmux.session_manager_label`, `tmux.session_manager_session`); defaults in `modules/scratchpads/config/defaults.toml`
- Hardcoded worth exposing: grid geometries per profile, Ghostty launch flags (background color/opacity, titlebar style, padding), profile→label mapping, `direct:/bin/zsh` initial command.

---

## reset-yabai

Source: `modules/space-display/bin/reset-yabai` → installed `~/bin/reset-yabai` (wrapper `home/bin/executable_reset-yabai.tmpl`)

Invoked by:
- Manual CLI only (maintenance command; no hotkey/service binding).

System behaviors:
- Stops the yabai launchd service (`yabai --stop-service`), **sudo** uninstalls the scripting addition (`sudo yabai --uninstall-sa`), uninstalls the service (`--uninstall-service`).
- Homebrew mutations: `brew uninstall --ignore-dependencies <yabai formula>`, `brew install <formula from Brewfile>`, `brew link --overwrite --force`, `brew pin` (formula parsed from the repo Brewfile).
- Reinstalls the launchd service (`yabai --install-service`).
- Chains into `~/bin/setup-yabai-sa` (sudoers write + SA load + service restart — see below).

Configuration inputs:
- Env: `DOTFILES_DIR` (default `~/dotfiles`), `DOTFILES_BREWFILE`, `BREW_BIN`, `YABAI_BIN`, `YABAI_BIN_AFTER_INSTALL`, `SETUP_YABAI_SA_BIN`
- Config: yabai formula declared in `Brewfile`
- Hardcoded worth exposing: none significant beyond the env overrides.

---

## setup-yabai-sa

Source: `modules/space-display/bin/setup-yabai-sa` → installed `~/bin/setup-yabai-sa` (wrapper `home/bin/executable_setup-yabai-sa.tmpl`)

Invoked by:
- Manual CLI; called by `reset-yabai` as its final step.

System behaviors:
- **Writes a sudoers drop-in** `/private/etc/sudoers.d/yabai` containing `<user> ALL=(root) NOPASSWD: sha256:<sha256-of-yabai-binary> <yabai path> --load-sa` — passwordless root scoped to the exact binary checksum. Validates with `sudo visudo -cf` first, installs via `sudo install -o root -g wheel -m 0440`.
- Writes a temp rule file `${TMPDIR:-/tmp}/yabai-sudoers.XXXXXX` (removed on exit trap).
- Loads the scripting addition: `sudo yabai --load-sa` (fails with guidance if SIP setup incomplete).
- Restarts the yabai launchd service: `yabai --restart-service`.

Configuration inputs:
- Env: `YABAI_BIN`, `YABAI_SUDOERS_FILE` (default `/private/etc/sudoers.d/yabai`), `SUDO_BIN`, plus tool-path overrides `SHASUM_BIN`, `AWK_BIN`, `ID_BIN`, `MKTEMP_BIN`, `RM_BIN`, `VISUDO_BIN`, `INSTALL_BIN`
- Hardcoded worth exposing: sudoers path/mode (0440 root:wheel).

---

## bookmarks (+ bookmarks-store)

Source: `modules/space-display/bin/bookmarks` (thin `exec ~/.config/yabai/bookmarks "$@"`) → real logic `modules/space-display/bin/bookmarks-store`, installed as `~/.config/yabai/bookmarks`; wrapper installed `~/bin/bookmarks`. Marked legacy (superseded by `projects`).

Invoked by:
- Manual CLI only in the current skhdrc (project-context hotkeys are dormant). Subcommands: `set|clear|jump|list|show <slot 1-5>`.

System behaviors:
- Persists bookmarks in `~/.config/yabai/space-bookmarks.json` (creates dir/file; atomic mktemp+mv updates; slot→space UUID map).
- yabai mutations: `yabai -m space --label "📌<slot> …"` on set, label rewrite/clear on clear (`space <idx> --label`), `yabai -m space --focus <idx>` on jump.
- yabai reads: `query --spaces`, `query --spaces --space`.
- Notifications for every outcome via `~/.config/skhd/notify.sh` (terminal-notifier / osascript).

Configuration inputs:
- None via env. Hardcoded worth exposing: store path `~/.config/yabai/space-bookmarks.json`, slot range 1–5, `📌` label prefix, notify helper path.

---

## create-space

Source: `modules/space-display/bin/create-space` → installed `~/.config/yabai/create-space`

Invoked by:
- skhd `alt-n` → `create-space auto`; `ctrl+alt-n` → `create-space move-window`; `cmd+alt-n` → `create-space new-window`

System behaviors:
- `yabai -m space --create`; identifies the new space by UUID diff (polls up to 1 s).
- `new-window` mode: **injects a synthetic keystroke** `skhd -k "cmd - n"` to open the focused app's default new window, then identifies an unseen normal window from the original app (up to 3 s plus query time); focus changes alone do not qualify. Space creation occurs on the original display.
- `current-window` mode (Cmd+n) uses the same native action/new-window detection and moves the new window to the originally focused space. No new window means no move or space creation.
- Moves the focused non-scratchpad window to the new space (`yabai -m window <id> --space`), focuses display/space/window, labels the space with the moved window's app name (`yabai -m space --label "$app"`).
- Runs `~/.config/yabai/close_empty_spaces.sh` afterwards when a window was moved (destroys empty spaces).

Configuration inputs:
- None via env/config. Hardcoded worth exposing: 20×0.05 s poll timing, auto-labeling of the space with app name, synthetic `cmd-n` keystroke.

---

## display-move

Source: `modules/space-display/bin/display-move` → installed `~/.config/yabai/display-move`

Invoked by:
- skhd `alt+shift-[` → `display-move prev`; `alt+shift-]` → `display-move next`

System behaviors:
- Selects a numeric target from live display coordinates, ordered by x then y, with wraparound; a single display is a no-op. `yabai -m window <id> --display <target>` moves the captured window, `yabai -m display --focus`, then re-focuses the original window id.
- No files, notifications, or processes.

Configuration inputs:
- None. Fully hardcoded; nothing meaningful to expose beyond direction args.

---

## close-empty-spaces

Source: `modules/space-display/bin/close-empty-spaces` → installed `~/.config/yabai/close_empty_spaces.sh`

Invoked by:
- skhd `alt-k`; also called by `create-space` after moving a window.

System behaviors:
- `yabai -m space <idx> --destroy` for every space with zero windows, highest index first; always keeps at least one space (double-checks remaining count each iteration).
- No files/notifications.

Configuration inputs:
- None. Possible setting: minimum number of spaces to keep (hardcoded 1).

---

## reload-colors

Source: `home/bin/executable_reload-colors` (plain file, no template) → installed `~/bin/reload-colors`

Invoked by:
- Manual CLI (after colorscheme changes). Note skhd also binds `alt-r` directly to `yabai --restart-service; skhd --restart-service` (same effect minus tmux).

System behaviors:
- Restarts both launchd services: `yabai --restart-service` and `skhd --restart-service`.
- If a tmux server is running: `tmux source-file ~/.tmux.conf` and `tmux display-message "Config reloaded!"`.

Configuration inputs:
- None. Hardcoded: `~/.tmux.conf` path.

---

## watch-sync

Source: `home/bin/executable_watch-sync` (plain file) → installed `~/bin/watch-sync`

Invoked by:
- Manual CLI (development watcher; long-running foreground process).

System behaviors:
- Runs `fswatch` on the chezmoi source state dir (from `chezmoi source-path`, honoring `.chezmoiroot`) and `modules/`.
- On every change: runs module validation (`modules/module-lifecycle/bin/dotfiles-module validate --json`) then **`chezmoi -S <dotfiles> apply`** — i.e. rewrites the entire managed `$HOME` tree (dotfiles, `~/bin`, `~/.config/*`, run_onchange scripts) automatically on each edit. This is the biggest indirect system mutator in the group.
- No sudo/network of its own.

Configuration inputs:
- Env: `DOTFILES_DIR` (defaults to `chezmoi source-path`)
- Hardcoded worth exposing: watch paths, debounce (none — applies on every event batch), validation step toggle.

---

## projects

Source: `modules/projects/bin/projects` (1626 lines) → installed `~/bin/projects` (and `~/.config/yabai/projects`)

Invoked by:
- Manual CLI — the global skhd project-context bindings (Hyper+1-5, Alt+Shift+1-9) are **intentionally dormant** per skhdrc comments; ProjectDeck/manual use only. `record-focus` is designed for a yabai `space_changed` signal but is not currently wired in skhdrc/yabairc.
- Subcommands: `create|delete|rename|new|adopt|change-space|detach|remove-space|assign-project-slot|clear-project-slot|set-space-slot|clear-space-slot|focus-project|focus-space|cycle|list|show|status|get|active|pick|pick-exec|pick-sub|menu-json|record-focus` (also `hibernate`/`restore-session`/`sessions` in usage text).

System behaviors:
- Persists project graph in `~/.config/yabai/projects.json` (creates dir/file; atomic mktemp+mv on every mutation; slots, spaces, last_project).
- yabai mutations: `yabai -m space --focus <idx>` (focus-project/focus-space/cycle/pick), `yabai -m space <idx> --label "<name> · <slot>"` / `--label ""` (labels rewritten on adopt/detach/slot changes/delete).
- osascript UI: `choose from list` menus, `display dialog` text prompts (project names), `display alert` confirmation dialogs for destructive ops (delete project, remove space); writes/removes temp item-list files `${TMPDIR:-/tmp}/projects-pick.XXXXXX`.
- Notifications via `~/.config/skhd/notify.sh` (gated by env, below).
- Launches the ProjectDeck UI binary (`exec -a projectdeck <deck>`) when built, exporting `PROJECTS_BIN` so the UI calls back into this CLI; falls back to AppleScript dialogs otherwise.
- No sudo/network/service changes.

Configuration inputs:
- Env: `PROJECTS_FILE` (default `~/.config/yabai/projects.json`), `PROJECTS_NOTIFY` (0 disables all notifications), `PROJECTS_NOTIFY_SUCCESS` (1 enables success toasts, default off), `PROJECTS_CONFIRM` (0 skips osascript confirmations), `PROJECTS_PICK_NAME`, `PROJECTS_PICK_MENU`, `PROJECTDECK_BIN`, `PROJECTS_BIN`
- Hardcoded worth exposing: slot ranges (project 1–5 / space 1–9), label format `"<name> · <slot>"`, ProjectDeck fallback path `~/.config/yabai/projectdeck`.

---

## projects-pick

Source: `modules/projects/bin/projects-pick` → installed `~/bin/projects-pick`

Invoked by:
- Manual CLI / launcher entry (project-context hotkeys dormant).

System behaviors:
- Pure wrapper: `exec <module_dir>/projects pick "$@"` — inherits all `projects pick` behaviors (ProjectDeck launch or osascript menus, yabai space focus/labels, projects.json writes, notifications).

Configuration inputs:
- Same as `projects` (all via env passthrough).

---

## open_terminal_window.sh (skhd helper)

Source: `home/dot_config/skhd/executable_open_terminal_window.sh` → installed `~/.config/skhd/open_terminal_window.sh`

Invoked by:
- Not bound in the current skhdrc (superseded by `hotkeys terminal new`, which embeds the same logic); kept as a standalone helper.

System behaviors:
- Identical to `hotkeys terminal new`: `/tmp/open_terminal_window.lock` + `/tmp/open_terminal_window.last_ms` debounce files; temporary yabai rule pinning the terminal to the current space; spawns terminal (Ghostty `env -u ZDOTDIR open -n -a`, iTerm2/Terminal via osascript, kitty binary, generic `open -n -a`); yabai window→space move plus display/space/window focus.

Configuration inputs:
- Env: `TERMINAL_APP` (default Ghostty). Hardcoded: 1200 ms cooldown, 10 s stale lock. (Unlike `hotkeys`, no TOML config.)

---

## notify.sh (skhd helper)

Source: `home/dot_config/skhd/executable_notify.sh` → installed `~/.config/skhd/notify.sh`

Invoked by:
- `hotkeys`, `bookmarks-store`, `projects` (and other modules) as the shared notification sink; configurable via app-focus `integrations.notification_command`.

System behaviors:
- Posts a macOS notification: prefers `terminal-notifier -group dotfiles.skhd -ignoreDnD` (**bypasses Do Not Disturb**), falls back to `osascript display notification` (newlines joined with " · ").
- No files/state.

Configuration inputs:
- None via env. Hardcoded worth exposing: notification group id `dotfiles.skhd`, `-ignoreDnD` flag, terminal-notifier vs osascript preference.

---

# Cross-cutting notes

- **Privilege escalation** is confined to `reset-yabai` / `setup-yabai-sa` (sudo + sudoers.d NOPASSWD rule scoped to yabai's sha256).
- **Service restarts**: `reset-yabai`, `setup-yabai-sa`, `reload-colors`, plus skhd binding `alt-r` (`yabai --restart-service; skhd --restart-service`).
- **State/config files written under $HOME**: `~/.config/skhd/{presentation_mode,zen_mode}`, `~/.config/skhd/app-mru/*`, `~/.config/yabai/space-bookmarks.json`, `~/.config/yabai/projects.json`.
- **/tmp artifacts**: `open_terminal_window.{lock,last_ms}`, `scratchpads_${USER}.log`, `scratchpads_${USER}_open_*.lock`, `yabai-sudoers.XXXXXX`, `projects-pick.XXXXXX`.
- **osascript surfaces**: notifications (notify.sh), Ghostty window close + keystroke injection (scratchpads), terminal window creation (iTerm2/Terminal), default-handler resolution (focus_app.sh), dialogs/menus/confirms (projects).
- **Only network-adjacent behavior**: `focus_app.sh @browser` launch path opens `https://google.com`; `reset-yabai` brew install downloads the formula.
- **Config systems ripe for user settings**: app-focus TOML (`~/.config/app-focus/config.toml`), scratchpads TOML (`~/.config/scratchpads/config.toml`), chezmoi data keys `.preferences.terminalApp` and `.preferences.appSlots.slot1..4`, plus the many env overrides listed per utility.

Utilities audited: 15


Repo: `/Users/adhipkashyap/dotfiles` (chezmoi source state). Deployed copies live at `~/bin/*` via `home/bin/executable_*.tmpl` wrappers that `includeTemplate` the module sources (gated on `.modules.<name>.enabled` chezmoi data keys).

Utilities audited: 12.

---

## tmux-hub

Source: `modules/tmux-sessions/bin/tmux-hub` (bash) → deployed via `home/bin/executable_tmux-hub.tmpl` (gated on `.modules.tmuxSessions.enabled`).

Invoked by:
- CLI: `open [ROOT]` (default), `jump SESSION_OR_PANE`, `close SESSION_ID`, `open-window SESSION`, `send PANE` (prompt from stdin), `dashboard` (internal, inside tmux), `dump-json`, `self-test`, `help`.
- tmux binding `prefix g` and global `S-F8` (Ghostty adapter): `run-shell "$HOME/bin/tmux-hub open '#{pane_current_path}'"` (modules/tmux-sessions/targets/tmux.conf.tmpl).
- which-key sessions menu (`tmux-which-key-sessions.yaml.tmpl`) also runs `tmux-hub open`.
- The Neovim dashboard (`custom.tmux_hub` lua) calls back into `tmux-hub jump/close/open-window/send`.

System behaviors:
- Creates a persistent tmux session named `hub` (`TMUX_HUB_SESSION`) with a `hub` window running `tmux-hub dashboard` (Neovim UI); session created with env `DOTFILES_TMUX_TEMPLATE=skip` to bypass auto-templating.
- Sets session option `@dotfiles_hub=1` and window option `@dotfiles_hub_window=1` as ownership markers; refuses to take over a pre-existing unmanaged session named `hub`.
- `select-window` / `switch-client` / `attach-session` to focus the hub or a jump target (attaches with `env -u ZDOTDIR -u TMUX -u TMUX_PANE`).
- `close`: `kill-session` on an exact session ID (`$N` only); refuses to kill the hub itself.
- `open-window` (macOS): spawns a new Ghostty window via `open -n -a Ghostty --args --working-directory=… --title="tmux · <name>" -e tmux … attach-session` — touches macOS app launch state. Linux branch execs `ghostty` directly in the background.
- `send`: writes stdin to a temp file `${TMPDIR:-/tmp}/tmux-hub-reply.XXXXXX`, loads it into a named tmux buffer, `paste-buffer -p -d` into the exact pane, then `send-keys Enter` — types into a live agent pane. Temp file removed after loading.
- `dashboard`/`dump-json`/`self-test`: spawn `nvim` (interactive or `--headless -u NONE`) with runtimepath extended to the user's Neovim config.

Configuration inputs:
- Env: `TMUX_HUB_SESSION` (default `hub`), `TMUX_HUB_NVIM_CONFIG` (`~/.config/nvim`), `TMUX_HUB_TMUX_BIN`, `TMUX_HUB_BIN`, `TMUX_HUB_SOCKET_NAME`/`TMUX_HUB_SOCKET_PATH` (alternate tmux server), `TMUX_HUB_DASHBOARD_COMMAND`, `TMUX_HUB_NO_SWITCH`, `TMUX_HUB_OPEN_BIN`, `TMUX_HUB_GHOSTTY_APP` (default `Ghostty`), `TMUX_HUB_GHOSTTY_BIN`.
- Hardcoded worth exposing: session name `hub`, Ghostty window title prefix `tmux ·`, marker option names `@dotfiles_hub`/`@dotfiles_hub_window`.

---

## tmux-workspace

Source: `modules/tmux-sessions/bin/tmux-workspace` (Bun/JS, ~1400 lines) — declarative session builder from `.tmux.tsx` JSX layouts.

Invoked by:
- CLI: `list`, `validate LAYOUT`, `plan|preview LAYOUT [--json]`, `open LAYOUT [--detached]`, `apply [LAYOUT] [--adopt]`, `repair [LAYOUT] --yes [--prune]`, `pick` (fzf), `clean [--yes]`, `snapshot save|restore`. Options: `--root`, `--session`, `--session-id`, `--pane`, `--json`, `--detached`, `--yes`, `--prune`, `--adopt`.
- which-key layouts menu (`tmux-which-key-layouts.yaml.tmpl`): `pick` in a display-popup, `apply --session-id`, `repair --yes`.
- which-key sessions menu: `tmux-workspace clean --yes`.
- tmux-resurrect hooks (`tmux-persistence.conf.tmpl`): `@resurrect-hook-post-save-all` → `snapshot save`; `@resurrect-hook-pre-restore-pane-processes` → `snapshot restore`.

System behaviors:
- Creates detached tmux sessions (`new-session -d -e DOTFILES_TMUX_TEMPLATE=skip -n __workspace__`), then reconciles windows: `new-window`, `split-window` (tree of Rows/Cols with percent sizes), `respawn-pane -k` / `respawn-window -k` (kills existing pane processes and relaunches commands), `rename-window`, `swap-window`, `move-window`, `kill-window` (during repair and `--prune`), `select-window`/`select-pane` for focus, `switch-client`/`attach-session` on `open`.
- `clean --yes`: `kill-session` on every *detached* managed session.
- Sets session options `@dotfiles_workspace`, `@dotfiles_workspace_path`, `@dotfiles_workspace_root`, `@dotfiles_tmux_template=workspace`, `base-index 0`; window options `@dotfiles_workspace_window_id`, `@dotfiles_window_type`, `@dotfiles_workspace_spec_hash`; pane option `@dotfiles_workspace_pane_id`; `set-environment DOTFILES_TMUX_TEMPLATE=skip` on restore.
- Concurrency lock via tmux `wait-for -L/-U` channel `dotfiles-workspace-<session>`.
- Writes `~/.local/state/tmux-workspace/resurrect.json` (mkdir 0700, file 0600, atomic tmp+rename) on `snapshot save`.
- Executes layout `.tmux.tsx` files as code (Bun transpiler, imports forbidden); spawns `fzf` for `pick`; spawns pane `run` commands (default windows run the configured assistant/editor: `codex`, `nvim`).
- Kills freshly created windows on materialization failure (rollback).

Configuration inputs:
- Env: `TMUX_WORKSPACE_CONFIG_HOME` (default `~/.config/tmux`), `TMUX_WORKSPACE_LAYOUT_DIR` (`<config>/layouts`), `TMUX_WORKSPACE_TMUX_SOCKET` (tmux `-L`), `TMUX_WORKSPACE_STATE_HOME` / `XDG_STATE_HOME`, `HOME`, arbitrary env vars referenced in layout paths, `DOTFILES_PREF_ASSISTANT` / `DOTFILES_PREF_TERMINAL_EDITOR` overrides, `DOTFILES_PREFS_FILE` (default `~/.config/dotfiles/preferences.toml`, keys `assistant`, `terminal_editor`).
- Files: layout `.tmux.tsx` files; preferences.toml; `resurrect.json` state.
- Hardcoded worth exposing: default window components Terminal/Codex/Nvim with indices 0/1/2, bootstrap window name `__workspace__`, split tolerance 8%, session-name sanitization rules.

---

## tmux-sessionizer

Source: `modules/tmux-sessions/bin/tmux-sessionizer` (bash) — compatibility wrapper over `sesh`.

Invoked by:
- CLI: no args (picker), `-s <index>` (connect to Nth entry of `sesh list -t -z -d`), `<session-or-directory>` (direct connect), `-h`.
- zsh bindkeys (`modules/tmux-sessions/targets/zshrc`): `Alt+h/t/n/s` → `tmux-sessionizer -s 0..3`.

System behaviors:
- Delegates entirely to `sesh`: `sesh connect` (creates/attaches tmux sessions, may run sesh-configured startup scripts) or `sesh picker --icons --hide-duplicates --separator-aware` (interactive fzf-style UI). No direct file writes; tmux mutations are whatever sesh performs (session creation/attach/switch).

Configuration inputs:
- Requires `sesh` on PATH (brew). Slot ordering comes from `sesh list -t -z -d` (tmux sessions + zoxide dirs). Sesh's own config (`~/.config/sesh/sesh.toml`) governs behavior. No env vars of its own — picker flags are hardcoded (candidates for user settings).

---

## tmux-sessionizer-zoxide

Source: `modules/tmux-sessions/bin/tmux-sessionizer-zoxide` (bash, 15 lines).

Invoked by:
- CLI: no arguments.
- tmux `prefix s` and global `S-F6`: `display-popup -EE -w 70% -h 70% … "$HOME/bin/tmux-sessionizer-zoxide"`; also which-key sessions menu.

System behaviors:
- `exec sesh picker --icons --hide-duplicates --separator-aware` — sessions + zoxide directories; selecting an entry creates/switches tmux sessions via sesh. No other side effects.

Configuration inputs:
- Requires `sesh`. Picker flags hardcoded. Popup geometry (70%/70%) hardcoded in the tmux binding.

---

## tmux-session-picker

Source: `modules/tmux-sessions/bin/tmux-session-picker` (bash, 16 lines).

Invoked by:
- CLI: no arguments.
- zsh bindkey `Alt+e` (`tmux-session-picker\n` typed into the shell).

System behaviors:
- `exec sesh picker --icons --hide-duplicates --separator-aware --tmux` — existing tmux sessions only; switch/attach via sesh. No file or process side effects.

Configuration inputs:
- Requires `sesh`; flags hardcoded (`--tmux` restricts to live sessions).

---

## daemon

Source: `modules/tmux-sessions/bin/daemon` (bash).

Invoked by:
- CLI only: `daemon NAME [KEY=VALUE ...] COMMAND [ARG...]`. No tmux/skhd bindings. For example: `daemon server PORT=3001 bun run server`.

System behaviors:
- Spawns `COMMAND` with `nohup … &` detached from the terminal (stdout+stderr → log, stdin `/dev/null`).
- Writes `/tmp/NAME.log` (command output) and `/tmp/NAME.pid` (PID) — world-visible /tmp files by default.
- Creates a detached tmux session `daemon-NAME` (with `DOTFILES_TMUX_TEMPLATE=skip`, window `logs`) running `tail -n +1 -F <log>`; skips creation if the session already exists; degrades gracefully when tmux is absent (process still runs).
- NAME validated to `[A-Za-z0-9][A-Za-z0-9._-]*` to prevent path injection.
- Leading environment assignments are passed literally through `env`; executable lookup uses the requested environment. Missing commands fail before creating logs, PID files, or tmux sessions.

Configuration inputs:
- Env: `DAEMON_LOG_DIR` (default `/tmp` — worth exposing/defaulting to a private dir), `DAEMON_TMUX_BIN`.
- Hardcoded: session name prefix `daemon-`, window name `logs`.

---

## tmux-session-template

Source: `modules/terminal-window-types/bin/tmux-session-template` (bash, ~620 lines). Sources shared libs `core.sh`, `prefs.sh`, `tmux.sh` from `$DOTFILES_LIB_DIR` (default `~/.local/lib/dotfiles`).

Invoked by:
- CLI: `auto SESSION`, `ensure SESSION [DIRECTORY]`, `cycle SESSION TYPE [WINDOW]`, `new SESSION TYPE [PANE]`, `duplicate SESSION [PANE]`.
- tmux hook (modules/terminal-window-types/targets/tmux.conf.tmpl): `set-hook -g after-new-session[50] 'run-shell "$HOME/bin/tmux-session-template auto #{q:session_name}"'` — every new session is auto-templated.
- tmux bindings: `prefix c` → `new … terminal`; `S-F4` (Ghostty Rcmd+d via skhd) → `duplicate`; `C-0/C-1/C-2/C-3` → `cycle terminal/codex/nvim/tuxedo` (C-1/C-2 conditional on control-panel surface); `C-S-0..3` → `new` of each type; `` C-` `` → cycle terminal (surface-conditional).
- skhd: `rcmd - d` re-emits `f16` in Ghostty (duplicate window path).
- Called programmatically by `tmux-yazi-open` (`new SESSION nvim PANE`).

System behaviors:
- Standard layout: window 0 `terminal` (shell), 1 `codex` (runs configured assistant), 2 `nvim` (runs configured editor), 3 `tuxedo` (runs `todo`).
- `auto`: only templates a brand-new ordinary session (skips `hs-*` sessions, sessions with env `DOTFILES_TMUX_TEMPLATE=skip`, grouped sessions, >1 window/pane, or panes with a start command). Renames initial window to `terminal`, creates the other three windows (`new-window -d` + `send-keys <cmd> C-m` — types the launch command into the shell), selects the terminal window, marks the session.
- `ensure`: creates/repairs the four typed windows in any session.
- `cycle`: `select-window` to next window of TYPE (with legacy-name/index migration that stamps `@dotfiles_window_type`).
- `new`/`duplicate`: `new-window` in the source pane's cwd, `send-keys` the type command, mark type, `select-window`. Duplicates get names `TYPE-N`.
- Window reordering via `swap-window -d` / `move-window -d`.
- Sets session option `@dotfiles_tmux_template=standard` and window option `@dotfiles_window_type`.
- Session-scoped mutex via tmux wait-for channel `dotfiles-tmux-template-<session_id>` (lock released on EXIT/HUP/INT/TERM traps).
- Spawns `codex`/`nvim`/`todo` processes indirectly by typing into new windows.

Configuration inputs:
- Env: `DOTFILES_LIB_DIR`, `TMUX_SESSION_TEMPLATE_SOCKET` → `DOTFILES_TMUX_SOCKET_NAME` (test socket), `DOTFILES_TMUX_TEMPLATE=skip` (per-session opt-out via tmux env).
- Prefs (via `dotfiles_pref` from prefs.sh / `~/.config/dotfiles/preferences.toml`): `assistant` (default `codex`), `terminal_editor` (default `nvim`).
- Hardcoded worth exposing: window type set and fixed indices (terminal=0, codex=1, nvim=2, tuxedo=3), the `todo` command for tuxedo, `hs-*` session-name exclusion prefix.

---

## tmux-window-program

Source: `modules/terminal-window-types/bin/tmux-window-program` (bash).

Invoked by:
- CLI: `tmux-window-program PANE_TTY`.
- tmux status line (`tmux-status.conf.tmpl`): `set -g @dotfiles_window_label '#("$HOME/bin/tmux-window-program" #{pane_tty})'` — run repeatedly by tmux's `#()` status interval for every window.

System behaviors:
- Read-only: runs `ps -t <tty>` to find the foreground process-group leader (pid==pgid==tpgid) and prints a friendly label (`~` for an idle shell, script basename for interpreters like node/bun/python, otherwise the command name). No tmux mutations, no files, no signals. Falls back to `?` on failure.

Configuration inputs:
- None (no env vars). Hardcoded: interpreter list (node/bun/deno/python/ruby/perl), shell list, script-suffix stripping (`.js/.ts/.py/...`), idle-shell glyph `~`.

---

## tmux-yazi-pane

Source: `modules/tmux-yazi/bin/tmux-yazi-pane` (bash). Sources `core.sh`, `tmux.sh` from `$DOTFILES_LIB_DIR`.

Invoked by:
- CLI: `toggle [PANE]` (PANE defaults to `$TMUX_PANE`).
- tmux binding `prefix b`: `run-shell "$HOME/bin/tmux-yazi-pane toggle '#{pane_id}'"`; also which-key pane menu.

System behaviors:
- Toggle logic: if the window already has a pane marked `@dotfiles_yazi_side=1`, `kill-pane` all such panes; otherwise `split-window -h -f -l 40%` in the source pane's cwd running `env EDITOR=$HOME/bin/tmux-yazi-open yazi <dir>` and marks the new pane.
- Guard: never kills the last pane in a window; won't split when the source pane itself is a full-window yazi.
- Window-scoped mutex via tmux wait-for channel `dotfiles-yazi-pane-<window_id>`; lock released via EXIT/HUP/INT/TERM traps.
- Spawns a `yazi` process; sets pane option `@dotfiles_yazi_side`.

Configuration inputs:
- Env: `DOTFILES_LIB_DIR`, `TMUX_YAZI_PANE_SOCKET` → `DOTFILES_TMUX_SOCKET_NAME`, `DOTFILES_TMUX_BIN`.
- Requires `yazi` on PATH. Hardcoded worth exposing: 40% split width, horizontal full-height orientation, EDITOR override path `$HOME/bin/tmux-yazi-open`.

---

## tmux-yazi-open

Source: `modules/tmux-yazi/bin/tmux-yazi-open` (bash). Sources `core.sh`, `tmux.sh`.

Invoked by:
- CLI: `tmux-yazi-open FILE...` — but in practice invoked *by yazi* as `$EDITOR` (set by tmux-yazi-pane) when opening files from the side pane. Requires `$TMUX_PANE`.

System behaviors:
- Finds a running Neovim in the current session: windows typed `@dotfiles_window_type=nvim` (or named `nvim`/`nvim-N`) containing a pane whose current command is `nvim`; re-stamps the window type option when found.
- If none, shells out to `$HOME/bin/tmux-session-template new <session> nvim <pane>` to create one, then polls up to 40×50ms for nvim readiness.
- Injects keystrokes into the nvim pane: `send-keys Escape Escape`, then a literal `:execute 'tab drop ' . fnameescape('<path>')` command and `Enter` for each file — remote-controls Neovim through its terminal.
- `select-pane` + `select-window` to focus the editor.
- Rejects filenames with control characters; resolves relative paths to absolute.

Configuration inputs:
- Env: `DOTFILES_LIB_DIR`, `TMUX_YAZI_OPEN_SOCKET` → `DOTFILES_TMUX_SOCKET_NAME`, `TMUX_SESSION_TEMPLATE_BIN` (default `$HOME/bin/tmux-session-template`), `DOTFILES_TMUX_BIN`, `TMUX_PANE` (required).
- Hardcoded worth exposing: 40×0.05s readiness poll, `tab drop` open strategy.

---

## tmux-command-palette

Source: `home/bin/executable_tmux-command-palette` (bash; lives directly under home/bin, no module bridge).

Invoked by:
- CLI: no args (open palette; must be inside tmux), `--dump-json`, `--self-test`, `--execute-file PATH` (internal).
- tmux bindings: `prefix Space` and global `S-F7` → `display-popup -EE -w 95% -h 92% -d "#{pane_current_path}" -T "tmux · Telescope" "$HOME/bin/tmux-command-palette"`.

System behaviors:
- Creates a temp selection file `${TMPDIR:-/tmp}/tmux-command-palette.XXXXXX` (removed via trap / after execution).
- Runs interactive `nvim -n --cmd 'set shadafile=NONE'` loading `custom.tmux_commands` Telescope UI (searches live tmux bindings + curated actions); the UI writes the chosen tmux command into the selection file.
- Executes the selection via `tmux run-shell -C "display-popup -C ; <command>"` — closes the popup then runs an arbitrary tmux command in the invoking client context (can be any tmux mutation the palette offers).
- `--dump-json`/`--self-test`: headless `nvim -u NONE` with runtimepath extended to the user config.

Configuration inputs:
- Env: `TMUX_COMMAND_PALETTE_NVIM_CONFIG` (default `~/.config/nvim`), `TMPDIR`, `TMUX` (must be set for interactive mode), `TMUX_COMMAND_PALETTE_SELECTION_FILE` (passed to the lua UI).
- Hardcoded: popup geometry lives in the binding; lua module name `custom.tmux_commands`.

---

## tmux-border-accent

Source: `modules/appearance-pip/bin/tmux-border-accent` → deployed via `home/bin/executable_tmux-border-accent.tmpl` (gated on `.modules.appearancePip.enabled`).

Invoked by:
- CLI: `start [WIDTH] [INACTIVE_COLOR]`, `update` (default), `suppress-scratchpads [WINDOW_ID]`.
- tmux hooks (modules/appearance-pip/targets/tmux.conf.tmpl), all `run-shell -b "$HOME/bin/tmux-border-accent update"` at slot [60]: `client-attached`, `client-detached`, `client-focus-in`, `client-focus-out`, `client-session-changed`, `after-rename-session` — fires on essentially every client focus/session change.
- `start` is expected to be run by the JankyBorders launch path (long-running: it `wait`s on the borders process).

System behaviors (macOS-heavy):
- Reads the focused tmux client's `@dotfiles_status_accent` session option (`list-clients`) and converts it to a `0xffRRGGBB` border color.
- Drives **JankyBorders** (`borders`): `start` launches it in the background with style/width/colors and blocks on it (service lifecycle); `update` sends a live `active_color=` reconfiguration; both apply per-window `width=0`, transparent-color overrides to every yabai scratchpad window.
- Queries **launchctl** (`launchctl print gui/$(id -u)`) to check the borders Mach service `git.felix.borders` is published before sending commands.
- Queries **yabai** (`yabai -m query --windows` + `jq`) to enumerate scratchpad window IDs.
- `pgrep -x borders` to detect a running instance. Silently no-ops when borders is unavailable.
- No tmux mutations, no file writes; purely macOS window-server cosmetics.

Configuration inputs:
- Env: `TMUX_BORDER_ACCENT_BORDERS_BIN`, `_TMUX_BIN`, `_YABAI_BIN`, `_JQ_BIN`, `_LAUNCHCTL_BIN`, `TMUX_BORDER_ACCENT_MACH_SERVICE` (default `git.felix.borders`), `TMUX_BORDER_ACCENT_WIDTH` (4.0), `TMUX_BORDER_ACCENT_INACTIVE_COLOR` (0xff000000), `TMUX_BORDER_ACCENT_TRANSPARENT_COLOR`, `TMUX_BORDER_ACCENT_SUPPRESS_ATTEMPTS` (4), `TMUX_BORDER_ACCENT_SUPPRESS_RETRY_DELAY` (0.05).
- tmux option: `@dotfiles_status_accent` (set elsewhere by the status/appearance modules).
- Chezmoi: `.modules.appearancePip.enabled` gates deployment.
- Hardcoded worth exposing: `style=square`, `hidpi=on`, `ax_focus=on`.

---

## agent-timer

Source: `modules/agent-timer/bin/agent-timer` (bash, ~2080 lines) → deployed via `home/bin/executable_agent-timer.tmpl` (gated on `.modules.agentTimer.enabled`). Sources `core.sh`, `locks.sh`, `state.sh` from `$DOTFILES_LIB_DIR`.

Invoked by:
- CLI: `start [--seconds N --target T --id --turn-id --message --warning-message --warning-seconds --json]`, `status [--id --json]`, `sessions [--json]`, `manage` (interactive TUI), `close SESSION [--yes] [--force-active]`, `cancel --id ID`, `shutdown [--reason] [--automatic-only]`, `enable`, `prune`, `tick`, `install-cron`, `uninstall-cron`, `hook` (Codex lifecycle hook, reads JSON on stdin), internal `_fire`, `_worker`, `_report-worker`.
- tmux binding `prefix T` (modules/agent-timer/targets/tmux.conf.tmpl): `display-popup … "$HOME/bin/agent-timer manage"`.
- Codex hooks: `hook` handles `UserPromptSubmit` (auto-arm), `SubagentStart`, `PreToolUse`, `Stop` events.
- cron (self-installed): `* * * * * $SELF tick # agent-timer backstop`.

System behaviors:
- **State files**: JSON per timer under `~/.local/state/agent-timer/` (`AGENT_TIMER_STATE_DIR`, dir chmod 700, files 0600 atomic writes), plus `.lock` dirs, session locks, a `lifecycle.lock`, a `module-disabled` latch file, and per-checkpoint side-report artifacts `*.checkpoint-<id>.md/.log/.request[.timeout]`.
- **Process spawning/killing**: launches a recurring `_worker` *inside the tmux server* via `tmux run-shell -b -t <pane>` (worker polls state, sleeps, fires warning/expiry); spawns detached `_report-worker` and `_fire` via `nohup … &`; at expiry for Codex agents launches a sandboxed `codex … exec --ephemeral --ignore-user-config --sandbox read-only --output-last-message <report.md>` side report with a watchdog that TERM/KILL-escalates the process group on timeout; kills workers/side reports (kill, kill -KILL, process-group `kill -- -PGID`, full descendant-tree termination with start-time fingerprinting) on cancel/stop/shutdown/close.
- **tmux mutations**: `kill-session` in `close` (after triple-checking the session has no attached clients, agents, or active timers, with interactive confirmation or `--yes --force-active`); otherwise read-only tmux inspection (`display-message`, `list-panes -a`). Never types into panes (design invariant: expiry uses notifications only).
- **macOS state**: `terminal-notifier` notifications (timer warnings, checkpoint due, report ready/failed, stale-target notices); `afplay /System/Library/Sounds/<Sound>.aiff` on expiry (fallback: BEL written to the pane's tty *output*); `crontab` modified by `install-cron`/`uninstall-cron` (marker-line dedup; temp files in `$TMPDIR`).
- **Process inspection**: walks `ps -axo pid,ppid` up to depth 8 to fingerprint agent processes (hermes/codex/claude/opencode) under each pane, validating pid + start-time + command line before any action.
- `manage`: interactive loop over `sesh list --tmux --json` inventory; Enter execs the sesh picker; typing a name closes that session.
- `shutdown` writes the disabled latch (blocks new timers until `enable` removes it).
- `tick` (cron backstop): fires overdue warnings/expiries for all states and prunes terminal states older than retention.

Configuration inputs:
- Config file: `~/.config/agent-timer/config.toml` (`AGENT_TIMER_CONFIG_FILE`), parsed with `yq`; keys: `default_seconds`, `warning_seconds`, `retention_seconds`, `report_timeout_seconds`, `expiry_sound`, `auto_start`, `preferred_agents[]`.
- Env overrides: `TASK_TIMELIMIT_SECS`, `TASK_TIME_WARNING_SECS`, `AGENT_TIMER_RETENTION_SECS`, `AGENT_TIMER_REPORT_TIMEOUT_SECS`, `AGENT_TIMER_EXPIRY_SOUND`, `AGENT_TIMER_AUTO_START`, `AGENT_TIMER_PREFERRED_AGENTS`, `AGENT_TIMER_EXPIRY_MESSAGE`, `AGENT_TIMER_WARNING_MESSAGE`, `AGENT_TIMER_NO_WORKER`, `AGENT_TIMER_SOUND_DIR`, `AGENT_TIMER_WORKER_POLL_SECONDS` (5), `AGENT_TIMER_WORKER_REGISTRATION_ATTEMPTS` (40), plus bin overrides `AGENT_TIMER_{PATH,STATE_DIR,TMUX_BIN,SESH_BIN,JQ_BIN,YQ_BIN,PS_BIN,CRONTAB_BIN,NOTIFIER_BIN,AFPLAY_BIN}` and test hooks `AGENT_TIMER_NOW`, `AGENT_TIMER_TEST_AGENT_PID`.
- Defaults worth noting: 600s timer, 60s warning, 7-day retention, 120s report timeout, `Ping` sound, auto_start=false; PATH pinned to `~/bin:/opt/homebrew/bin:/usr/local/bin:...`.
- Chezmoi: `.modules.agentTimer.enabled` gates deployment and the `prefix T` binding.

---

# Cross-cutting notes

- **Shared marker options**: `@dotfiles_window_type` is written by tmux-workspace, tmux-session-template, and tmux-yazi-open; `@dotfiles_tmux_template` distinguishes `standard` (template) vs `workspace` ownership. `DOTFILES_TMUX_TEMPLATE=skip` (session env) is the universal opt-out honored by the `after-new-session[50]` auto-template hook; tmux-hub, tmux-workspace, and daemon all set it on the sessions they create.
- **tmux hooks installed by this family**: `after-new-session[50]` (session-template auto), six client/session hooks at slot [60] (border-accent update), tmux-resurrect save/restore hooks (workspace snapshot).
- **Files under /tmp**: daemon logs+pids (`/tmp/NAME.{log,pid}`), tmux-hub reply temp files, command-palette selection files, agent-timer cron temp files.
- **macOS-touching**: tmux-hub `open-window` (Ghostty via `open`), tmux-border-accent (JankyBorders/yabai/launchctl), agent-timer (terminal-notifier, afplay, crontab).
- **sesh dependency**: sessionizer trio and agent-timer `manage`/`sessions` all require `sesh`; picker flags are hardcoded in four places and could be centralized as a user setting.


Repo: `/Users/adhipkashyap/dotfiles` (chezmoi source state; `home/bin/executable_*.tmpl` wrappers `includeTemplate` the module sources and are gated on `.modules.<key>.enabled` chezmoi data flags, exporting `DOTFILES_DIR={{ .chezmoi.sourceDir | dir }}`).

---

## dotfiles-settings
Source: `modules/settings/bin/dotfiles-settings` (bash, 518 lines), rendered to `~/bin/dotfiles-settings` via `home/bin/executable_dotfiles-settings.tmpl` (gated on `modules.settings.enabled`).
Invoked by: user CLI (`pick`/`list`/`get`/`set`/`validate`); `dotfiles-manager-ui` backend (`list --json`, `set KEY VALUE --json`); fzf interactive picker is the default subcommand.
System behaviors:
- Writes setting values into `home/.chezmoidata/*.yaml` files in the source repo via `yq -i` (atomic tmp+`mv`), with a backup copy in `$TMPDIR` and rollback on failure.
- **chezmoi apply**: `chezmoi -S $ROOT apply --force --source-path <bridge files...>` after every `set` (unless `--no-apply`) — re-renders only the registry-declared bridge templates into `$HOME`.
- Verifies effective value with `chezmoi data --format json` and refuses/rolls back if a machine override in `~/.config/chezmoi` masks the key.
- Service reloads (per registry `reload:` list, unless `--no-reload`): `skhd --restart-service`; `tmux source-file ~/.tmux.conf`; `pkill -USR2` targeting the Ghostty.app process (config reload signal); executes `~/bin/reload-colors`.
- Artifact regeneration (`regenerate: shortcuts`): runs `shortcut-catalog update --root $ROOT` (which itself invokes chezmoi and may compile Swift; see shortcut-catalog).
- Locking: mkdir-style lock dirs `$ROOT/.dotfiles-settings.lock` (or `$ROOT/.dotfiles-module.lock` when editing `10-modules.yaml`) via the shared lib `home/dot_local/lib/dotfiles/{core.sh,locks.sh}`.
- Enumerates `/Applications`, `~/Applications`, `/System/Applications` (macos-apps value provider) and `/System/Library/Sounds/*.aiff` (macos-sounds provider); no network calls; no sudo; no git.
Configuration inputs:
- Env: `DOTFILES_DIR`, `DOTFILES_SETTINGS_REGISTRY`, `DOTFILES_SETTINGS_DATA_FILE` (test override), `DOTFILES_SETTINGS_{YQ,JQ,FZF,CHEZMOI,TMUX,SKHD}_BIN`, `TMPDIR`.
- Files: `modules/settings/registry.yaml` (apiVersion `dotfiles/v1`, kind `SettingsRegistry`, schemaVersion 1; per-setting key/type/dataPath/file/bridges/reload/regenerate/values), `home/.chezmoidata/*.yaml` data files, `home/dot_config/colorschemes/executable_*.sh` (colorschemes provider).
- Chezmoi data keys: whatever `dataPath` each registry entry names (all under `home/.chezmoidata`).
- Hardcoded worth exposing: lock timeout 10000ms; fzf UI options; Ghostty pkill pattern; `~/bin/reload-colors` path.

## dotfiles-module
Source: `modules/module-lifecycle/bin/dotfiles-module` (bash, 517 lines), rendered via `home/bin/executable_dotfiles-module.tmpl` (NOT feature-gated — always installed).
Invoked by: user CLI (`validate`/`status`/`plan`/`enable`/`disable`/`uninstall`/`purge`); `dotfiles-manager-ui` (`status --json`).
System behaviors:
- Toggles `modules.<key>.enabled` booleans in `home/.chezmoidata/10-modules.yaml` via `yq -i` on a temp copy, atomic `mv`, backup + rollback on apply failure.
- **chezmoi apply**: `chezmoi -S $ROOT apply --force --source-path <manifest target bridges>` on enable/disable/uninstall/purge; on failure the data file is restored and bridges re-applied (rollback), so a failed apply triggers a second apply.
- **Deletes files under $HOME**: `uninstall` removes declared `state.ephemeral` paths; `purge` (requires `--confirm <module-id>` exact match) additionally `rm -rf`s declared `state.preserved` paths. Globs are expanded relative to `$HOME` (`~/...` entries) or `--state-root` (`./...` entries) with symlink-traversal and root-escape guards. tmux-pane-option:/tmux-wait-channel: handles are retained (no generic remover).
- Locking: `$ROOT/.dotfiles-module.lock` via shared lock lib; refuses to remove `module-lifecycle` itself.
- Extensive manifest validation (id/dataKey/targets/state schema, path-safety, symlink components); read-only `plan` subcommands print or emit JSON plans without changes.
- No Homebrew, no sudo, no git, no network.
Configuration inputs:
- Env: `DOTFILES_DIR`, `HOME` (must be absolute non-symlink dir).
- Files: `modules/*/module.yaml` manifests (apiVersion `dotfiles/v1`; `dataKey`, `targets[].{source,destination,bridge,ownership}`, `state.{preserved,ephemeral}`), `home/.chezmoidata/10-modules.yaml`.
- Chezmoi data keys: `modules.<camelCaseKey>.enabled` for every module.
- Hardcoded worth exposing: lock timeout 10000ms; data file path `home/.chezmoidata/10-modules.yaml`.

## dotfiles-deps
Source: `modules/dependencies/bin/dotfiles-deps` (python3, 1219 lines), rendered via `home/bin/executable_dotfiles-deps.tmpl` as a `/bin/sh` heredoc piped to `python3 -` (gated on `modules.dependencies.enabled`).
Invoked by: user CLI (`status`/`check`/`snapshot`/`pins check|apply`); `dotfiles-manager-ui` (`status --json`).
System behaviors:
- `status`: fully offline inventory — parses Brewfile, module manifests (via `yq` subprocess), `.chezmoidata.toml`, `.chezmoiexternal.toml`, tmux plugin declarations, Yazi `package.toml`, Neovim `lazy-lock.json`, VSCodium extension list, and `dependencies.lock.json` snapshot; runs `shutil.which()` probes only.
- `check`: spawns **Homebrew read-only operations** — `brew tap`, `brew outdated --json=v2`, `brew info --json=v2 --formula|--cask NAME` per Homebrew record, `brew list --versions` fallback (brew may itself hit the network for `outdated`/`info` depending on brew config); **git read operations** `git -C <checkout> rev-parse HEAD` and `git status --porcelain` for every chezmoi external / tpm plugin / local-git plugin checkout under `$HOME`; exit 1 on manager errors.
- `snapshot`: same probes plus `codium --list-extensions --show-versions`; prints a new `dependencies.lock.json` payload to stdout (does not write the file itself); refuses (raises) if any required manager is unavailable.
- `pins apply`: **mutates git checkouts under $HOME** — `git -C <path> cat-file -e <rev>^{commit}` then `git checkout --quiet --detach <pinned-revision>` for each `gitPins` entry (chezmoi/tpm managed checkouts); skips checkouts with modified tracked files; never fetches (fails with "fetch it explicitly" if commit absent).
- No chezmoi apply (only `chezmoi source-path` for root discovery when `DOTFILES_DIR` unset), no sudo, no service restarts, no file writes/deletes.
Configuration inputs:
- Env: `DOTFILES_DIR` (else derives from script location or `chezmoi source-path`).
- Files: `modules/dependencies/config/sources.toml` (schema_version 1; `sources.{brewfile,modules,chezmoi_data,chezmoi_externals,tmux,tmux_installer,yazi,neovim}`, `runtime.{shared_library_dir,tmux_plugin_dir}`, `local_git_plugins[]` with 40-hex commit pins), `Brewfile`, `home/.chezmoidata.toml` (`gitPins`, `vscodeExtensions`, `chromeExtensions`, `externalProjects`), `.chezmoiexternal.toml`, `modules/*/module.yaml`, `modules/dependencies/dependencies.lock.json`.
- Hardcoded worth exposing: `EXECUTABLE_BREW_ALIASES` (nvim→neovim, python3→python, rg→ripgrep), `PLATFORM_EXECUTABLES`, `MANAGER_EXECUTABLES` sets; SCHEMA_VERSION 1.

## dotfiles-uninstall
Source: `modules/system-uninstall/bin/dotfiles-uninstall` (bash, 645 lines), rendered via `home/bin/executable_dotfiles-uninstall.tmpl` (gated on `modules.systemUninstall.enabled`).
Invoked by: user CLI (`plan` default / `execute --confirm 'REMOVE DOTFILES FROM $HOME'` / `restore RUN_ID --confirm 'RESTORE DOTFILES TO $HOME'`); `dotfiles-manager-ui` (`plan --json` for the System view).
System behaviors:
- `plan`: read-only — runs `chezmoi managed --include=files,symlinks|dirs` and `chezmoi verify` per leaf; emits plan JSON; no changes.
- `execute` (**destructive, exact-confirmation string required**): under `$ROOT/.dotfiles-module.lock` + a state execution lock, creates a run dir `$XDG_STATE_HOME/dotfiles/system-uninstall/runs/<UTC-ts>-<pid>` (mode 700, umask 077), snapshots plan + module manifests, **backs up every existing managed leaf** (`cp -pP` + cksum/readlink fingerprint verification), then **deletes every chezmoi-managed file/symlink under $HOME** (via `$REMOVE_BIN -f`, default `rm`; lifecycle controller and itself removed last) and `rmdir`s empty managed directories deepest-first. Preserved: source repo, `~/projects`, `$XDG_STATE_HOME`, module `state.preserved` paths, Homebrew packages, tmux plugins/sessions, yabai/skhd services.
- Quiesce: runs `~/bin/agent-timer shutdown --reason system-uninstall` if present (process/service stop); `restore` re-runs `agent-timer enable`.
- `restore`: re-creates original directories (mode-restored) and copies fingerprint-verified backups back; refuses to overwrite anything created post-uninstall.
- Every step journaled in `ledger.json` (jq read-modify-write, chmod 600); failures recorded in `failure.txt`; fingerprint preflight aborts if any target changed after backup. Never uses `chezmoi destroy/purge/forget`.
- No Homebrew, no sudo, no git, no network.
Configuration inputs:
- Env: `DOTFILES_DIR`, `HOME`, `XDG_STATE_HOME` (default `~/.local/state`), `DOTFILES_UNINSTALL_REMOVE_BIN` (removal command override, default `rm`), `TMPDIR`.
- Files: `$ROOT/.chezmoiroot` (repo validity check), `modules/*/module.yaml` (`state.preserved` inventory), shared lock lib `home/dot_local/lib/dotfiles/{core.sh,locks.sh}`.
- Hardcoded worth exposing: confirmation phrases; lock timeout 10000ms; preserved prefixes (`projects`, source repo, state home); `~/bin/agent-timer` path.

## dotfiles-manager
Source: `modules/dotfiles-manager/bin/dotfiles-manager` (bash), rendered via `home/bin/executable_dotfiles-manager.tmpl` (gated on `modules.dotfilesManager.enabled`).
Invoked by: user CLI / skhd hotkey (`open`); tmux navigation (`tmux select terminal|settings`); its settings window re-invokes it (`ui`).
System behaviors:
- **tmux session management**: creates/curates a dedicated tmux session (default `dotfiles-manager`) with `settings` (runs `dotfiles-manager ui`), and `terminal` windows; sets many session/window options (status bar styling, `@dotfiles_manager_role` markers); `switch-client`/`attach`.
- `open`: delegates to `~/bin/scratchpads open command <label> codex $root "<manager> tmux attach"` (yabai scratchpad window spawn via Ghostty).
- `theme edit`: creates `~/.config/dotfiles-manager/theme.tcss` (copied from theme.example.tcss if present) and `exec`s `$VISUAL`/`$EDITOR`/nvim on it.
- `rules`: prints (does not run) yabai rule add/remove commands for the scratchpad.
- No chezmoi, no Homebrew, no sudo, no git, no direct network.
Configuration inputs:
- Env: `DOTFILES_MANAGER_{ROOT,TMUX_SESSION,SCRATCHPAD_LABEL,SCRATCHPADS_BIN,COMMAND,UI_BIN,THEME,THEME_EXAMPLE}`, `VISUAL`/`EDITOR`, `TMUX`.
- Files: `theme.tcss`/`theme.example.tcss`. The panel has only Terminal and Settings surfaces and does not configure or launch Hermes.
- Hardcoded worth exposing: default `root=$HOME/dotfiles`, session name, scratchpad label `dotfiles_manager`, Catppuccin status-bar colors, scratchpad grid `10:10:1:1:8:8`.

## dotfiles-manager-ui
Source: `modules/dotfiles-manager/bin/dotfiles-manager-ui` (Python/Textual, 862 lines; shebang `#!/usr/bin/env -S uv run --script` with PEP 723 inline metadata: `textual==8.2.8`, python>=3.11, uv `exclude-newer` 2026-07-01), rendered via `home/bin/executable_dotfiles-manager-ui.tmpl`; a companion uv lock is rendered from `home/bin/dotfiles-manager-ui.lock.tmpl` ← `modules/dotfiles-manager/bin/dotfiles-manager-ui.lock`.
Invoked by: `dotfiles-manager ui` (inside the manager tmux session); direct CLI; `--self-test` for CI.
System behaviors:
- **uv script bootstrap**: first run may hit the network to resolve/download textual + deps into uv's cache (lockfile pins versions).
- Spawns subprocesses of the other utilities: `dotfiles-settings list/set --json` (with `DOTFILES_DIR` injected, cwd=$root), `dotfiles-module status --json`, `dotfiles-deps status --json`, `dotfiles-uninstall plan --json`. All mutation flows go through `dotfiles-settings set`, which does chezmoi apply + service reloads (see above).
- Reads `modules/shortcut-guide/generated/shortcuts.json` for the Shortcuts view.
- No direct file writes, sudo, git, or Homebrew.
Configuration inputs:
- Env: `DOTFILES_MANAGER_SETTINGS_BIN` (default `~/bin/dotfiles-settings`), `DOTFILES_MANAGER_ROOT` (default `~/dotfiles`), `DOTFILES_MANAGER_MODULE_BIN`, `DOTFILES_MANAGER_DEPS_BIN`, `DOTFILES_MANAGER_UNINSTALL_BIN`, `DOTFILES_MANAGER_SHORTCUTS`, `DOTFILES_MANAGER_THEME` (`~/.config/dotfiles-manager/theme.tcss` CSS override).
- Hardcoded worth exposing: embedded Catppuccin CSS; responsive breakpoints (100/68 cols); notify timeout 8s; textual pin `8.2.8`.

## Dotfiles native utility host
Source: `modules/dotfiles-control-center/Sources/ExtensionKit`, `Sources/UtilityCLI`,
and the SwiftUI Utilities view. Build: `scripts/build-app.py`, also exposed as
`make build-app` and `bootstrap.sh --app`.

- Stores imported executable packages, registry/settings/shortcuts, and utility
  data under `~/Library/Application Support/Dotfiles/Utilities`; registry writes
  are locked and atomic. Newly imported utilities are disabled. Removal keeps
  the utility data directory.
- Runs declared executable paths or resolved external tools with literal argv,
  optional stdin, controlled environment, timeout, cancellation, and output limits.
  Utility processes run with the user's permissions; packages are trusted code.
- Registers enabled noninteractive action shortcuts with macOS while the app runs.
  It does not rewrite or migrate the existing skhd configuration.
- Writes deterministic owned `dev.dotfiles.utility.<hash>.plist` LaunchAgents;
  explicit start/restart uses `launchctl bootstrap`, stop uses `bootout`. Services
  run at login and can continue after the app quits. Disable/removal stops them.
  A bundled launchd-owned supervisor retries crashes up to three times with
  2/4/8-second backoff and retains 1 MiB active plus 1 MiB backup per channel.
  App/CLI lifecycle mutations and action execution share a lease and durable
  recovery journal; interrupted updates restore prior settings and services.
- Uses `SMAppService.mainApp` only when the user changes Open at login.
- Builds/codesigns a generated `.app` and ZIP without applying personal config.
  Developer ID signing and notarization are explicit release operations.

See [NATIVE_APP.md](NATIVE_APP.md) for paths, update/rollback boundaries, prerequisites,
and uninstall instructions; [EXTENSION_AUTHORING.md](EXTENSION_AUTHORING.md) defines
the environment and extension hooks. Third-party commands retain their own effects.

## dotfiles-control-center source launcher
Source: `modules/dotfiles-control-center/bin/dotfiles-control-center` (bash launcher, 20 lines) fronting a Swift package in the same module; rendered via `home/bin/executable_dotfiles-control-center.tmpl` (gated on `modules.dotfilesControlCenter.enabled`, exports `DOTFILES_DIR`).
Invoked by: user CLI / hotkeys.
System behaviors:
- `exec /usr/bin/env swift run --package-path $MODULE_DIR --configuration release dotfiles-control-center "$@"` — **compiles the Swift package on first run/after changes** (SwiftPM writes build artifacts under `<module>/.build`; may resolve/fetch SwiftPM dependencies over the network if Package.swift declares any) and then runs the native app.
- Exports `DOTFILES_CONTROL_CENTER_CWD` (caller's cwd) to the Swift process. Behaviors of the compiled app itself are out of scope of this launcher (separate Swift source audit).
Configuration inputs:
- Env: `DOTFILES_DIR` (module dir resolution), `DOTFILES_CONTROL_CENTER_CWD` (set by launcher).
- Files: `modules/dotfiles-control-center/Package.swift` (existence-checked).
- Hardcoded worth exposing: build configuration `release`.

## shortcut-catalog
Source: `modules/shortcut-guide/bin/shortcut-catalog` (python3, 346 lines), rendered via `home/bin/executable_shortcut-catalog.tmpl` (sh heredoc → `python3 -`; gated on `modules.shortcutGuide.enabled`; exports `DOTFILES_DIR` and `SHORTCUT_GUIDE_MODULE_DIR`).
Invoked by: user CLI / `make shortcuts-update` / `make shortcuts-check`; `dotfiles-settings` regenerate hook (`shortcuts`).
System behaviors:
- Renders desired skhd config with `chezmoi -S ROOT cat ~/.skhdrc` (read-only chezmoi).
- **Compiles Swift**: unless `SHORTCUT_CATALOG_WHICHKEY_BIN` points at a prebuilt binary, runs `modules/shortcut-guide/install/build-whichkey.sh` (swiftc build into a temp dir) then executes `whichkey --dump-json` on the rendered skhdrc to extract bindings.
- Validates binding owners against `modules/*/module.yaml` ids; writes (mode `update`) or verifies (mode `check`, exit 1 when stale) `modules/shortcut-guide/generated/shortcuts.{json,md}` via fsync'd atomic replace, chmod 644 — writes inside the source repo, not $HOME.
- No Homebrew, sudo, git, or network.
Configuration inputs:
- Env: `SHORTCUT_GUIDE_MODULE_DIR`, `DOTFILES_DIR`, `SHORTCUT_CATALOG_CHEZMOI_BIN` (default `chezmoi`), `SHORTCUT_CATALOG_WHICHKEY_BIN`, `WHICHKEY_BUILD_PATH`/`WHICHKEY_INSTALL_PATH` (passed to build script), `HOME`.
- CLI: `update|check`, `--root`, `--output-dir`.
- Hardcoded worth exposing: `CATEGORY_ORDER` map; required binding fields; SCHEMA_VERSION 1.

## man-me
Source: `home/bin/executable_man-me` (bash, 621 lines; installed verbatim, not a template).
Invoked by: user CLI (`man-me [QUERY] [--installed|--source DIR] [--category NAME] [--all]`).
System behaviors:
- Read-only reference generator: scans for `# man-me:` metadata comments using `rg -l` (or `find`+`grep` fallback) across the chezmoi source tree (source mode) or `~/bin`, `~/.config/{skhd,yabai,zsh}`, `~/.zshrc`, `~/.skhdrc`, `~/.yabairc` (installed mode); also discovers un-catalogued bins/helpers and zsh functions (sed over `zshrc.commands`).
- May run `chezmoi source-path` for source-tree auto-detection; may use `fzf --filter` for matching. No writes, no network, no sudo, no services.
Configuration inputs:
- Env: `DOTFILES_DIR`, `HOME`.
- Convention: `# man-me: name/category/usage/description/tags/source=` comment blocks in each tool's source.
- Hardcoded worth exposing: installed-mode scan path list; source→installed path mapping table (large case statement, includes special cases for karabiner, skhdrc, projectdeck, app-focus helpers).

## hermes-dotfiles
Source: `modules/hermes-agent/bin/hermes-dotfiles` (bash, 30 lines), rendered via `home/bin/executable_hermes-dotfiles.tmpl` (gated on `modules.hermesAgent.enabled`).
Invoked by: user CLI; tmux/session templates that open the assistant window (per `preferences.assistant` setting).
System behaviors:
- Validates the Hermes profile exists (`hermes profile show <profile>`), then `exec hermes -p <profile> [args|--tui]` — spawns the Hermes agent process (which has its own broad tool surface: network, file writes, etc., outside this wrapper's scope). No other system behavior.
Configuration inputs:
- Env: `HERMES_DOTFILES_PROFILE` (default `dotfiles`), `HERMES_DOTFILES_BIN` (default: `hermes` on PATH).
- Hardcoded worth exposing: exit codes 127 (no hermes) / 69 (no profile); default `--tui` when argless.

## ghostty-startup-bench
Source: `home/bin/executable_ghostty-startup-bench` (zsh, 227 lines; installed verbatim).
Invoked by: user CLI (`ghostty-startup-bench [iterations]`, default 5).
System behaviors:
- Benchmarks login-shell startup by repeatedly spawning `/bin/zsh -lic "exit 0"`.
- **Spawns and closes GUI windows**: launches Ghostty windows via `ghostty +new-window` (non-macOS only) and `open -n -a Ghostty --args ...` (macOS; default + minimal-config variants running `/bin/cat`), polls `yabai -m query --windows` (jq) until each window appears, then closes it with `yabai -m window <id> --close`. 5s per-window timeout; 0.15s inter-sample sleep.
- No writes, no sudo, no network, no chezmoi/brew/git.
Configuration inputs:
- Env: `GHOSTTY_STARTUP_BENCH_SHELL_ONLY=1` (skip GUI benchmarks), `HOME` (window working directory).
- Requires yabai + jq for GUI benchmarks (skipped with warning otherwise).
- Hardcoded worth exposing: 5000ms window-wait deadline; sleep intervals; window title prefix `ghostty-bench:`.

## lucide-icons-excalidraw
Source: `home/bin/executable_lucide-icons-excalidraw.tmpl` (bash, 20 lines; template only for module gating context — body is static).
Invoked by: user CLI.
System behaviors:
- `cd ~/.local/share/raycast-extensions/raycast-lucide-excalidraw/projects/raycast-extension && exec npm run dev -- "$@"` — starts the Raycast extension dev server (**npm dev process; may install/fetch nothing itself but the dev server watches files and binds ports**). Errors out with guidance to run `chezmoi apply`/`bootstrap.sh` if the external checkout (chezmoi external, pinned in `gitPins`, cloned from `git@github.com:adhipk/raycast-lucide-excalidraw.git`) is missing.
Configuration inputs:
- Hardcoded checkout path `~/.local/share/raycast-extensions/raycast-lucide-excalidraw` (worth exposing as a setting); external managed by `home/.chezmoidata.toml` `externalProjects`/`gitPins`.

---

## browser-use-helium

Source: `home/bin/executable_browser-use-helium` → installed `~/bin/browser-use-helium`.

Invoked by: Codex CLI or user CLI for interactive browser work.

System behaviors:
- Reads Helium's `DevToolsActivePort` file and rejects a missing or malformed endpoint.
- Runs the separately installed Browser Use CLI against Helium's local DevTools WebSocket. Browser Use may inspect or change browser tabs and writes its daemon state under `~/.config/browser-harness`; this wrapper does not start a cloud browser.

Configuration inputs:
- Env: `HOME` for Helium's profile and `BH_TAB_MARKER` (defaults to `0` to leave tab titles unchanged).
- Browser Use CLI is installed at the `uv tool dir --bin` path by `bootstrap.sh`.

---

# External symlink-mounted commands

These `home/bin/symlink_*.tmpl` entries render as symlinks into `~/bin` pointing at external project checkouts under `~/projects` (cloned/pinned by chezmoi externals + `gitPins` in `home/.chezmoidata.toml`). Upstream code is not audited here.

## kit / kit-watch
Source: `home/bin/symlink_kit.tmpl`, `symlink_kit-watch.tmpl` (gated on `modules.kitTts.enabled`).
Invoked by: user CLI.
Mounts: `~/projects/kittentts-cli/kit` and `.../kit-watch` — upstream repo `kittentts-cli` (chezmoi external, commit-pinned via `gitPins`). TTS CLI + watcher.

## todo / chezmoi-todo
Source: `home/bin/symlink_todo.tmpl`, `symlink_chezmoi-todo.tmpl` (gated on `modules.todo.enabled`; both point at the same target).
Mounts: `~/projects/tuxedo-project-todo/bin/todo` — upstream `git@github.com:adhipk/tuxedo-project-todo.git`, commit-pinned.

## default-apps
Source: `home/bin/symlink_default-apps.tmpl` (gated on `modules.macosDefaultApps.enabled`).
Mounts: `~/projects/macos-default-apps/bin/default-apps` — upstream `macos-default-apps` repo, commit-pinned. (Sets macOS default-app handlers; system mutation happens upstream.)

## gh-create-repo
Source: `home/bin/symlink_gh-create-repo.tmpl` (gated on `modules.ghCreateRepo.enabled`).
Mounts: `~/projects/gh-create-repo/bin/gh-create-repo` — upstream `git@github.com:adhipk/gh-create-repo.git`, commit-pinned. (GitHub repo creation; network via `gh` upstream.)

## unescape-string / unescape-buffer
Source: `home/bin/symlink_unescape-string.tmpl`, `symlink_unescape-buffer.tmpl` (gated on `modules.unescapeCli.enabled`).
Mounts: `~/projects/unescape-cli/bin/unescape-{string,buffer}` — upstream `unescape-cli` repo, commit-pinned.

---

Audited utilities: 13 fully audited + 8 external symlink-mounted commands (6 distinct upstream repos) = 21 sections.

### Markdown clipboard

The `markdown-clipboard` module polls the macOS clipboard every 200 ms and adds HTML to plain-text Markdown copies, preserving the original text. Plain-text copies with Chromium/editor metadata qualify even when the editor language mode is null. VS Code Markdown-mode copies have their source-highlighted HTML replaced with rendered HTML while retaining editor metadata. It skips other rich, non-text, marked-sensitive and oversized copies. `markdown-clipboard once` explicitly processes the current clipboard; startup watches only new copies. Its after-apply hook compiles the Swift worker and registers `com.dotfiles.markdown-clipboard` in the user LaunchAgents directory. Code blocks use semantic HTML without syntax-highlighting spans or line links. Pandoc is installed by bootstrap; no clipboard content is logged or persisted. Disable through `dotfiles-module disable markdown-clipboard`; teardown unloads the agent and removes generated worker/plist files.
