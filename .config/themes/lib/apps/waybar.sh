#!/bin/bash
# Waybar theme handler

apply_waybar() {
    local theme="$1"
    local palette_path="$2"

    if copy_to_current "$theme" "waybar.css"; then
        # Update power icon color from palette
        if [[ -n "$palette_path" ]]; then
            local icon_color=$(grep -oP '^export CRUST="\K[^"]+' "$palette_path" 2>/dev/null)
            if [[ -n "$icon_color" ]]; then
                sed -i "s/<span color='#[^']*'>/<span color='$icon_color'>/" "$HOME/.config/waybar/config.jsonc"
            fi
        fi
        # Full restart needed for structural changes
        if pgrep -x waybar >/dev/null; then
            pkill -x waybar 2>/dev/null
            sleep 0.3
            waybar &>/dev/null &
            disown
        fi
        report_ok "waybar"
    else
        report_skip "waybar (no theme file)"
    fi
}
