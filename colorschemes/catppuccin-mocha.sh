#!/usr/bin/env bash
# Catppuccin Mocha Colorscheme
# Central source of truth for all color definitions

# Base colors
export COLOR_BASE="1e1e2e"
export COLOR_MANTLE="181825"
export COLOR_CRUST="11111b"

# Surface colors
export COLOR_SURFACE0="313244"
export COLOR_SURFACE1="45475a"
export COLOR_SURFACE2="585b70"

# Overlay colors
export COLOR_OVERLAY0="6c7086"
export COLOR_OVERLAY1="7f849c"
export COLOR_OVERLAY2="9399b2"

# Text colors
export COLOR_SUBTEXT0="a6adc8"
export COLOR_SUBTEXT1="bac2de"
export COLOR_TEXT="cdd6f4"

# Accent colors
export COLOR_LAVENDER="b4befe"
export COLOR_BLUE="89b4fa"
export COLOR_SAPPHIRE="74c7ec"
export COLOR_SKY="89dceb"
export COLOR_TEAL="94e2d5"
export COLOR_GREEN="a6e3a1"
export COLOR_YELLOW="f9e2af"
export COLOR_PEACH="fab387"
export COLOR_MAROON="eba0ac"
export COLOR_RED="f38ba8"
export COLOR_MAUVE="cba6f7"
export COLOR_PINK="f5c2e7"
export COLOR_FLAMINGO="f2cdcd"
export COLOR_ROSEWATER="f5e0dc"

# Special color for active window border (customized lavender)
export COLOR_ACTIVE_BORDER="7287fd"

# Border-specific colors in 0xAARRGGBB format (for JankyBorders)
export BORDER_COLOR_RED="0xff${COLOR_RED}"
export BORDER_COLOR_GREEN="0xff${COLOR_GREEN}"
export BORDER_COLOR_BLUE="0xff${COLOR_BLUE}"
export BORDER_COLOR_YELLOW="0xff${COLOR_YELLOW}"
export BORDER_COLOR_BASE="0xff${COLOR_BASE}"
export BORDER_COLOR_ACTIVE="0xff${COLOR_ACTIVE_BORDER}"
export BORDER_COLOR_INACTIVE="0xff${COLOR_BASE}"

# Export as JSON for tools that need it
export COLORS_JSON=$(cat <<EOF
{
  "base": "$COLOR_BASE",
  "mantle": "$COLOR_MANTLE",
  "crust": "$COLOR_CRUST",
  "surface0": "$COLOR_SURFACE0",
  "surface1": "$COLOR_SURFACE1",
  "surface2": "$COLOR_SURFACE2",
  "overlay0": "$COLOR_OVERLAY0",
  "overlay1": "$COLOR_OVERLAY1",
  "overlay2": "$COLOR_OVERLAY2",
  "subtext0": "$COLOR_SUBTEXT0",
  "subtext1": "$COLOR_SUBTEXT1",
  "text": "$COLOR_TEXT",
  "lavender": "$COLOR_LAVENDER",
  "blue": "$COLOR_BLUE",
  "sapphire": "$COLOR_SAPPHIRE",
  "sky": "$COLOR_SKY",
  "teal": "$COLOR_TEAL",
  "green": "$COLOR_GREEN",
  "yellow": "$COLOR_YELLOW",
  "peach": "$COLOR_PEACH",
  "maroon": "$COLOR_MAROON",
  "red": "$COLOR_RED",
  "mauve": "$COLOR_MAUVE",
  "pink": "$COLOR_PINK",
  "flamingo": "$COLOR_FLAMINGO",
  "rosewater": "$COLOR_ROSEWATER",
  "active_border": "$COLOR_ACTIVE_BORDER",
  "border": {
    "red": "$BORDER_COLOR_RED",
    "green": "$BORDER_COLOR_GREEN",
    "blue": "$BORDER_COLOR_BLUE",
    "yellow": "$BORDER_COLOR_YELLOW",
    "base": "$BORDER_COLOR_BASE",
    "active": "$BORDER_COLOR_ACTIVE",
    "inactive": "$BORDER_COLOR_INACTIVE"
  }
}
EOF
)
