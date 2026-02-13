#!/usr/bin/env bash

# Dotfiles installation script
# This script sets up symlinks for all configuration files

set -e

DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

echo "Installing dotfiles from $DOTFILES_DIR"

# Create backup directory if files exist
if [ -f "$HOME/.skhdrc" ] || [ -f "$HOME/.yabairc" ] || [ -d "$HOME/.config/borders" ]; then
    echo "Creating backup at $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    [ -f "$HOME/.skhdrc" ] && mv "$HOME/.skhdrc" "$BACKUP_DIR/"
    [ -f "$HOME/.yabairc" ] && mv "$HOME/.yabairc" "$BACKUP_DIR/"
    [ -d "$HOME/.config/borders" ] && mv "$HOME/.config/borders" "$BACKUP_DIR/"
    [ -d "$HOME/.config/skhd" ] && mv "$HOME/.config/skhd" "$BACKUP_DIR/"
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p "$HOME/.config/borders"
mkdir -p "$HOME/.config/skhd"

# Create symlinks
echo "Creating symlinks..."

# Top-level config files
ln -sf "$DOTFILES_DIR/skhdrc" "$HOME/.skhdrc"
ln -sf "$DOTFILES_DIR/yabairc" "$HOME/.yabairc"

# Border scripts
ln -sf "$DOTFILES_DIR/config/borders/mark_window.sh" "$HOME/.config/borders/mark_window.sh"
ln -sf "$DOTFILES_DIR/config/borders/update_border.sh" "$HOME/.config/borders/update_border.sh"

# skhd scripts
for script in "$DOTFILES_DIR/config/skhd"/*; do
    if [ -f "$script" ]; then
        ln -sf "$script" "$HOME/.config/skhd/$(basename "$script")"
    fi
done

# Make scripts executable
echo "Making scripts executable..."
chmod +x "$DOTFILES_DIR/config/borders"/*.sh
chmod +x "$DOTFILES_DIR/config/skhd"/*.sh
chmod +x "$DOTFILES_DIR/colorschemes"/*.sh

# Create initial window_colors.json if it doesn't exist
if [ ! -f "$HOME/.config/borders/window_colors.json" ]; then
    echo '{}' > "$HOME/.config/borders/window_colors.json"
fi

echo ""
echo "✓ Dotfiles installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Restart yabai and skhd: alt+r"
echo "  2. Start borders with: borders active_color=\$(source ~/dotfiles/colorschemes/colors.sh && echo \$BORDER_COLOR_ACTIVE) inactive_color=\$(source ~/dotfiles/colorschemes/colors.sh && echo \$BORDER_COLOR_INACTIVE) width=5.0"
echo ""
echo "To change colorscheme:"
echo "  Edit ~/dotfiles/colorschemes/catppuccin-mocha.sh"
echo ""
