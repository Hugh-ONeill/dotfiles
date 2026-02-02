#!/bin/bash
# Firefox theme handler - applies on restart

apply_firefox() {
    local theme="$1"
    local src="$THEMES_DIR/$theme/firefox-colors.css"
    local profile_dir="$HOME/.mozilla/firefox"
    local applied=0

    if [[ ! -f "$src" ]]; then
        report_skip "firefox (no theme file)"
        return
    fi

    # Apply to all Firefox profiles with a chrome directory
    for profile in "$profile_dir"/*.default*; do
        [[ -d "$profile/chrome" ]] || continue
        cp "$src" "$profile/chrome/theme-colors.css"
        ((applied++))
    done

    if [[ $applied -gt 0 ]]; then
        report_ok "firefox (restart to apply)"
    else
        report_skip "firefox (no profiles with chrome dir)"
    fi
}
