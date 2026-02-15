#!/bin/bash
# Set cursor theme based on current theme

COLORS_CONF="$HOME/.config/hypr/appearance/colors.conf"

if [[ -f "$COLORS_CONF" ]]; then
    # Extract cursor_theme from colors.conf
    cursor_theme=$(grep '^\$cursor_theme' "$COLORS_CONF" | sed 's/.*= *//')
    cursor_size=$(grep '^\$cursor_size' "$COLORS_CONF" | sed 's/.*= *//' || echo "24")

    if [[ -n "$cursor_theme" ]]; then
        hyprctl setcursor "$cursor_theme" "${cursor_size:-24}"
        # Also set env vars for toolkits
        export XCURSOR_THEME="$cursor_theme"
        export XCURSOR_SIZE="${cursor_size:-24}"
        export HYPRCURSOR_THEME="$cursor_theme"
        export HYPRCURSOR_SIZE="${cursor_size:-24}"
    fi
fi
