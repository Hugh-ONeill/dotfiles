#!/bin/bash
# Hyprland theme handler

apply_hyprland() {
    local theme="$1"
    if copy_to_current "$theme" "hypr-colors.conf"; then
        hyprctl reload &>/dev/null || true
        # Set cursor theme
        if [[ -x "$HOME/.config/hypr/scripts/set-cursor.sh" ]]; then
            "$HOME/.config/hypr/scripts/set-cursor.sh" &>/dev/null
        fi
        report_ok "hyprland"

        # Toggle hyprbars plugin based on decoration style
        local json_palette="$PALETTES_DIR/$theme.json"
        local decoration=$(jq -r '.style.decoration // "none"' "$json_palette" 2>/dev/null)
        local hyprbars_so="/var/cache/hyprpm/wiz/hyprland-plugins/hyprbars.so"
        if [[ "$decoration" == "hyprbars" && -f "$hyprbars_so" ]]; then
            hyprctl plugin load "$hyprbars_so" &>/dev/null
        else
            hyprctl plugin unload "$hyprbars_so" &>/dev/null
        fi
    else
        report_skip "hyprland (no theme file)"
    fi
}

apply_hyprlock()    { apply_simple "$1" "hyprlock-colors.conf" "hyprlock"; }
apply_hyprtoolkit() { apply_simple "$1" "hyprtoolkit.conf"     "hyprtoolkit"; }

