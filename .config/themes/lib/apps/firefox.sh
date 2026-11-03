#!/bin/bash
# Firefox handler — writes shared user.js prefs, copies color CSS + ensures @import in userChrome

# Profiles live under the legacy path OR the newer XDG path. Firefox >=~140
# uses ~/.config/mozilla for fresh profiles when ~/.mozilla doesn't exist.
firefox_profiles() {
    local root profile
    for root in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
        [[ -d "$root" ]] || continue
        for profile in "$root"/*.default*; do
            [[ -d "$profile" ]] && echo "$profile"
        done
    done
}

# Write each profile's user.js from the shared prefs + optional per-machine prefs
apply_firefox_prefs() {
    local shared="$HOME/.config/firefox/user.js"
    local local_prefs="$HOME/.config/firefox/user-local.js"
    local profile

    [[ -f "$shared" ]] || return 0
    while read -r profile; do
        if [[ -f "$local_prefs" ]]; then
            cat "$shared" "$local_prefs" > "$profile/user.js"
        else
            cp "$shared" "$profile/user.js"
        fi
    done < <(firefox_profiles)
}

apply_firefox() {
    local theme="$1"
    local src="$GENERATED_DIR/$theme/firefox-colors.css"
    local applied=0 profile

    apply_firefox_prefs

    if [[ ! -f "$src" ]]; then
        report_skip "firefox (no theme file)"
        return
    fi

    while read -r profile; do
        local chrome_dir="$profile/chrome"
        mkdir -p "$chrome_dir"
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

        ((++applied))
    done < <(firefox_profiles)

    if [[ $applied -gt 0 ]]; then
        report_ok "firefox (restart to apply)"
    else
        report_skip "firefox (no profiles found)"
    fi
}
