# Dotfiles

Personal macOS configuration files with centralized colorscheme management.

## Structure

```
dotfiles/
├── colorschemes/          # Centralized color definitions
│   ├── catppuccin-mocha.sh
│   └── colors.sh -> catppuccin-mocha.sh
├── config/
│   ├── skhd/             # skhd helper scripts
│   │   ├── focus_app.sh
│   │   ├── show_keys.sh
│   │   └── whichkey
│   └── yazi/             # yazi file manager config
│       ├── init.lua
│       └── keymap.toml
├── skhdrc               # Keyboard shortcuts
├── yabairc              # Window manager config
├── zshrc                # Zsh shell config
├── zshrc.secrets.example # Secret env template (not committed live)
├── install.sh           # Installation script
└── reload_colors.sh     # Reload configs after color changes
```

## Installation

```bash
cd ~/dotfiles
./install.sh
```

### Quick Setup (new Mac)

```bash
cd ~/dotfiles
./bootstrap.sh
```

This installs Homebrew (if needed), installs dependencies from `Brewfile`, and then runs `./install.sh`.

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

### Space Management
- `alt + k` - Close all empty desktops/spaces
- `alt + n` - Create a new space and focus it
- `alt + shift + ~` - Open a new Ghostty window in the current space

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
- [Yazi](https://github.com/sxyazi/yazi) - Terminal file manager
- [Catppuccin](https://github.com/catppuccin/catppuccin) - Color scheme

## Shell Secrets

`zshrc` will source `~/.zshrc.secrets` when present. Keep machine-specific values
and tokens there, and use `zshrc.secrets.example` as the template.

## Yazi Integration

- `zshrc` includes a `y` wrapper that returns you to the directory you exit from.
- `config/yazi/keymap.toml` includes:
  - `!` to open an interactive shell in the current directory
  - `Esc` to close input prompts with one press
  - `gr` to jump to the current git repo root
- `config/yazi/init.lua` enables zoxide DB updates from Yazi.

## Configuration Details

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
- **Colorscheme**: Color variables are properly defined and exported
- **Configs**: Core keybindings are present and syntax is valid
- **Symlinks**: All symlinks point to correct locations and targets exist
- **Integration**: Components work together and core services are running

### Best Practices

- Run `make test` before committing changes
- All tests should pass before pushing to remote
- Add tests for new features to prevent regressions

### Adding New Tests

When adding features:
1. Add test cases to appropriate test file in `tests/`
2. Run `make test` to ensure no regressions
3. Commit tests alongside feature changes
