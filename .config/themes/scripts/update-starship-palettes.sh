#!/bin/bash
# Update starship.toml palettes from theme palette files
# Usage: ./update-starship-palettes.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/lib/config.sh"
source "$LIB_DIR/utils.sh"
STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

if [[ ! -f "$STARSHIP_CONFIG" ]]; then
    echo "Error: Starship config not found: $STARSHIP_CONFIG"
    exit 1
fi

# Get contrasting foreground based on background luminance
get_contrast_fg() {
    local bg_color="$1"
    local dark_fg="$2"
    local light_fg="$3"
    local lum=$(hex_luminance "$bg_color")
    if [[ $lum -gt $LUMINANCE_THRESHOLD ]]; then
        echo "$dark_fg"
    else
        echo "$light_fg"
    fi
}

# Function to generate a starship palette block from a JSON palette file
generate_palette_block() {
    local palette_file="$1"
    local palette_name="$2"

    # Load colors into associative array, resolving references
    declare -A colors
    load_palette_colors colors "$palette_file"

    # Load gradient
    readarray -t gradient_refs < <(jq -r '.gradient[]' "$palette_file")
    declare -a gradient
    for ref in "${gradient_refs[@]}"; do
        if [[ "$ref" == \#* ]]; then
            gradient+=("$ref")
        else
            gradient+=("${colors[$ref]}")
        fi
    done

    local MODULE_FG="${colors[module_fg]}"
    local MODULE_FG_LIGHT="${colors[module_fg_light]}"

    cat <<EOF
[palettes.$palette_name]
# Structural
text = "${colors[text]}"
subtext1 = "${colors[subtext1]}"
subtext0 = "${colors[subtext0]}"
overlay2 = "${colors[overlay2]}"
overlay1 = "${colors[overlay1]}"
overlay0 = "${colors[overlay0]}"
surface2 = "${colors[surface2]}"
surface1 = "${colors[surface1]}"
surface0 = "${colors[surface0]}"
base = "${colors[base]}"
mantle = "${colors[mantle]}"
crust = "${colors[crust]}"
# Gradient
g0 = "${gradient[0]}"
g1 = "${gradient[1]}"
g2 = "${gradient[2]}"
g3 = "${gradient[3]}"
g4 = "${gradient[4]}"
g5 = "${gradient[5]}"
g6 = "${gradient[6]}"
g7 = "${gradient[7]}"
g8 = "${gradient[8]}"
g9 = "${gradient[9]}"
# Semantic
sem_ok = "${colors[sem_ok]}"
sem_warn = "${colors[sem_warn]}"
sem_err = "${colors[sem_err]}"
sem_info = "${colors[sem_info]}"
module_fg = "$MODULE_FG"
module_fg_light = "$MODULE_FG_LIGHT"
# Auto-contrast foreground for each gradient
g0_fg = "$(get_contrast_fg "${gradient[0]}" "$MODULE_FG" "$MODULE_FG_LIGHT")"
g1_fg = "$(get_contrast_fg "${gradient[1]}" "$MODULE_FG" "$MODULE_FG_LIGHT")"
g2_fg = "$(get_contrast_fg "${gradient[2]}" "$MODULE_FG" "$MODULE_FG_LIGHT")"
g3_fg = "$(get_contrast_fg "${gradient[3]}" "$MODULE_FG" "$MODULE_FG_LIGHT")"
g4_fg = "$(get_contrast_fg "${gradient[4]}" "$MODULE_FG" "$MODULE_FG_LIGHT")"
g5_fg = "$(get_contrast_fg "${gradient[5]}" "$MODULE_FG" "$MODULE_FG_LIGHT")"
g6_fg = "$(get_contrast_fg "${gradient[6]}" "$MODULE_FG" "$MODULE_FG_LIGHT")"
g7_fg = "$(get_contrast_fg "${gradient[7]}" "$MODULE_FG" "$MODULE_FG_LIGHT")"
g8_fg = "$(get_contrast_fg "${gradient[8]}" "$MODULE_FG" "$MODULE_FG_LIGHT")"
g9_fg = "$(get_contrast_fg "${gradient[9]}" "$MODULE_FG" "$MODULE_FG_LIGHT")"
EOF
}

# Read everything except palette sections (palettes are always at the end)
NON_PALETTE=$(awk '
    /^\[palettes\./ { in_palette=1; next }
    in_palette && /^\[/ && !/^\[palettes\./ { in_palette=0 }
    !in_palette { print }
' "$STARSHIP_CONFIG")

# Generate new config: non-palette content first, then fresh palettes appended
{
    echo "$NON_PALETTE"
    echo ""

    # Generate palettes for all JSON themes
    for palette_file in "$PALETTES_DIR"/*.json; do
        [[ ! -f "$palette_file" ]] && continue
        theme_name=$(basename "$palette_file" .json)
        # Special case for catppuccin naming
        [[ "$theme_name" == "catppuccin" ]] && palette_name="catppuccin_mocha" || palette_name="$theme_name"
        generate_palette_block "$palette_file" "$palette_name"
        echo ""
    done
} > "$STARSHIP_CONFIG.new"

# Replace the config
mv "$STARSHIP_CONFIG.new" "$STARSHIP_CONFIG"

echo "Updated starship palettes from palette files"
