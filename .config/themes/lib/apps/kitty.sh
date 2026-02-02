#!/bin/bash
# Kitty terminal theme handler

apply_kitty() {
    local theme="$1"
    if copy_to_current "$theme" "kitty.conf"; then
        # Also copy font config if available
        copy_to_current "$theme" "kitty-font.conf" &>/dev/null
        pkill -SIGUSR1 kitty 2>/dev/null || true
        report_ok "kitty"
    else
        report_skip "kitty (no theme file)"
    fi
}
