#!/bin/bash
# Theme system utility functions

get_themes() {
    find "$THEMES_DIR" -maxdepth 1 -mindepth 1 -type d \
        ! -name "palettes" ! -name "templates" ! -name "lib" ! -name "current" \
        -printf "%f\n" | sort
}

get_current() {
    [[ -f "$CURRENT_THEME_FILE" ]] && cat "$CURRENT_THEME_FILE" || echo "unknown"
}

has_palette() {
    local theme="$1"
    [[ -f "$PALETTES_DIR/$theme.sh" ]] || [[ -f "$THEMES_DIR/$theme/palette.sh" ]]
}

get_palette_path() {
    local theme="$1"
    if [[ -f "$THEMES_DIR/$theme/palette.sh" ]]; then
        echo "$THEMES_DIR/$theme/palette.sh"
    elif [[ -f "$PALETTES_DIR/$theme.sh" ]]; then
        echo "$PALETTES_DIR/$theme.sh"
    fi
}

# Copy file from theme to current/
copy_to_current() {
    local theme="$1"
    local filename="$2"
    local src="$THEMES_DIR/$theme/$filename"
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
