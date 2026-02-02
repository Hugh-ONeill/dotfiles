#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Rofi Nerd Fonts Picker
# Categorized browser for Nerd Font icons
# ══════════════════════════════════════════════════════════════════════════════
DIR="$(dirname "$0")"
ROFI="rofi -dmenu -i -p Icons -theme ${DIR}/style.rasi"
nerd_font_file="/usr/lib/python3.14/site-packages/picker/data/nerd_font.csv"

# Fallback if path changes
[[ ! -f "$nerd_font_file" ]] && nerd_font_file=$(find /usr -name "nerd_font.csv" -path "*picker*" 2>/dev/null | head -1)

if [[ ! -f "$nerd_font_file" ]]; then
    notify-send "Nerd Fonts" "nerd_font.csv not found. Install rofimoji." -u critical
    exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
# Categories
# ══════════════════════════════════════════════════════════════════════════════

declare -A categories=(
    ["cod"]="	Codicons (VS Code)"
    ["dev"]="	Devicons"
    ["fa"]="	Font Awesome"
    ["fae"]="	Font Awesome Ext"
    ["linux"]="	Linux Distros"
    ["md"]="󰦆	Material Design"
    ["oct"]="	Octicons (GitHub)"
    ["pl"]="	Powerline"
    ["ple"]="	Powerline Extra"
    ["pom"]="	Pomicons"
    ["seti"]="	Seti UI"
    ["weather"]="	Weather"
    ["iec"]="⏻	IEC Power"
    ["custom"]="	Custom"
)

# Category order for display
category_order=(cod dev fa fae linux md oct pl ple pom seti weather iec custom)

# ══════════════════════════════════════════════════════════════════════════════
# Functions
# ══════════════════════════════════════════════════════════════════════════════

show_categories() {
    for cat in "${category_order[@]}"; do
        echo "${categories[$cat]}"
    done | $ROFI
}

get_category_prefix() {
    local selection="$1"
    for cat in "${!categories[@]}"; do
        if [[ "${categories[$cat]}" == "$selection" ]]; then
            echo "$cat"
            return
        fi
    done
}

show_icons() {
    local prefix="$1"
    grep " ${prefix}-" "$nerd_font_file" | sed 's/ /\t/' | $ROFI
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

while true; do
    category=$(show_categories)
    [[ -z "$category" ]] && exit 0

    prefix=$(get_category_prefix "$category")
    [[ -z "$prefix" ]] && exit 0

    selected=$(show_icons "$prefix")
    [[ -z "$selected" ]] && continue

    # Extract just the icon (everything before the space)
    icon="${selected%% *}"

    # Copy to clipboard
    echo -n "$icon" | wl-copy
    notify-send "Nerd Fonts" "Copied: $icon" -t 1500
    exit 0
done
