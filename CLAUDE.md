# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a macOS dotfiles repository for managing window manager (yabai), keyboard shortcuts (skhd), shell configuration (zsh), and terminal file manager (yazi) with centralized colorscheme management.

## Setup and Installation

**Initial setup (new machine):**
```bash
./bootstrap.sh
```

**Install/reinstall dotfiles:**
```bash
./install.sh
# or use make alias:
make install
```

The install script:
- Creates timestamped backups of existing configs
- Symlinks all config files to home directory
- Links helper scripts from `config/skhd/` and `config/yabai/` to `~/.config/`
- Links scripts from `scripts/*.sh` to `~/bin/<name>` (without .sh extension)
- Makes all scripts executable

**Reload configurations after changes:**
```bash
./reload_colors.sh
# or:
make reload
# or use keyboard shortcut: alt+r
```

**Auto-sync on file changes (requires fswatch):**
```bash
make watch
```

## Testing

**Run all tests:**
```bash
make test
```

**Run individual test suites:**
```bash
make test-colorscheme     # Colorscheme definitions and exports
make test-configs         # skhdrc and yabairc syntax and keybindings
make test-symlinks        # Symlink integrity
make test-integration     # End-to-end integration
```

Always run `make test` before committing changes. All tests must pass.

## Architecture

### Symlink Strategy

The repository uses symlinks to connect dotfiles to their active locations:
- Top-level configs (zshrc, skhdrc, yabairc) → `~/.zshrc`, `~/.skhdrc`, `~/.yabairc`
- Helper scripts in `config/skhd/*.sh` → `~/.config/skhd/`
- Helper scripts in `config/yabai/*.sh` → `~/.config/yabai/`
- Yazi configs in `config/yazi/*` → `~/.config/yazi/`
- Command scripts in `scripts/*.sh` → `~/bin/<name>` (stripped .sh extension)

**When adding new helper scripts**, they must be placed in the appropriate `config/` subdirectory and users must run `./install.sh` to create the symlinks.

### Colorscheme Management

Single source of truth: `colorschemes/catppuccin-mocha.sh`

The system uses a symlink approach:
- `colorschemes/colors.sh` → `colorschemes/catppuccin-mocha.sh` (symlink)
- All configs source `colors.sh` to get color definitions
- To switch colorschemes: update the symlink and run `./reload_colors.sh`

### Window Manager (yabai)

**Layout:** BSP (Binary Space Partitioning)
- Padding: 0px top, 3px bottom/left/right
- No gaps between windows
- External bar offset: 40px (top)

**Fixed Space Layout (1-4):**
1. `browser` - Ghostty + browsers (Safari, Chrome, Arc, Brave, Firefox)
2. `editor` - Code editors (Cursor, VS Code, Zed, Sublime, Xcode)
3. `comms` - Communication apps (Slack, Teams, Outlook)
4. `empty` - No default apps

yabairc ensures minimum 4 spaces exist on display 1 at startup.

**App Assignment Rules:**
Apps are automatically assigned to specific spaces via `yabai -m rule --add` directives in yabairc. When modifying app rules, maintain this fixed space structure.

### Keyboard Shortcuts (skhd)

Organized into sections:
1. **Window Management** (ctrl+alt) - Focus, swap, warp, resize, fullscreen, float
2. **Space Management** (alt+n, alt+k, ctrl+alt+shift+numbers) - Create spaces, close empty spaces, move windows
3. **App Focus** (alt+backtick, alt+1-4) - Smart app switching with cycling
4. **Window Close/Minimize** (ctrl+alt+w/z)
5. **Restart Services** (alt+r)
6. **Help** (alt+/) - Shows keybinding cheat sheet

**App Focus Behavior (alt + number):**
- `alt + backtick` - Ghostty
- `alt + 1` - @browser (detects default browser)
- `alt + 2` - @editor (detects running editor: Cursor, VS Code, Zed, etc.)
- `alt + 3` - Microsoft Teams
- `alt + 4` - Slack

When pressed repeatedly:
- Single window: toggles back to previous window
- Multiple windows: cycles through app windows

**Helper Scripts:**
- `config/skhd/focus_app.sh` - App focus logic
- `config/skhd/show_keys.sh` - Display keybinding cheat sheet
- `config/skhd/open_terminal_window.sh` - Opens new Ghostty window in current space (defaults to Ghostty, uses keycode 0x32 for tilde)
- `config/yabai/close_empty_spaces.sh` - Closes all empty spaces safely (keeps at least one space)

**Keycode Usage:**
The tilde binding uses keycode `0x32` in skhdrc for reliability across keyboard layouts.

### Shell Configuration (zsh)

- Main config: `zshrc`
- Secrets template: `zshrc.secrets.example`
- zshrc sources `~/.zshrc.secrets` if present for machine-specific tokens

**Yazi Integration:**
- `y` wrapper function in zshrc returns to directory on exit
- Custom keymaps in `config/yazi/keymap.toml` (`!` for shell, `Esc` to close prompts, `gr` for git root)
- `config/yazi/init.lua` enables zoxide DB updates

## Important Patterns

### Adding New Keyboard Shortcuts

1. Edit `skhdrc` with the new binding
2. If the shortcut calls a new helper script:
   - Place script in `config/skhd/` or `config/yabai/`
   - Make it executable
   - Run `./install.sh` to create symlink
3. Update tests in `tests/test_configs.sh` to check for the new keybinding
4. Run `make test` to verify
5. Reload: `alt+r` or `./reload_colors.sh`

### Adding App-to-Space Assignments

1. Edit `yabairc` and add rule: `yabai -m rule --add app="^AppName$" space=N`
2. Use exact app name from Activity Monitor
3. Respect the fixed space layout (1=browser, 2=editor, 3=comms, 4=empty)
4. Reload: `alt+r`

### Modifying Colorscheme

1. Edit `colorschemes/catppuccin-mocha.sh`
2. Run `./reload_colors.sh` to apply everywhere
3. Or switch schemes: `ln -sf new-scheme.sh colorschemes/colors.sh && ./reload_colors.sh`

### Adding Command Scripts

1. Create script in `scripts/<name>.sh`
2. Make executable: `chmod +x scripts/<name>.sh`
3. Run `./install.sh` - script will be available as `<name>` in `~/bin/`
4. Example: `scripts/watch-sync.sh` becomes `watch-sync` command

## Common Issues

**Yabai scripting addition not loading:**
Run `sudo yabai --load-sa` and check System Settings → Privacy & Security

**skhd shortcuts not working:**
- Check if another app is capturing the shortcut
- Use `skhd --observe` to debug
- Restart: `alt+r`

**Symlinks broken after moving repository:**
Re-run `./install.sh` to recreate all symlinks

**Tests failing:**
Check test output for specific failures. Common causes:
- Missing required tools (yabai, skhd, jq)
- Syntax errors in config files
- Broken symlinks
- Missing colorscheme exports

## File Locations

**Active configs (via symlinks):**
- `~/.zshrc` → `dotfiles/zshrc`
- `~/.skhdrc` → `dotfiles/skhdrc`
- `~/.yabairc` → `dotfiles/yabairc`
- `~/.config/skhd/` → `dotfiles/config/skhd/*`
- `~/.config/yabai/` → `dotfiles/config/yabai/*`
- `~/.config/yazi/` → `dotfiles/config/yazi/*`
- `~/bin/` → `dotfiles/scripts/*.sh` (without .sh)

**Secrets (not committed):**
- `~/.zshrc.secrets` - sourced by zshrc if present
