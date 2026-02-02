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
        # Apply screen shader if specified in theme.conf
        local theme_conf="$THEMES_DIR/$theme/theme.conf"
        local shader=""
        if [[ -f "$theme_conf" ]]; then
            shader=$(grep -E '^shader=' "$theme_conf" | cut -d= -f2)
        fi
        if [[ -n "$shader" && "$shader" != "none" ]]; then
            hyprctl keyword decoration:screen_shader "$shader" &>/dev/null
            report_ok "hyprland + shader"
        else
            hyprctl keyword decoration:screen_shader "[[EMPTY]]" &>/dev/null
            report_ok "hyprland"
        fi
    else
        report_skip "hyprland (no theme file)"
    fi
}

apply_hyprlock() {
    local theme="$1"
    if copy_to_current "$theme" "hyprlock-colors.conf"; then
        report_ok "hyprlock"
    else
        report_skip "hyprlock (no theme file)"
    fi
}

apply_hyprtoolkit() {
    local theme="$1"
    if copy_to_current "$theme" "hyprtoolkit.conf"; then
        report_ok "hyprtoolkit"
    else
        report_skip "hyprtoolkit (no theme file)"
    fi
}

