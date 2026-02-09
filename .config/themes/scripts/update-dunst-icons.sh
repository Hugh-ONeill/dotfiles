#!/bin/bash
# Update dunst SVG icons with theme colors
# Usage: ./update-dunst-icons.sh <theme-name>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_DIR="$(dirname "$SCRIPT_DIR")"
PALETTES_DIR="$THEMES_DIR/palettes"
TEMPLATES_DIR="$THEMES_DIR/templates/dunst-icons"
ICONS_DIR="$HOME/.config/dunst/icons"

if [[ -z "$1" ]]; then
    echo "Usage: $0 <theme-name>"
    exit 1
fi

THEME_NAME="$1"
PALETTE_FILE="$PALETTES_DIR/$THEME_NAME.sh"

if [[ ! -f "$PALETTE_FILE" ]]; then
    echo "Error: Palette file not found: $PALETTE_FILE"
    exit 1
fi

if [[ ! -d "$TEMPLATES_DIR" ]]; then
    echo "Error: Templates directory not found: $TEMPLATES_DIR"
    exit 1
fi

# Source the theme palette
source "$PALETTE_FILE"

# Catppuccin mocha colors (what the template icons use)
CAT_BLUE="#89b4fa"
CAT_TEAL="#94e2d5"
CAT_GREEN="#a6e3a1"
CAT_LAVENDER="#b4befe"
CAT_MAUVE="#cba6f7"
CAT_RED="#f38ba8"
CAT_YELLOW="#f9e2af"

echo "Generating dunst icons for $THEME_NAME..."

for template in "$TEMPLATES_DIR"/*.svg; do
    [[ -f "$template" ]] || continue

    filename=$(basename "$template")
    output="$ICONS_DIR/$filename"

    sed \
        -e "s/${CAT_BLUE}/${BLUE}/gi" \
        -e "s/${CAT_TEAL}/${TEAL}/gi" \
        -e "s/${CAT_GREEN}/${GREEN}/gi" \
        -e "s/${CAT_LAVENDER}/${LAVENDER}/gi" \
        -e "s/${CAT_MAUVE}/${MAUVE}/gi" \
        -e "s/${CAT_RED}/${RED}/gi" \
        -e "s/${CAT_YELLOW}/${YELLOW}/gi" \
        "$template" > "$output"
done

echo "Done! Updated $(ls -1 "$TEMPLATES_DIR"/*.svg 2>/dev/null | wc -l) icons."
