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

# Prepend @import "<name>" to a userChrome/userContent file unless it's there.
# @import must come before any other rule, so it always goes first.
ensure_firefox_import() {
    local file="$1" name="$2"
    grep -q "$name" "$file" 2>/dev/null && return
    if [[ -f "$file" ]]; then
        local existing
        existing=$(cat "$file")
        printf '@import "%s";\n%s\n' "$name" "$existing" > "$file"
    else
        printf '@import "%s";\n' "$name" > "$file"
    fi
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

    local content_src="$GENERATED_DIR/$theme/firefox-content.css"

    while read -r profile; do
        local chrome_dir="$profile/chrome"
        mkdir -p "$chrome_dir"
        cp "$src" "$chrome_dir/theme-colors.css"
        ensure_firefox_import "$chrome_dir/userChrome.css" "theme-colors.css"

        # about: pages (newtab, preferences, addons) via userContent.css
        if [[ -f "$content_src" ]]; then
            cp "$content_src" "$chrome_dir/theme-content.css"
            ensure_firefox_import "$chrome_dir/userContent.css" "theme-content.css"
        fi

        ((++applied))
    done < <(firefox_profiles)

    if [[ $applied -gt 0 ]]; then
        report_ok "firefox (restart to apply)"
    else
        report_skip "firefox (no profiles found)"
    fi
}
