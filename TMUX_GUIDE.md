# tmux Integration Guide

## How tmux fits into your setup

**Your workflow:**
- **yabai** manages physical window placement (tiling windows on macOS)
- **tmux** manages terminal sessions/panes inside Ghostty windows
- **sesh** command (`tmux-sessionizer-zoxide`) quickly switches between project sessions

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

In Ghostty, `Cmd+Backtick`, `Cmd+1`, and `Cmd+2` jump directly to those
windows. `Cmd+B` toggles one Yazi 40%-wide full-height right pane, while
`Cmd+Shift+B` opens or selects a dedicated Yazi tmux window. New Yazi views
start in the active pane's directory and close when Yazi exits. Sessions
created with an explicit command remain single-purpose.
Compound/orchestrated session creators that add their own windows or queue
index-targeted commands must use
`tmux new-session -e DOTFILES_TMUX_TEMPLATE=skip ...`; `hs-*` sessions opt out
automatically.

## Command Center

Press `Ctrl+A Space`. The repo-owned menu groups the complete lifecycle:

- `s` — switch, create, rename, close, save/restore all state, or close detached managed layouts
- `w` — choose, create typed windows, reorder, rename, or close windows
- `p` — navigate, split, resize, swap, break, or close panes
- `l` — open, reapply, or repair a declarative workspace layout

The active session name remains visible beside the current folder in the
bottom bar. Resurrect and Continuum save structure, directories, pane contents,
and an allowlist of interactive processes in the background. Neovim, Codex, and
Yazi are restored; arbitrary development commands are deliberately not
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
three-window hook and retain typed terminal/Codex/Neovim metadata. A layout
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
- `Ctrl+A c` - New window (tmux default)
- `Ctrl+A p` - Previous window
- `Ctrl+A n` - Next window
- `Ctrl+A 0-9` - Switch to window by number (uses prefix)
- `Ctrl+A ,` - Rename window (uses prefix)
- `Ctrl+A &` - Kill window (uses prefix)

### Sessions (uses prefix)
- `Ctrl+A d` - Detach from session
- `Ctrl+A s` - List and switch sessions
- `Ctrl+A $` - Rename session

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
# Run `tmux-sessionizer-zoxide` to fuzzy find projects
# Then switch between sessions instantly
# Works great with your existing setup and uses `sesh`
```

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
