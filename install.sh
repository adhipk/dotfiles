#!/usr/bin/env bash

# Dotfiles installation script
# This script sets up symlinks for all configuration files

set -e

DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

echo "Installing dotfiles from $DOTFILES_DIR"

# Create backup directory if files exist
if [ -f "$HOME/.zshrc" ] || [ -f "$HOME/.skhdrc" ] || [ -f "$HOME/.yabairc" ] || [ -d "$HOME/.config/yazi" ]; then
    echo "Creating backup at $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    [ -f "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$BACKUP_DIR/"
    [ -f "$HOME/.skhdrc" ] && mv "$HOME/.skhdrc" "$BACKUP_DIR/"
    [ -f "$HOME/.yabairc" ] && mv "$HOME/.yabairc" "$BACKUP_DIR/"
    [ -d "$HOME/.config/skhd" ] && mv "$HOME/.config/skhd" "$BACKUP_DIR/"
    [ -d "$HOME/.config/yabai" ] && mv "$HOME/.config/yabai" "$BACKUP_DIR/"
    [ -d "$HOME/.config/yazi" ] && mv "$HOME/.config/yazi" "$BACKUP_DIR/"
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p "$HOME/.config/skhd"
mkdir -p "$HOME/.config/yabai"
mkdir -p "$HOME/.config/yazi"
mkdir -p "$HOME/bin"

# Create symlinks
echo "Creating symlinks..."

# Top-level config files
ln -sf "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/skhdrc" "$HOME/.skhdrc"
ln -sf "$DOTFILES_DIR/yabairc" "$HOME/.yabairc"

# skhd scripts
for script in "$DOTFILES_DIR/config/skhd"/*; do
    if [ -f "$script" ]; then
        ln -sf "$script" "$HOME/.config/skhd/$(basename "$script")"
    fi
done

# yabai scripts
for script in "$DOTFILES_DIR/config/yabai"/*; do
    if [ -f "$script" ]; then
        ln -sf "$script" "$HOME/.config/yabai/$(basename "$script")"
    fi
done

# yazi configs
for file in "$DOTFILES_DIR/config/yazi"/*; do
    if [ -f "$file" ]; then
        ln -sf "$file" "$HOME/.config/yazi/$(basename "$file")"
    fi
done

# Helper commands (symlink scripts/*.sh -> ~/bin/<name>)
for script in "$DOTFILES_DIR/scripts"/*.sh; do
    if [ -f "$script" ]; then
        name="$(basename "$script")"
        name="${name%.sh}"
        ln -sf "$script" "$HOME/bin/$name"
    fi
done

# Make scripts executable
echo "Making scripts executable..."
chmod +x "$DOTFILES_DIR/config/skhd"/*.sh
chmod +x "$DOTFILES_DIR/config/yabai"/*.sh 2>/dev/null || true
chmod +x "$DOTFILES_DIR/colorschemes"/*.sh
chmod +x "$DOTFILES_DIR/scripts"/*.sh 2>/dev/null || true

echo ""
echo "✓ Dotfiles installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Restart yabai and skhd: alt+r"
echo ""
echo "To change colorscheme:"
echo "  Edit ~/dotfiles/colorschemes/catppuccin-mocha.sh"
echo ""
