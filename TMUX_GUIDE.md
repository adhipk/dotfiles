# tmux Integration Guide

## How tmux fits into your setup

**Your workflow:**
- **yabai** manages physical window placement (tiling windows on macOS)
- **tmux** manages terminal sessions/panes inside Ghostty windows
- **tmux-sessionizer** (Ctrl+F) quickly switches between project sessions

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

## Key Bindings (Direct - No Prefix!)

### Panes (splits) - Most Common
- `Alt+\` - Split horizontally (side by side)
- `Alt+-` - Split vertically (top/bottom)
- `Alt+h/j/k/l` - Navigate panes (vim-style)
- `Alt+H/J/K/L` - Resize panes
- `Alt+w` - Close pane
- `Alt+z` - Toggle zoom (fullscreen pane)

### Windows (like browser tabs)
- `Alt+t` - New window
- `Alt+p` - Previous window
- `Alt+n` - Next window
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

### Option 2: Use tmux-sessionizer (already configured!)
```bash
# Press Ctrl+F to fuzzy find projects
# Switch between sessions instantly
# Works great with your existing setup
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

6. **Auto-reloads with `alt+r`** (via reload_colors.sh)

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
