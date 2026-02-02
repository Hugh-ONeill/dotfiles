#!/bin/bash
# Preview theme colors for fzf-tab

theme="$1"
palette="$HOME/.config/themes/palettes/$theme.json"

[[ ! -f "$palette" ]] && echo "Theme not found" && exit 1

# Function to print a colored block
color_block() {
    local hex="${1#\#}"
    [[ -z "$hex" || "$hex" == "null" ]] && return
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    printf "\033[48;2;%d;%d;%dm  \033[0m" "$r" "$g" "$b"
}

# Get a color, resolving references
get_color() {
    local key="$1"
    local val=$(jq -r ".colors.$key // empty" "$palette")
    if [[ "$val" == \#* ]]; then
        echo "$val"
    elif [[ -n "$val" ]]; then
        # It's a reference to another color
        jq -r ".colors.$val // empty" "$palette"
    fi
}

# Description
desc=$(jq -r '.description // empty' "$palette")
[[ -n "$desc" ]] && echo "$desc" && echo ""

# Base colors
echo "Bases:"
printf "  "
for c in crust mantle base surface0 surface1 surface2; do
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
