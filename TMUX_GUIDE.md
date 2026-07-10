# tmux Integration Guide

## How tmux fits into your setup

**Your workflow:**
- **yabai** manages physical window placement (tiling windows on macOS)
- **tmux** manages terminal sessions/panes inside Ghostty windows
- **sesh** provides the shared built-in picker for tmux, configured, and zoxide sessions

## Quick Start

**First time setup:** The config is already installed! Just start using tmux.

```bash
# Start a new tmux session
tmux
# or named session
tmux new -s myproject

# Attach to existing session
tmux attach -t myproject
# or use alias
ta myproject

# List all sessions
tl

# Kill a session
tkss myproject
```

Ordinary new sessions automatically receive this window layout:

- `0 terminal` — raw shell
- `1 codex` — starts Codex
- `2 nvim` — starts Neovim
- `3 tuxedo` — opens that session directory's `todo.txt` through the `todo` wrapper

In Ghostty, the left Command layer stays application-local: `Cmd+Backtick/1/2/3`
cycles terminal/Codex/Neovim/Tuxedo windows by type, `Cmd+B` toggles one Yazi side
pane, and `Cmd+Shift+B` opens its dedicated tmux window. Terminal lifecycle
actions stay behind Control and the `Ctrl+A` prefix. Right Command carries only
four infrequent tmux-management actions in Ghostty; its chords pass through in
other apps, while sided Option and Hyper remain reserved. Sessions created with
an explicit command remain single-purpose. As with every tmux-accessible app,
Tuxedo inherits the same working directory as the session's other windows.
Compound/orchestrated session creators that add their own windows or queue
index-targeted commands must use
`tmux new-session -e DOTFILES_TMUX_TEMPLATE=skip ...`; `hs-*` sessions opt out
automatically.

## Command Center

Press `Ctrl+A Space`. The repo-owned menu groups the complete lifecycle:

- `s` — switch, create, rename, close, save/restore all state, or close detached managed layouts
- `w` — choose, create or duplicate typed windows, reorder, rename, or close windows
- `p` — navigate, split, resize, swap, break, or close panes
- `l` — open, reapply, or repair a declarative workspace layout

Sessions > Last uses tmux's per-client history, matching the direct `Ctrl+A L`
binding. Closing a session does not detach its clients; tmux keeps them
connected and moves them to a surviving session so the picker or last-session
action remains immediately available.

The active session name remains visible beside the current folder in the
bottom bar. Generated numeric sessions display their active folder instead,
and when a named session already matches its folder the duplicate context is
omitted. Its centered `~ · codex · nvim · tuxedo` selector uses a foreground-only
session accent for the active label, keeping normal and padded scratchpad
terminals aligned without a full-height color block. Resurrect and Continuum
save structure, directories, pane contents,
and an allowlist of interactive processes in the background. Neovim, Codex,
Tuxedo, and Yazi are restored; arbitrary development commands are deliberately not
restarted automatically. A workspace sidecar restores the custom layout IDs
that Resurrect itself does not retain.

## React-like layouts

Layouts live in `~/.config/tmux/layouts/*.tmux.tsx`. They use a small JSX
runtime built into `tmux-workspace`; React and `node_modules` are not involved.

```tsx
const Core = () => <><Terminal /><Codex /><Nvim focus /></>

export default (
  <Session root="$PROJECT_ROOT">
    <Core />
    <Window id="runtime" name="runtime">
      <Cols sizes="2fr 1fr">
        <Pane id="server" run="bun run dev" />
        <Rows>
          <Pane id="tests" run="bun test --watch" />
          <Pane id="shell" />
        </Rows>
      </Cols>
    </Window>
  </Session>
)
```

```bash
tmux-workspace list
tmux-workspace plan project --root "$PWD"
tmux-workspace open project --root "$PWD"
tmux-workspace apply project --root "$PWD"
tmux-workspace repair project --root "$PWD" --yes
```

`apply` creates missing windows without restarting healthy panes. If the pane
tree has drifted, it reports the affected window; `repair --yes` replaces only
those managed windows. Layout-created sessions opt out of the automatic
four-window hook and retain their declared typed terminal/Codex/Neovim metadata. A layout
will not take over a same-named unmanaged session unless `--adopt` is supplied.

Layouts are trusted local configuration: component functions execute while
`validate` or `plan` loads the file, while each pane's `run` command is deferred
until that pane is first created.

## Key Bindings

### Panes (most common)
- `Ctrl+A \|` - Split pane horizontally (keep current directory)
- `Ctrl+A -` - Split pane vertically (keep current directory)
- `Ctrl+A h/j/k/l` - Move between panes
- `Cmd+B` in Ghostty - Toggle one Yazi 40%-wide full-height right pane
- `Ctrl+A z` - Toggle zoom for the current pane

### Windows (like browser tabs)
- `Cmd+Shift+B` in Ghostty - Open or select a dedicated Yazi window
- `Cmd+Backtick/1/2/3` in Ghostty - Cycle terminal/Codex/Neovim/Tuxedo windows by type
- `Ctrl+0/1/2/3` - Cycle typed terminal/Codex/Neovim/Tuxedo windows without the prefix
- `Ctrl+Shift+0/1/2/3` - Create that typed window in the active pane's directory
- `Ctrl+4..9` - Select an exact higher window index without the prefix
- `Right Cmd+D` in Ghostty - Duplicate the current typed window in the active directory
- Command Center > Windows > Duplicate - The same duplicate action without the sided shortcut
- `Ctrl+A c` - Create a typed terminal window in the active directory
- `Ctrl+A p` - Previous window
- `Ctrl+A n` - Next window
- `Ctrl+A 0-9` - Switch to window by number (uses prefix)
- `Ctrl+A ,` - Rename window (uses prefix)
- `Ctrl+A &` - Kill window (uses prefix)

### Sessions (uses prefix)
- `Ctrl+A d` - Detach from session
- `Ctrl+A s` - Open sesh's built-in session picker
- `Ctrl+A L` - Switch to this client's last tmux session
- `Ctrl+A $` - Rename the session with the same contextual, editable suggestion

### Ghostty controls
- `Cmd+Backtick/1/2/3` - Cycle tmux `terminal`/`codex`/`nvim`/`tuxedo` windows by type
- `Cmd+B` / `Cmd+Shift+B` - Toggle a Yazi side pane or open its dedicated window
- `Right Cmd+D/R/S/Space` - Duplicate, rename, choose a session, or open the command center
- Left Command and all unlisted Command chords - Keep Ghostty and macOS defaults
- Right Command chords outside Ghostty - Pass through to the current app
- Left/Right Option - No additional sided layer yet
- Hyper - Reserved and intentionally unbound

### Copy Mode (vim-style)
- `Ctrl+A [` - Enter copy mode
- `v` - Start selection
- `y` - Copy to clipboard
- `/` / `?` - Search forward or backward
- `Ctrl+A ]` - Paste

### Misc
- `Ctrl+A Space r` - Reload config
- `Ctrl+A Space ?` - List all key bindings

## Recommended Workflow

### Option 1: One tmux session per Ghostty window
Good for projects that need multiple terminals:
```bash
# In Ghostty window on space 2 (editor space)
tmux new -s frontend
# Create splits/windows as needed
```

### Option 2: Use sesh (already configured!)
```bash
# Open sesh's built-in picker directly, or press Ctrl+A s
sesh picker
```

The shell and tmux session shortcuts use this built-in picker instead of
maintaining hand-rolled `fzf` pipelines. Chezmoi manages the shared picker
settings in `~/.config/sesh/sesh.toml`; declarative window layouts stay in the
repo's `.tmux.tsx` workspace system.

### Option 3: Detached sessions as "workspaces"
Keep long-running tasks in background:
```bash
# Start dev server in detached session
tmux new -d -s api "npm run dev"

# Check on it later
ta api

# Or just let it run in background
```

## Integration with your yabai spaces

**Recommended pattern:**
- Space 1 (browser): No tmux needed, browsers handle tabs
- Space 2 (editor): 1 tmux session with splits for editor + terminal work
- Space 3 (comms): No tmux needed
- Space 4+: 1 tmux session per project

## Tips

1. **Use tmux for terminal sessions, yabai for GUI apps**
   - Don't try to tile GUI apps with tmux
   - Use yabai's tiling for cross-app layouts

2. **Prefix changed to Ctrl+A** (easier than default Ctrl+B)

3. **Mouse enabled** - can click to switch panes/windows

4. **Consistent with your vim bindings** - h/j/k/l for navigation

5. **Colors match your catppuccin-mocha theme**

6. **Reload deliberately** - `alt+r` restarts yabai and skhd. Run
   `reload-colors` to restart those services and reload tmux configuration.
   A real `./install.sh` or `make install` also reloads tmux and signals every
   running Ghostty process, including the scratchpad, to reload its config.

## Troubleshooting

**Colors look wrong:**
```bash
echo $TERM  # should be "tmux-256color" inside tmux
```

**Config not loading:**
```bash
tmux source-file ~/.tmux.conf
```

**Kill all tmux sessions:**
```bash
tmux kill-server
```
