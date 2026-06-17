#!/bin/bash
# Assemble a theme's starship.toml from the tracked template fragments.
# Usage: ./build-starship.sh <theme-name>
#
# Output: generated/<theme>/starship.toml = format block (for the theme's
# style.bar) + base modules (palette line set to the active palette) + every
# theme's [palettes.*] block. The live ~/.config/starship/starship.toml is a
# copy of this, placed by apply_starship at theme-switch time.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/lib/config.sh"
source "$LIB_DIR/utils.sh"

THEME_NAME="$1"
[[ -z "$THEME_NAME" ]] && { echo "Usage: $0 <theme-name>"; exit 1; }

PALETTE_FILE="$PALETTES_DIR/$THEME_NAME.json"
[[ ! -f "$PALETTE_FILE" ]] && { echo "Error: palette not found: $PALETTE_FILE"; exit 1; }

STARSHIP_TMPL_DIR="$TEMPLATES_DIR/starship"
BASE_TMPL="$STARSHIP_TMPL_DIR/base.toml.tmpl"
OUTPUT="$GENERATED_DIR/$THEME_NAME/starship.toml"
mkdir -p "$GENERATED_DIR/$THEME_NAME"

# starship's palette name (catppuccin is published under the mocha flavour name)
starship_palette_name() {
    [[ "$1" == "catppuccin" ]] && echo "catppuccin_mocha" || echo "$1"
}

# Active palette + format style for this theme
ACTIVE_PALETTE=$(starship_palette_name "$THEME_NAME")
BAR=$(jq -r '.style.bar // "rounded"' "$PALETTE_FILE")
FORMAT_FILE="$STARSHIP_TMPL_DIR/format-$BAR.txt"
[[ -f "$FORMAT_FILE" ]] || FORMAT_FILE="$STARSHIP_TMPL_DIR/format-rounded.txt"

# Get contrasting foreground based on background luminance
get_contrast_fg() {
    local lum; lum=$(hex_luminance "$1")
    [[ $lum -gt $LUMINANCE_THRESHOLD ]] && echo "$2" || echo "$3"
}

# Generate a starship [palettes.<name>] block from a JSON palette file
generate_palette_block() {
    local palette_file="$1" palette_name="$2"
    declare -A colors
    load_palette_colors colors "$palette_file"

    readarray -t gradient_refs < <(jq -r '.gradient[]' "$palette_file")
    declare -a gradient
    for ref in "${gradient_refs[@]}"; do
        if [[ "$ref" == \#* ]]; then gradient+=("$ref"); else gradient+=("${colors[$ref]}"); fi
    done

    local MODULE_FG="${colors[module_fg]}" MODULE_FG_LIGHT="${colors[module_fg_light]}"

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

# Build all palette blocks (every theme, sorted) into a temp file
PALETTES_TMP=$(mktemp)
trap 'rm -f "$PALETTES_TMP"' EXIT
for pf in "$PALETTES_DIR"/*.json; do
    [[ -f "$pf" ]] || continue
    pname=$(starship_palette_name "$(basename "$pf" .json)")
    generate_palette_block "$pf" "$pname" >> "$PALETTES_TMP"
    echo "" >> "$PALETTES_TMP"
done

# Assemble: base template, with sentinels resolved, then palette blocks appended.
# Python does the splices so format-block glyphs/backslashes pass through literally.
BASE_TMPL="$BASE_TMPL" FORMAT_FILE="$FORMAT_FILE" PALETTES_TMP="$PALETTES_TMP" \
ACTIVE_PALETTE="$ACTIVE_PALETTE" OUTPUT="$OUTPUT" python3 - <<'PY'
import os
base = open(os.environ['BASE_TMPL']).read()
fmt  = open(os.environ['FORMAT_FILE']).read()
pals = open(os.environ['PALETTES_TMP']).read()
block = 'format = """\n' + fmt + '\n"""'
base = base.replace('@@STARSHIP_FORMAT@@', block)
base = base.replace('@@STARSHIP_PALETTE@@', os.environ['ACTIVE_PALETTE'])
out = base.rstrip('\n') + '\n\n' + pals
open(os.environ['OUTPUT'], 'w').write(out)
PY
