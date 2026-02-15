#!/bin/bash
# Firefox theme handler — copies color CSS + ensures @import in userChrome

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
        local chrome_dir="$profile/chrome"
        cp "$src" "$chrome_dir/theme-colors.css"

        # Ensure userChrome.css imports the theme colors
        local userchrome="$chrome_dir/userChrome.css"
        if [[ ! -f "$userchrome" ]] || ! grep -q "theme-colors.css" "$userchrome" 2>/dev/null; then
            if [[ -f "$userchrome" ]]; then
                local existing=$(cat "$userchrome")
                echo -e '@import "theme-colors.css";\n'"$existing" > "$userchrome"
            else
                echo '@import "theme-colors.css";' > "$userchrome"
            fi
        fi

        ((applied++))
    done

    if [[ $applied -gt 0 ]]; then
        report_ok "firefox (restart to apply)"
    else
        report_skip "firefox (no profiles with chrome dir)"
    fi
}
