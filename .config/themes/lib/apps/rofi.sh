#!/bin/bash
# Rofi theme handler

apply_rofi() {
    local theme="$1"
    local ok=false
    if copy_to_current "$theme" "rofi-colors.rasi"; then
        ok=true
    fi
    # Also copy fonts if available
    copy_to_current "$theme" "fonts.rasi" &>/dev/null
    if $ok; then
        report_ok "rofi"
    else
        report_skip "rofi (no theme file)"
    fi
}
