#!/usr/bin/env bash
# Cava visualizer for waybar with theme-aware gradient colors

exec 2>/dev/null
set +e

# Bar characters (from lowest to highest)
bar_chars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

# Read colors from current theme
THEME_CSS="$HOME/.config/waybar/theme.css"
[[ -L "$THEME_CSS" ]] && THEME_CSS=$(readlink -f "$THEME_CSS")

get_color() {
    grep -oP "@define-color\s+${1}\s+\K#[0-9a-fA-F]{6}" "$THEME_CSS" 2>/dev/null | head -1
}

# Use gradient colors g0-g7 for 8-bar visualizer
colors=(
    "$(get_color g0)"
    "$(get_color g1)"
    "$(get_color g2)"
    "$(get_color g3)"
    "$(get_color g4)"
    "$(get_color g5)"
    "$(get_color g6)"
    "$(get_color g7)"
)

# Run cava and process output
cava -p ~/.config/cava/config-waybar 2>/dev/null | while IFS=';' read -r -a vals; do
    # Check if all values are zero
    sum=0
    for val in "${vals[@]}"; do
        [[ -n "$val" ]] && ((sum += val))
    done

    # Skip output if silent
    if [[ $sum -eq 0 ]]; then
        printf '\n' || exit 0
        continue
    fi

    output=""
    for i in "${!vals[@]}"; do
        val="${vals[$i]}"
        [[ -z "$val" ]] && continue
        idx=$((val > 7 ? 7 : val))
        color="${colors[$i]}"
        output+="<span foreground='${color}'>${bar_chars[$idx]}</span>"
    done
    printf '%s\n' "$output" || exit 0
done
