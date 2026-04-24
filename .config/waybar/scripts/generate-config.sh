#!/bin/bash
# Generate waybar config.jsonc from template using current theme colors
# Usage: generate-config.sh [theme-css-path]

WAYBAR_DIR="$HOME/.config/waybar"
TEMPLATE="$WAYBAR_DIR/config.jsonc.template"
OUTPUT="$WAYBAR_DIR/config.jsonc"

# Use provided theme path or follow the symlink
THEME_CSS="${1:-$WAYBAR_DIR/theme.css}"

# Resolve symlink if necessary
if [[ -L "$THEME_CSS" ]]; then
    THEME_CSS=$(readlink -f "$THEME_CSS")
fi

if [[ ! -f "$THEME_CSS" ]]; then
    echo "Error: Theme CSS not found: $THEME_CSS" >&2
    exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
    echo "Error: Template not found: $TEMPLATE" >&2
    exit 1
fi

# Extract color from theme CSS
# Usage: get_color "variable-name"
get_color() {
    local var="$1"
    grep -oP "@define-color\s+${var}\s+\K#[0-9a-fA-F]{6}" "$THEME_CSS" | head -1
}

# Map semantic names to theme variables
# icon-red    -> g0 (warm/danger color)
# icon-orange -> g1 (warm accent)
# icon-green  -> g3 (success/positive)
# icon-blue   -> g6 (primary/cool)
# icon-muted  -> module-fg (neutral)
# calendar-today -> g0 (highlight)

ICON_RED=$(get_color "g0")
ICON_ORANGE=$(get_color "g1")
ICON_GREEN=$(get_color "g3")
ICON_BLUE=$(get_color "g6")
ICON_MUTED=$(get_color "module-fg")
CALENDAR_TODAY=$(get_color "g0")

# Validate we got all colors
missing=()
[[ -z "$ICON_RED" ]] && missing+=("g0/icon-red")
[[ -z "$ICON_ORANGE" ]] && missing+=("g1/icon-orange")
[[ -z "$ICON_GREEN" ]] && missing+=("g3/icon-green")
[[ -z "$ICON_BLUE" ]] && missing+=("g6/icon-blue")
[[ -z "$ICON_MUTED" ]] && missing+=("module-fg/icon-muted")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing colors in theme: ${missing[*]}" >&2
    exit 1
fi

# Generate config from template
sed \
    -e "s/{{icon-red}}/${ICON_RED}/g" \
    -e "s/{{icon-orange}}/${ICON_ORANGE}/g" \
    -e "s/{{icon-green}}/${ICON_GREEN}/g" \
    -e "s/{{icon-blue}}/${ICON_BLUE}/g" \
    -e "s/{{icon-muted}}/${ICON_MUTED}/g" \
    -e "s/{{calendar-today}}/${CALENDAR_TODAY}/g" \
    "$TEMPLATE" > "$OUTPUT"

echo "Generated $OUTPUT from $THEME_CSS"
echo "  icon-red:      $ICON_RED"
echo "  icon-orange:   $ICON_ORANGE"
echo "  icon-green:    $ICON_GREEN"
echo "  icon-blue:     $ICON_BLUE"
echo "  icon-muted:    $ICON_MUTED"
echo "  calendar-today: $CALENDAR_TODAY"
