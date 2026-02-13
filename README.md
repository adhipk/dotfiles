# Dotfiles

Personal macOS configuration files with centralized colorscheme management.

## Structure

```
dotfiles/
├── colorschemes/          # Centralized color definitions
│   ├── catppuccin-mocha.sh
│   └── colors.sh -> catppuccin-mocha.sh
├── config/
│   ├── borders/          # JankyBorders scripts
│   │   ├── mark_window.sh
│   │   └── update_border.sh
│   └── skhd/            # skhd helper scripts
│       ├── focus_app.sh
│       ├── show_keys.sh
│       └── whichkey
├── skhdrc               # Keyboard shortcuts
├── yabairc              # Window manager config
├── install.sh           # Installation script
└── reload_colors.sh     # Reload configs after color changes
```

## Installation

```bash
cd ~/dotfiles
./install.sh
```

This will:
- Back up existing configs
- Create symlinks for all configuration files
- Set up proper permissions

## Keyboard Shortcuts

### Window Management (ctrl + alt)
- `h/j/k/l` - Focus window (vim directions)
- `shift + h/j/k/l` - Swap windows
- `return` - Toggle fullscreen
- `f` - Toggle float
- `w` - Close window

### Window Border Marking (fn)
- `fn + 1` - Mark window with red border
- `fn + 2` - Mark window with green border
- `fn + 3` - Mark window with blue border
- `fn + 4` - Mark window with yellow border
- `fn + 0` - Clear border marking

### App Focus (alt)
- `alt + backtick` - Ghostty
- `alt + 1` - Browser
- `alt + 2` - Editor
- `alt + 3` - Microsoft Teams
- `alt + 4` - Slack

### Other
- `alt + r` - Restart yabai & skhd
- `alt + /` - Show keybindings cheat sheet

## Colorscheme Management

All colors are defined in `colorschemes/catppuccin-mocha.sh`. This is the single source of truth for colors used across all tools.

### Changing Colors

1. Edit `~/dotfiles/colorschemes/catppuccin-mocha.sh`
2. Run `./reload_colors.sh` to apply changes everywhere

### Adding a New Colorscheme

1. Create `colorschemes/my-scheme.sh` based on `catppuccin-mocha.sh`
2. Update the symlink: `ln -sf my-scheme.sh colorschemes/colors.sh`
3. Run `./reload_colors.sh`

## Tools Used

- [yabai](https://github.com/koekeishiya/yabai) - Tiling window manager
- [skhd](https://github.com/koekeishiya/skhd) - Hotkey daemon
- [JankyBorders](https://github.com/FelixKratz/JankyBorders) - Window borders
- [Catppuccin](https://github.com/catppuccin/catppuccin) - Color scheme

## Configuration Details

### Border System

The border system tracks which windows you've marked with specific colors. When you focus a marked window, it displays your assigned color. Unmarked windows show the default active/inactive colors.

- Marked windows persist in `~/.config/borders/window_colors.json`
- Colors are sourced from the central colorscheme
- Automatic updates on window focus via yabai signals

### Window Manager

- Layout: BSP (Binary Space Partitioning)
- Padding: 0px top, 3px bottom/left/right
- No gaps between windows
- External bar offset: 40px (top)
