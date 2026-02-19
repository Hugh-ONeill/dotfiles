#!/bin/bash
# Build GTK or Kvantum theme by find-replacing catppuccin colors with palette
# Usage: build-catppuccin-retheme.sh --gtk <theme> [--all]
#        build-catppuccin-retheme.sh --kvantum <theme> [--all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/lib/config.sh"
source "$LIB_DIR/utils.sh"

# ============================================================
# CATPPUCCIN BASE COLORS
# ============================================================

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

# ============================================================
# TARGET-SPECIFIC FUNCTIONS
# ============================================================

# ---- GTK target ----

gtk_find_base() {
    local base_name="$1"
    local result
    result=$(find /usr/share/themes ~/.local/share/themes ~/.themes \
        -maxdepth 1 -type d -name "${base_name}-lavender-standard+default" 2>/dev/null | head -1)
    if [[ -z "$result" ]]; then
        result=$(find /usr/share/themes ~/.local/share/themes ~/.themes \
            -maxdepth 1 -type d -name "${base_name}-*-standard+default" 2>/dev/null | head -1)
    fi
    echo "$result"
}

gtk_copy_base() {
    local base_theme="$1" output="$2"
    cp -r "$base_theme"/* "$output/"
}

gtk_sed_files() {
    local output="$1" sed_script="$2"
    find "$output" -type f \( -name "*.css" -o -name "*.svg" \) | while read -r file; do
        sed -i "$sed_script" "$file"
    done
    if [[ -d "$output/gnome-shell" ]]; then
        find "$output/gnome-shell" -type f -name "*.css" | while read -r file; do
            sed -i "$sed_script" "$file"
        done
    fi
}

gtk_post_process() {
    local theme_name="$1" output="$2"
    cat > "$output/index.theme" << EOF
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=$theme_name
Comment=GTK theme generated from $theme_name palette
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=$theme_name
MetacityTheme=$theme_name
IconTheme=Papirus-Dark
CursorTheme=Adwaita
ButtonLayout=close,minimize,maximize:menu
EOF
}

# ---- Kvantum target ----

kvantum_find_base() {
    local base_name="$1"
    local kvantum_dir="$HOME/.config/Kvantum"
    if [[ -d "$kvantum_dir/$base_name" ]]; then
        echo "$kvantum_dir/$base_name"
    elif [[ -d "/usr/share/Kvantum/$base_name" ]]; then
        echo "/usr/share/Kvantum/$base_name"
    fi
}

kvantum_copy_base() {
    local base_theme="$1" output="$2" theme_name="$3"
    cp "$base_theme"/*.kvconfig "$output/$theme_name.kvconfig" 2>/dev/null || true
    cp "$base_theme"/*.svg "$output/$theme_name.svg" 2>/dev/null || true
}

kvantum_sed_files() {
    local output="$1" sed_script="$2"
    for file in "$output"/*.kvconfig "$output"/*.svg; do
        [[ -f "$file" ]] && sed -i "$sed_script" "$file"
    done
}

kvantum_post_process() { :; }

# ============================================================
# MAIN
# ============================================================

# Parse target flag
TARGET=""
shift_args=0
case "${1:-}" in
    --gtk)     TARGET="gtk";     shift; shift_args=1 ;;
    --kvantum) TARGET="kvantum"; shift; shift_args=1 ;;
    *)
        echo "Usage: $0 --gtk|--kvantum <theme-name> [--all]"
        exit 1
        ;;
esac

if [[ -z "$1" ]]; then
    echo "Usage: $0 --$TARGET <theme-name> [--all]"
    echo ""
    echo "Available themes:"
    for f in "$PALETTES_DIR"/*.json; do
        [[ -f "$f" ]] && basename "$f" .json
    done
    exit 1
fi

# Build all themes
if [[ "$1" == "--all" ]]; then
    for f in "$PALETTES_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        theme=$(basename "$f" .json)
        [[ "$theme" == "chameleon" ]] && continue
        "$0" "--$TARGET" "$theme"
    done
    exit 0
fi

THEME_NAME="$1"
PALETTE_FILE="$PALETTES_DIR/$THEME_NAME.json"

if [[ ! -f "$PALETTE_FILE" ]]; then
    echo "Error: Palette not found: $PALETTE_FILE"
    exit 1
fi

# ---- Detect light/dark ----
BASE_COLOR=$(jq -r '.colors.base' "$PALETTE_FILE")
if [[ "$BASE_COLOR" != \#* ]]; then
    BASE_COLOR=$(jq -r ".colors[\"$BASE_COLOR\"] // .colors.base" "$PALETTE_FILE")
fi

LUMINANCE=$(hex_luminance "$BASE_COLOR")
if [[ $LUMINANCE -gt $LUMINANCE_THRESHOLD ]]; then
    IS_LIGHT=true
    declare -n CATPPUCCIN_SRC=CATPPUCCIN_LATTE
    echo "Detected light theme (luminance: $LUMINANCE)"
else
    IS_LIGHT=false
    declare -n CATPPUCCIN_SRC=CATPPUCCIN_MOCHA
    echo "Detected dark theme (luminance: $LUMINANCE)"
fi

# ---- Set target-specific base theme name + output dir ----
case "$TARGET" in
    gtk)
        if $IS_LIGHT; then BASE_THEME_NAME="catppuccin-latte"; else BASE_THEME_NAME="catppuccin-mocha"; fi
        OUTPUT_DIR="$HOME/.themes"
        BASE_THEME=$(gtk_find_base "$BASE_THEME_NAME")
        [[ -z "$BASE_THEME" ]] && { echo "Error: No catppuccin GTK base theme found. Install catppuccin-gtk first."; exit 1; }
        ;;
    kvantum)
        if $IS_LIGHT; then BASE_THEME_NAME="catppuccin-latte-lavender"; else BASE_THEME_NAME="catppuccin-mocha-lavender"; fi
        OUTPUT_DIR="$HOME/.config/Kvantum"
        BASE_THEME=$(kvantum_find_base "$BASE_THEME_NAME")
        [[ -z "$BASE_THEME" ]] && { echo "Error: No catppuccin Kvantum theme found: $BASE_THEME_NAME. Install catppuccin-kvantum first."; exit 1; }
        ;;
esac

echo "Using base theme: $BASE_THEME"

# ---- Load palette colors ----
declare -A OUR_COLORS
load_palette_colors OUR_COLORS "$PALETTE_FILE"

# Load and resolve gradient
GRADIENT=($(jq -r '.gradient[]' "$PALETTE_FILE"))
for i in "${!GRADIENT[@]}"; do
    ref="${GRADIENT[$i]}"
    if [[ "$ref" != \#* ]]; then
        resolved=$(jq -r ".colors[\"$ref\"] // \"$ref\"" "$PALETTE_FILE")
        GRADIENT[$i]="$resolved"
    fi
done

# Map gradient to catppuccin rainbow names
ACCENT=$(resolve_color "accent" "$PALETTE_FILE")
[[ -z "$ACCENT" ]] && ACCENT="${GRADIENT[7]}"

SEM_ERR=$(resolve_color "sem_err" "$PALETTE_FILE")
SEM_WARN=$(resolve_color "sem_warn" "$PALETTE_FILE")
SEM_OK=$(resolve_color "sem_ok" "$PALETTE_FILE")
SEM_INFO=$(resolve_color "sem_info" "$PALETTE_FILE")

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

# ---- Build + apply ----
THEME_OUTPUT="$OUTPUT_DIR/$THEME_NAME"
mkdir -p "$THEME_OUTPUT"

echo "Building $TARGET theme: $THEME_NAME"

case "$TARGET" in
    gtk)     gtk_copy_base "$BASE_THEME" "$THEME_OUTPUT" ;;
    kvantum) kvantum_copy_base "$BASE_THEME" "$THEME_OUTPUT" "$THEME_NAME" ;;
esac

# Build sed replacement script
SED_SCRIPT=""
for key in "${!CATPPUCCIN_SRC[@]}"; do
    src_color="${CATPPUCCIN_SRC[$key]}"
    dst_color="${OUR_COLORS[$key]}"
    if [[ -n "$dst_color" && "$src_color" != "$dst_color" ]]; then
        src_lower=$(echo "$src_color" | tr '[:upper:]' '[:lower:]')
        dst_lower=$(echo "$dst_color" | tr '[:upper:]' '[:lower:]')
        SED_SCRIPT+="s/$src_lower/$dst_lower/gi;"
    fi
done

echo "  Replacing colors..."
case "$TARGET" in
    gtk)     gtk_sed_files "$THEME_OUTPUT" "$SED_SCRIPT" ;;
    kvantum) kvantum_sed_files "$THEME_OUTPUT" "$SED_SCRIPT" ;;
esac

case "$TARGET" in
    gtk)     gtk_post_process "$THEME_NAME" "$THEME_OUTPUT" ;;
    kvantum) kvantum_post_process ;;
esac

echo "  Done! Theme installed to: $THEME_OUTPUT"

# Update theme.conf
THEME_CONF="$GENERATED_DIR/$THEME_NAME/theme.conf"
if [[ -f "$THEME_CONF" ]]; then
    case "$TARGET" in
        gtk)     conf_key="gtk_theme" ;;
        kvantum) conf_key="kvantum_theme" ;;
    esac
    if grep -q "^${conf_key}=" "$THEME_CONF"; then
        sed -i "s|^${conf_key}=.*|${conf_key}=$THEME_NAME|" "$THEME_CONF"
        echo "  Updated theme.conf"
    fi
fi

echo ""
echo "$TARGET theme '$THEME_NAME' ready!"
