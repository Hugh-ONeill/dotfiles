#!/bin/bash
# Preview theme colors for fzf-tab

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/lib/config.sh"
source "$LIB_DIR/utils.sh"

theme="$1"
palette="$PALETTES_DIR/$theme.json"

[[ ! -f "$palette" ]] && echo "Theme not found" && exit 1

# Shorthand: resolve a single color from the palette
get_color() { resolve_color "$1" "$palette"; }

# Description
desc=$(jq -r '.description // empty' "$palette")
[[ -n "$desc" ]] && echo "$desc" && echo ""

# Base colors
echo "Bases:"
printf "  "
for c in crust mantle base surface0 surface1 surface2 overlay0 overlay1 overlay2; do
    color_block "$(get_color $c)"
done
echo ""

# Text colors
echo "Text:"
printf "  "
for c in text subtext1 subtext0; do
    color_block "$(get_color $c)"
done
echo ""

# Gradient
echo "Gradient:"
printf "  "
while read -r color; do
    if [[ "$color" == \#* ]]; then
        color_block "$color"
    else
        color_block "$(get_color "$color")"
    fi
done < <(jq -r '.gradient[]' "$palette")
echo ""

# Accents
echo "Accents:"
printf "  "
for c in accent accent_secondary accent_tertiary; do
    color_block "$(get_color $c)"
done
echo ""
