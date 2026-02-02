#!/bin/bash
# Build Kvantum theme from palette by find-replacing catppuccin colors
# Usage: ./build-kvantum-theme.sh <theme-name>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PALETTES_DIR="$SCRIPT_DIR/palettes"
OUTPUT_DIR="$HOME/.config/Kvantum"

# Catppuccin Mocha colors (source)
declare -A CATPPUCCIN_MOCHA=(
    [crust]="#11111b"
    [mantle]="#181825"
    [base]="#1e1e2e"
    [surface0]="#313244"
    [surface1]="#45475a"
    [surface2]="#585b70"
    [overlay0]="#6c7086"
    [overlay1]="#7f849c"
    [overlay2]="#9399b2"
    [text]="#cdd6f4"
    [subtext1]="#bac2de"
    [subtext0]="#a6adc8"
    [red]="#f38ba8"
    [maroon]="#eba0ac"
    [peach]="#fab387"
    [yellow]="#f9e2af"
    [green]="#a6e3a1"
    [teal]="#94e2d5"
    [sky]="#89dceb"
    [sapphire]="#74c7ec"
    [blue]="#89b4fa"
    [lavender]="#b4befe"
    [mauve]="#cba6f7"
    [pink]="#f5c2e7"
    [flamingo]="#f2cdcd"
    [rosewater]="#f5e0dc"
)

# Catppuccin Latte colors (for light themes)
declare -A CATPPUCCIN_LATTE=(
    [crust]="#dce0e8"
    [mantle]="#e6e9ef"
    [base]="#eff1f5"
    [surface0]="#ccd0da"
    [surface1]="#bcc0cc"
    [surface2]="#acb0be"
    [overlay0]="#9ca0b0"
    [overlay1]="#8c8fa1"
    [overlay2]="#7c7f93"
    [text]="#4c4f69"
    [subtext1]="#5c5f77"
    [subtext0]="#6c6f85"
    [red]="#d20f39"
    [maroon]="#e64553"
    [peach]="#fe640b"
    [yellow]="#df8e1d"
    [green]="#40a02b"
    [teal]="#179299"
    [sky]="#04a5e5"
    [sapphire]="#209fb5"
    [blue]="#1e66f5"
    [lavender]="#7287fd"
    [mauve]="#8839ef"
    [pink]="#ea76cb"
    [flamingo]="#dd7878"
    [rosewater]="#dc8a78"
)

if [[ -z "$1" ]]; then
    echo "Usage: $0 <theme-name> [--all]"
    echo ""
    echo "Available themes:"
    for f in "$PALETTES_DIR"/*.json; do
        [[ -f "$f" ]] && basename "$f" .json
    done
    exit 1
fi

# Build all themes if --all
if [[ "$1" == "--all" ]]; then
    for f in "$PALETTES_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        theme=$(basename "$f" .json)
        [[ "$theme" == "chameleon" ]] && continue  # Skip chameleon
        "$0" "$theme"
    done
    exit 0
fi

THEME_NAME="$1"
PALETTE_FILE="$PALETTES_DIR/$THEME_NAME.json"

if [[ ! -f "$PALETTE_FILE" ]]; then
    echo "Error: Palette not found: $PALETTE_FILE"
    exit 1
fi

# Detect if light theme (check if base color is light)
BASE_COLOR=$(jq -r '.colors.base' "$PALETTE_FILE")
if [[ "$BASE_COLOR" != \#* ]]; then
    # It's a reference, resolve it
    BASE_COLOR=$(jq -r ".colors[\"$BASE_COLOR\"] // .colors.base" "$PALETTE_FILE")
fi

# Calculate luminance to detect light/dark
hex_to_luminance() {
    local hex="${1#\#}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    echo $(( (299 * r + 587 * g + 114 * b) / 1000 ))
}

LUMINANCE=$(hex_to_luminance "$BASE_COLOR")
if [[ $LUMINANCE -gt 140 ]]; then
    IS_LIGHT=true
    BASE_THEME_NAME="catppuccin-latte-lavender"
    declare -n CATPPUCCIN_SRC=CATPPUCCIN_LATTE
    echo "Detected light theme (luminance: $LUMINANCE)"
else
    IS_LIGHT=false
    BASE_THEME_NAME="catppuccin-mocha-lavender"
    declare -n CATPPUCCIN_SRC=CATPPUCCIN_MOCHA
    echo "Detected dark theme (luminance: $LUMINANCE)"
fi

# Find base theme
BASE_THEME="$OUTPUT_DIR/$BASE_THEME_NAME"

if [[ ! -d "$BASE_THEME" ]]; then
    # Try system location
    BASE_THEME="/usr/share/Kvantum/$BASE_THEME_NAME"
fi

if [[ ! -d "$BASE_THEME" ]]; then
    echo "Error: No catppuccin Kvantum theme found: $BASE_THEME_NAME"
    echo "Install catppuccin-kvantum first"
    exit 1
fi

echo "Using base theme: $BASE_THEME"

# Load our palette colors
declare -A OUR_COLORS

# Helper to resolve color references
resolve_color() {
    local key="$1"
    local value=$(jq -r ".colors[\"$key\"] // empty" "$PALETTE_FILE")
    if [[ -z "$value" ]]; then
        echo ""
        return
    fi
    if [[ "$value" == \#* ]]; then
        echo "$value"
    else
        # It's a reference to another color
        jq -r ".colors[\"$value\"] // \"$value\"" "$PALETTE_FILE"
    fi
}

# Load structural colors
for key in crust mantle base surface0 surface1 surface2 overlay0 overlay1 overlay2 text subtext1 subtext0; do
    OUR_COLORS[$key]=$(resolve_color "$key")
done

# Load gradient colors (these map to catppuccin rainbow)
GRADIENT=($(jq -r '.gradient[]' "$PALETTE_FILE"))

# Resolve gradient colors
for i in "${!GRADIENT[@]}"; do
    ref="${GRADIENT[$i]}"
    if [[ "$ref" == \#* ]]; then
        GRADIENT[$i]="$ref"
    else
        resolved=$(jq -r ".colors[\"$ref\"] // \"$ref\"" "$PALETTE_FILE")
        GRADIENT[$i]="$resolved"
    fi
done

# Get accent color for lavender replacement
ACCENT=$(resolve_color "accent")
[[ -z "$ACCENT" ]] && ACCENT="${GRADIENT[7]}"  # Default to ~lavender position

# Map semantic colors to catppuccin equivalents
SEM_ERR=$(resolve_color "sem_err")
SEM_WARN=$(resolve_color "sem_warn")
SEM_OK=$(resolve_color "sem_ok")
SEM_INFO=$(resolve_color "sem_info")

# Build color mapping (catppuccin -> ours)
OUR_COLORS[red]="${SEM_ERR:-${GRADIENT[0]}}"
OUR_COLORS[maroon]="${GRADIENT[0]}"
OUR_COLORS[peach]="${GRADIENT[1]}"
OUR_COLORS[yellow]="${SEM_WARN:-${GRADIENT[2]}}"
OUR_COLORS[green]="${SEM_OK:-${GRADIENT[3]}}"
OUR_COLORS[teal]="${GRADIENT[4]}"
OUR_COLORS[sky]="${GRADIENT[5]:-${GRADIENT[4]}}"
OUR_COLORS[sapphire]="${GRADIENT[6]:-${GRADIENT[5]}}"
OUR_COLORS[blue]="${SEM_INFO:-${GRADIENT[6]}}"
OUR_COLORS[lavender]="$ACCENT"
OUR_COLORS[mauve]="${GRADIENT[8]:-${GRADIENT[7]}}"
OUR_COLORS[pink]="${GRADIENT[9]:-${GRADIENT[8]}}"
OUR_COLORS[flamingo]="${GRADIENT[1]}"
OUR_COLORS[rosewater]="${OUR_COLORS[text]}"

# Create output directory
THEME_OUTPUT="$OUTPUT_DIR/$THEME_NAME"
mkdir -p "$THEME_OUTPUT"

echo "Building Kvantum theme: $THEME_NAME"

# Copy base theme files with new name
cp "$BASE_THEME"/*.kvconfig "$THEME_OUTPUT/$THEME_NAME.kvconfig" 2>/dev/null || true
cp "$BASE_THEME"/*.svg "$THEME_OUTPUT/$THEME_NAME.svg" 2>/dev/null || true

# Build sed replacement script
SED_SCRIPT=""
for key in "${!CATPPUCCIN_SRC[@]}"; do
    src_color="${CATPPUCCIN_SRC[$key]}"
    dst_color="${OUR_COLORS[$key]}"

    if [[ -n "$dst_color" && "$src_color" != "$dst_color" ]]; then
        # Case-insensitive replacement
        src_upper=$(echo "$src_color" | tr '[:lower:]' '[:upper:]')
        src_lower=$(echo "$src_color" | tr '[:upper:]' '[:lower:]')
        dst_lower=$(echo "$dst_color" | tr '[:upper:]' '[:lower:]')

        SED_SCRIPT+="s/$src_lower/$dst_lower/gi;"
        SED_SCRIPT+="s/$src_upper/$dst_lower/gi;"
    fi
done

# Apply replacements to kvconfig and svg
echo "  Replacing colors..."
for file in "$THEME_OUTPUT"/*.kvconfig "$THEME_OUTPUT"/*.svg; do
    [[ -f "$file" ]] && sed -i "$SED_SCRIPT" "$file"
done

echo "  Done! Theme installed to: $THEME_OUTPUT"

# Update theme.conf to use this Kvantum theme
THEME_CONF="$SCRIPT_DIR/$THEME_NAME/theme.conf"
if [[ -f "$THEME_CONF" ]]; then
    if grep -q "^kvantum_theme=" "$THEME_CONF"; then
        sed -i "s|^kvantum_theme=.*|kvantum_theme=$THEME_NAME|" "$THEME_CONF"
    fi
    echo "  Updated theme.conf"
fi

echo ""
echo "Kvantum theme '$THEME_NAME' ready!"
echo "Apply with: kvantummanager --set $THEME_NAME"
