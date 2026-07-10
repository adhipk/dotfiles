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

## Key Bindings

### Panes (most common)
- `Ctrl+A \|` - Split pane horizontally (keep current directory)
- `Ctrl+A -` - Split pane vertically (keep current directory)
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
- `Ctrl+A ]` - Paste

### Misc
- `Ctrl+A r` - Reload config
- `Ctrl+A ?` - List all key bindings

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
