#!/bin/bash
# Theme system utility functions

get_themes() {
    find "$GENERATED_DIR" -maxdepth 1 -mindepth 1 -type d \
        -printf "%f\n" | sort
}

get_current() {
    [[ -f "$CURRENT_THEME_FILE" ]] && cat "$CURRENT_THEME_FILE" || echo "unknown"
}

has_palette() {
    local theme="$1"
    [[ -f "$PALETTES_DIR/$theme.json" ]] || [[ -f "$GENERATED_DIR/$theme/palette.json" ]]
}

get_palette_path() {
    local theme="$1"
    if [[ -f "$GENERATED_DIR/$theme/palette.json" ]]; then
        echo "$GENERATED_DIR/$theme/palette.json"
    elif [[ -f "$PALETTES_DIR/$theme.json" ]]; then
        echo "$PALETTES_DIR/$theme.json"
    fi
}

# Copy file from theme to current/
copy_to_current() {
    local theme="$1"
    local filename="$2"
    local src="$GENERATED_DIR/$theme/$filename"
    if [[ -e "$src" ]]; then
        rm -rf "$CURRENT_DIR/$filename"
        cp -r "$src" "$CURRENT_DIR/$filename"
        return 0
    fi
    return 1
}

# Report success/skip for an app
report_ok() { echo -e "  ${GREEN}✓${NC} $1"; }
report_skip() { echo -e "  ${YELLOW}⊘${NC} $1"; }
report_err() { echo -e "  ${RED}✗${NC} $1"; }

# Copy-and-report shorthand for simple app handlers
apply_simple() {
    local theme="$1" filename="$2" name="$3"
    if copy_to_current "$theme" "$filename"; then
        report_ok "$name"
    else
        report_skip "$name (no theme file)"
    fi
}

# ============================================================
# COLOR UTILITIES
# ============================================================

# Convert hex color to semicolon-separated RGB (e.g. #ff0000 -> 255;0;0)
hex_to_rgb() {
    local hex="${1#\#}"
    printf "%d;%d;%d" "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

# Calculate perceived luminance (0-255) from hex color
hex_luminance() {
    local hex="${1#\#}"
    local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
    echo $(( (299 * r + 587 * g + 114 * b) / 1000 ))
}

# Print a colored terminal block from hex color
color_block() {
    local hex="${1#\#}"
    [[ -z "$hex" || "$hex" == "null" ]] && return
    printf "\033[48;2;%d;%d;%dm  \033[0m" "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

# ---- Palette loading ----

# Load all palette colors into an associative array, resolving references.
# Usage: declare -A COLORS; load_palette_colors COLORS /path/to/palette.json
load_palette_colors() {
    local -n _colors_ref="$1"
    local palette_file="$2"

    # first pass: hex values
    while IFS='=' read -r key value; do
        _colors_ref["$key"]="$value"
    done < <(jq -r '.colors | to_entries[] | select(.value | startswith("#")) | "\(.key)=\(.value)"' "$palette_file")

    # second pass: resolve references
    while IFS='=' read -r key ref; do
        local resolved="${_colors_ref[$ref]}"
        if [[ -n "$resolved" ]]; then
            _colors_ref["$key"]="$resolved"
        else
            echo "Warning: unresolved reference '$ref' for '$key'" >&2
        fi
    done < <(jq -r '.colors | to_entries[] | select(.value | startswith("#") | not) | "\(.key)=\(.value)"' "$palette_file")
}

# Resolve a single color key from a palette JSON, following one level of reference.
# Usage: resolve_color "accent" /path/to/palette.json
resolve_color() {
    local key="$1" palette_file="$2"
    local value
    value=$(jq -r ".colors[\"$key\"] // empty" "$palette_file")
    [[ -z "$value" ]] && return
    if [[ "$value" == \#* ]]; then
        echo "$value"
    else
        jq -r ".colors[\"$value\"] // \"$value\"" "$palette_file"
    fi
}
