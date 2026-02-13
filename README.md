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

### Window Cycling
- `alt + tab` - Cycle through windows on current desktop (forward)
- `shift + alt + tab` - Cycle through windows on current desktop (backward)

### Window Border Marking (fn)
- `fn + 1` - Mark window with red border
- `fn + 2` - Mark window with peach border
- `fn + 3` - Mark window with yellow border
- `fn + 4` - Mark window with green border
- `fn + 5` - Mark window with teal border
- `fn + 6` - Mark window with sky blue border
- `fn + 7` - Mark window with blue border
- `fn + 8` - Mark window with mauve (purple) border
- `fn + 9` - Mark window with pink border
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

## Testing

A comprehensive test suite is included to prevent regressions when making changes.

### Running Tests

Run all tests:
```bash
make test
```

Run individual test suites:
```bash
make test-colorscheme     # Test color definitions and exports
make test-scripts         # Test border marking scripts
make test-configs         # Test skhdrc and yabairc
make test-symlinks        # Test symlink integrity
make test-integration     # Test end-to-end integration
```

Or run test scripts directly:
```bash
./tests/run_all_tests.sh              # Run all tests
./tests/test_colorscheme.sh           # Individual suite
```

### Test Coverage

The test suite validates:
- **Colorscheme**: All 9 colors are properly defined, hex values are valid, border format is correct
- **Scripts**: Border scripts can be executed, source colorscheme correctly, handle JSON operations
- **Configs**: All keybindings are present, no hardcoded colors, syntax is valid
- **Symlinks**: All symlinks point to correct locations and targets exist
- **Integration**: Components work together, services are running, end-to-end color flow

### Best Practices

- Run `make test` before committing changes
- All tests should pass before pushing to remote
- Add tests for new features to prevent regressions

### Adding New Tests

When adding features:
1. Add test cases to appropriate test file in `tests/`
2. Run `make test` to ensure no regressions
3. Commit tests alongside feature changes
