#!/bin/bash
# wlogout theme handler

apply_wlogout() {
    local theme="$1"
    local theme_css="$GENERATED_DIR/$theme/wlogout.css"
    local theme_css2="$GENERATED_DIR/$theme/wlogout-style-2.css"
    local applied=false

    if [[ -f "$theme_css" ]]; then
        cp "$theme_css" "$HOME/.config/wlogout/style.css"
        copy_to_current "$theme" "wlogout.css" &>/dev/null
        applied=true
    fi

    if [[ -f "$theme_css2" ]]; then
        cp "$theme_css2" "$HOME/.config/wlogout/style-2.css"
        copy_to_current "$theme" "wlogout-style-2.css" &>/dev/null
        applied=true
    fi

    if $applied; then
        report_ok "wlogout"
    else
        report_skip "wlogout (no theme file)"
    fi
}
