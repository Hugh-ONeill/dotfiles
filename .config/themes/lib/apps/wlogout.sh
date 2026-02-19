#!/bin/bash
# wlogout theme handler

apply_wlogout() {
    local theme="$1"
    local theme_css="$GENERATED_DIR/$theme/wlogout.css"

    if [[ -f "$theme_css" ]]; then
        cp "$theme_css" "$HOME/.config/wlogout/style.css"
        copy_to_current "$theme" "wlogout.css" &>/dev/null
        report_ok "wlogout"
    else
        report_skip "wlogout (no theme file)"
    fi
}
