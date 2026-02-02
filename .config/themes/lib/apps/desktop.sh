#!/bin/bash
# Desktop environment theme handler (GTK, QT, dunst, spicetify, pywal)

apply_dunst() {
    local theme="$1"
    if copy_to_current "$theme" "dunst-colors.conf"; then
        # Copy themed icons if available
        copy_to_current "$theme" "dunst-icons" 2>/dev/null
        pkill dunst 2>/dev/null || true
        report_ok "dunst"
    else
        report_skip "dunst (no theme file)"
    fi
}

apply_gtk_qt() {
    local theme="$1"
    local theme_dir="$THEMES_DIR/$theme"
    local theme_conf="$theme_dir/theme.conf"

    [[ ! -f "$theme_conf" ]] && { report_skip "gtk/qt (no theme.conf)"; return; }

    get_conf() { grep -oP "^$1=\K.*" "$theme_conf" 2>/dev/null | tr -d '"'; }

    # GTK4 css
    if copy_to_current "$theme" "gtk.css"; then
        report_ok "gtk4 css"
    fi

    # GTK theme via gsettings
    local gtk_theme=$(get_conf gtk_theme)
    local gtk_icon_theme=$(get_conf gtk_icon_theme)
    local gtk_cursor_theme=$(get_conf gtk_cursor_theme)
    local gtk_cursor_size=$(get_conf gtk_cursor_size)

    if [[ -n "$gtk_theme" ]] && command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
        report_ok "gtk theme ($gtk_theme)"
    fi

    if [[ -n "$gtk_icon_theme" ]] && command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface icon-theme "$gtk_icon_theme" 2>/dev/null || true
        report_ok "icon theme ($gtk_icon_theme)"
    fi

    if [[ -n "$gtk_cursor_theme" ]] && command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface cursor-theme "$gtk_cursor_theme" 2>/dev/null || true
        [[ -n "$gtk_cursor_size" ]] && gsettings set org.gnome.desktop.interface cursor-size "$gtk_cursor_size" 2>/dev/null || true
        hyprctl setcursor "$gtk_cursor_theme" "${gtk_cursor_size:-24}" &>/dev/null || true
        report_ok "cursor theme ($gtk_cursor_theme)"
    fi

    # QT theme
    local qt_color_scheme=$(get_conf qt_color_scheme)
    if [[ -n "$qt_color_scheme" ]]; then
        local qt_applied=false
        for qtconf in "$HOME/.config/qt5ct/qt5ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"; do
            if [[ -f "$qtconf" ]]; then
                sed -i "s|^color_scheme_path=.*|color_scheme_path=${qtconf%/*}/colors/$qt_color_scheme|" "$qtconf" 2>/dev/null || true
                qt_applied=true
            fi
        done
        $qt_applied && report_ok "qt color scheme ($qt_color_scheme)"
    fi

    # Kvantum
    local kvantum_theme=$(get_conf kvantum_theme)
    if [[ -n "$kvantum_theme" ]] && command -v kvantummanager &>/dev/null; then
        kvantummanager --set "$kvantum_theme" 2>/dev/null || true
        report_ok "kvantum ($kvantum_theme)"
    fi
}

apply_spicetify() {
    local theme="$1"
    if [[ -d "$HOME/.config/spicetify/Themes/$theme" ]]; then
        spicetify config current_theme "$theme" 2>/dev/null
        spicetify apply 2>/dev/null &
        report_ok "spicetify"
    else
        report_skip "spicetify (no theme)"
    fi
}

apply_pywal() {
    local theme="$1"
    if [[ -f "$HOME/.config/wal/colorschemes/dark/$theme.json" ]]; then
        wal --theme "$theme" -n -s -t -e -q 2>/dev/null
        report_ok "pywal"
    else
        report_skip "pywal (no colorscheme)"
    fi
}

apply_stylus() {
    local theme="$1"
    local theme_dir="$THEMES_DIR/$theme"
    local stylus_dir="$theme_dir/stylus"

    [[ ! -d "$stylus_dir" ]] && { report_skip "stylus (no styles)"; return; }

    # Copy to current for easy access
    if copy_to_current "$theme" "stylus"; then
        report_ok "stylus (import from ~/.config/themes/current/stylus/)"
    else
        report_skip "stylus"
    fi
}

apply_firefox() {
    local theme="$1"
    local theme_dir="$THEMES_DIR/$theme"
    local colors_file="$theme_dir/firefox-colors.css"
    local theme_data="$theme_dir/firefox-theme-data.json"

    # Copy userChrome.css colors (fallback for when extension not installed)
    if [[ -f "$colors_file" ]]; then
        local profile_dir=""
        for dir in "$HOME"/.mozilla/firefox/*.default-release "$HOME"/.mozilla/firefox/*.default; do
            [[ -d "$dir" ]] && { profile_dir="$dir"; break; }
        done

        if [[ -n "$profile_dir" ]]; then
            local chrome_dir="$profile_dir/chrome"
            mkdir -p "$chrome_dir"
            cp "$colors_file" "$chrome_dir/theme-colors.css"

            local userchrome="$chrome_dir/userChrome.css"
            if [[ ! -f "$userchrome" ]] || ! grep -q "theme-colors.css" "$userchrome" 2>/dev/null; then
                if [[ -f "$userchrome" ]]; then
                    local existing=$(cat "$userchrome")
                    echo -e '@import "theme-colors.css";\n'"$existing" > "$userchrome"
                else
                    echo '@import "theme-colors.css";' > "$userchrome"
                fi
            fi
        fi
    fi

    # Hot-swap via extension if Firefox is running and theme data exists
    if [[ -f "$theme_data" ]] && pgrep -x firefox &>/dev/null; then
        local json_data=$(cat "$theme_data" | tr -d '\n')
        local b64=$(echo -n "$json_data" | base64 -w0)

        # Open URL directly - extension intercepts via webNavigation
        firefox "https://theme-switch.local/?data=${b64}" &>/dev/null &

        report_ok "firefox (hot-swap)"
    else
        report_ok "firefox (restart to apply)"
    fi
}
