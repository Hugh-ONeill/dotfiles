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
    local theme_dir="$GENERATED_DIR/$theme"
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

    # gtk-3.0/settings.ini wins over gsettings outside GNOME (no portal mapping
    # under Hyprland), so any GTK3 app that doesn't speak gsettings — pinentry-gtk,
    # for one — reads the .ini directly. Keep both surfaces in sync.
    local gtk3_ini="$HOME/.config/gtk-3.0/settings.ini"
    update_gtk3_ini() {
        local key="$1" val="$2"
        [[ -f "$gtk3_ini" && -n "$val" ]] || return
        if grep -q "^$key=" "$gtk3_ini"; then
            sed -i "s|^$key=.*|$key=$val|" "$gtk3_ini"
        else
            echo "$key=$val" >> "$gtk3_ini"
        fi
    }

    if [[ -n "$gtk_theme" ]] && command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
        update_gtk3_ini gtk-theme-name "$gtk_theme"
        report_ok "gtk theme ($gtk_theme)"
    fi

    if [[ -n "$gtk_icon_theme" ]] && command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface icon-theme "$gtk_icon_theme" 2>/dev/null || true
        update_gtk3_ini gtk-icon-theme-name "$gtk_icon_theme"
        report_ok "icon theme ($gtk_icon_theme)"
    fi

    if [[ -n "$gtk_cursor_theme" ]] && command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface cursor-theme "$gtk_cursor_theme" 2>/dev/null || true
        [[ -n "$gtk_cursor_size" ]] && gsettings set org.gnome.desktop.interface cursor-size "$gtk_cursor_size" 2>/dev/null || true
        update_gtk3_ini gtk-cursor-theme-name "$gtk_cursor_theme"
        [[ -n "$gtk_cursor_size" ]] && update_gtk3_ini gtk-cursor-theme-size "$gtk_cursor_size"
        hyprctl setcursor "$gtk_cursor_theme" "${gtk_cursor_size:-24}" &>/dev/null || true
        report_ok "cursor theme ($gtk_cursor_theme)"
    fi

    # Kvantum
    local kvantum_theme=$(get_conf kvantum_theme)
    if [[ -n "$kvantum_theme" ]] && command -v kvantummanager &>/dev/null; then
        kvantummanager --set "$kvantum_theme" 2>/dev/null || true
        report_ok "kvantum ($kvantum_theme)"
    fi
}

apply_qt() {
    local theme="$1"
    local src="$GENERATED_DIR/$theme/qt-colorscheme.conf"

    [[ ! -f "$src" ]] && { report_skip "qt (no qt-colorscheme.conf)"; return; }

    copy_to_current "$theme" "qt-colorscheme.conf" >/dev/null

    local applied=false
    for qtdir in "$HOME/.config/qt5ct" "$HOME/.config/qt6ct"; do
        [[ -d "$qtdir" ]] || continue
        mkdir -p "$qtdir/colors"
        cp "$CURRENT_DIR/qt-colorscheme.conf" "$qtdir/colors/current.conf"
        local qtconf="$qtdir/$(basename "$qtdir").conf"
        [[ -f "$qtconf" ]] && sed -i "s|^color_scheme_path=.*|color_scheme_path=$qtdir/colors/current.conf|" "$qtconf" 2>/dev/null
        # Icon theme follows GTK's (Papirus-<theme> overlay for Dolphin et al.)
        local icons
        icons=$(grep -oP '^gtk_icon_theme=\K.*' "$GENERATED_DIR/$theme/theme.conf" 2>/dev/null | tr -d '"')
        [[ -f "$qtconf" && -n "$icons" ]] && sed -i "s|^icon_theme=.*|icon_theme=$icons|" "$qtconf" 2>/dev/null
        # KDE apps (Dolphin) call KIconTheme::initTheme(), which overrides qt6ct
        # with kdeglobals [Icons] Theme and falls back to Breeze when it's unset
        [[ -n "$icons" ]] && command -v kwriteconfig6 &>/dev/null \
            && kwriteconfig6 --file kdeglobals --group Icons --key Theme "$icons"
        applied=true
    done

    # Restart long-running Qt daemons so they pick up the new color scheme.
    # Most Qt apps cache palette at startup; hyprpolkitagent is the user-facing
    # one (sudo/auth dialogs).
    systemctl --user is-active --quiet hyprpolkitagent 2>/dev/null \
        && systemctl --user restart hyprpolkitagent 2>/dev/null

    $applied && report_ok "qt color scheme" || report_skip "qt (no qt5ct/qt6ct config dir)"
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

apply_spicetify() {
    local theme="$1"
    command -v spicetify &>/dev/null || { report_skip "spicetify (not installed)"; return; }
    # spotify-launcher only downloads Spotify on first launch; nothing to patch before that
    local spath
    spath=$(grep -oP '^spotify_path\s*=\s*\K.*' "$HOME/.config/spicetify/config-xpui.ini" 2>/dev/null)
    if [[ -z "$spath" ]]; then
        if [[ -d "$HOME/.local/share/spotify-launcher/install/usr/share/spotify" ]]; then
            spicetify -q config spotify_path "$HOME/.local/share/spotify-launcher/install/usr/share/spotify/" \
                prefs_path "$HOME/.config/spotify/prefs"
        else
            report_skip "spicetify (Spotify not downloaded yet; launch it once)"
            return
        fi
    fi
    copy_to_current "$theme" "spicetify-color.ini" || { report_skip "spicetify (no theme file)"; return; }
    # Themes/palette/color.ini is a symlink to current/spicetify-color.ini
    if [[ "$(spicetify config current_theme 2>/dev/null)" != "palette" ]]; then
        spicetify -q config current_theme palette color_scheme palette
    fi
    # Rewrites Spotify's xpui colors; a running Spotify shows them after a restart.
    # spotify-launcher updates wipe the patch, so fall back to re-applying it.
    if spicetify -q -n refresh 2>/dev/null || spicetify -q -n backup apply 2>/dev/null; then
        report_ok "spicetify (restart Spotify to apply)"
    else
        report_skip "spicetify (refresh and re-apply failed; run: spicetify backup apply)"
    fi
}

apply_aseprite() {
    local theme="$1"
    local src="$GENERATED_DIR/$theme/aseprite"
    local ext="$HOME/.config/aseprite/extensions/palette-theme" ini="$HOME/.config/aseprite/aseprite.ini"
    [[ -d "$HOME/.config/aseprite" ]] || { report_skip "aseprite (not set up)"; return; }
    [[ -f "$src/theme.xml" ]] || { report_skip "aseprite (no theme)"; return; }
    mkdir -p "$ext" && cp "$src"/* "$ext/"
    # Select it; Aseprite rewrites aseprite.ini on exit, so a running one keeps its choice
    if [[ -f "$ini" ]] && grep -q '^\[theme\]' "$ini"; then
        sed -i '/^\[theme\]/,/^\[/{s/^selected = .*/selected = palette/}' "$ini"
    fi
    report_ok "aseprite (restart Aseprite to apply)"
}

# #rrggbb -> "r, g, b" as 0-1 floats, for Godot's Color(...)
hex_to_godot() {
    local h="${1#\#}"
    awk -v r=$((16#${h:0:2})) -v g=$((16#${h:2:2})) -v b=$((16#${h:4:2})) \
        'BEGIN { printf "%.3f, %.3f, %.3f", r/255, g/255, b/255 }'
}

# Set "key = value" in a Godot .tres, appending it when missing
godot_set() {
    local file="$1" key="$2" val="$3"
    if grep -q "^${key} = " "$file"; then
        sed -i "s|^${key} = .*|${key} = ${val}|" "$file"
    else
        printf '%s = %s\n' "$key" "$val" >> "$file"
    fi
}

apply_godot() {
    local theme="$1"
    local cfg="$HOME/.var/app/org.godotengine.Godot/config/godot"
    local tet="$GENERATED_DIR/$theme/godot.tet" palette="$PALETTES_DIR/$theme.json"
    [[ -d "$cfg" ]] || { report_skip "godot (not set up)"; return; }
    [[ -f "$tet" ]] || { report_skip "godot (no theme file)"; return; }
    mkdir -p "$cfg/text_editor_themes"
    cp "$tet" "$cfg/text_editor_themes/Palette.tet"
    # Godot rewrites editor settings on exit; only edit them while it's closed
    if flatpak ps --columns=application 2>/dev/null | grep -qx 'org.godotengine.Godot'; then
        report_skip "godot (running; script theme updated, restart and re-run for the UI colors)"
        return
    fi
    local settings
    settings=$(ls -1 "$cfg"/editor_settings-*.tres 2>/dev/null | sort -V | tail -1)
    [[ -n "$settings" ]] || { report_skip "godot (no editor settings yet)"; return; }
    local base accent mode
    base=$(resolve_color "base" "$palette")
    accent=$(resolve_color "accent" "$palette")
    mode=dark; [[ $(hex_luminance "$base") -gt $LUMINANCE_THRESHOLD ]] && mode=light
    godot_set "$settings" "text_editor/theme/color_theme" '"Palette"'
    godot_set "$settings" "interface/theme/base_color" "Color($(hex_to_godot "$base"), 1)"
    godot_set "$settings" "interface/theme/accent_color" "Color($(hex_to_godot "$accent"), 1)"
    # Catppuccin's recommended values: contrast 0.2 / icon saturation 0.6 for dark
    if [[ "$mode" == dark ]]; then
        godot_set "$settings" "interface/theme/contrast" "0.2"
        godot_set "$settings" "interface/theme/icon_saturation" "0.6"
    else
        godot_set "$settings" "interface/theme/contrast" "0.06"
        godot_set "$settings" "interface/theme/icon_saturation" "1.0"
    fi
    report_ok "godot ($(basename "$settings"))"
}

# Jellyfin: upstream's hosted theme.css for layout + palette vars inlined, in
# the server's branding.xml CustomCss (so every client gets it, not just here)
apply_jellyfin() {
    local theme="$1"
    local cfg="${JELLYFIN_CONFIG_DIR:-$HOME/.config/jellyfin}"
    local css="$GENERATED_DIR/$theme/jellyfin-colors.css"
    [[ -d "$cfg" ]] || { report_skip "jellyfin (no config dir)"; return; }
    [[ -f "$css" ]] || { report_skip "jellyfin (no theme file)"; return; }
    python3 - "$cfg/branding.xml" "$css" <<'PY'
import sys, xml.etree.ElementTree as ET
from pathlib import Path
path, css = Path(sys.argv[1]), Path(sys.argv[2]).read_text()
custom = "@import url('https://jellyfin.catppuccin.com/theme.css');\n" + css
if path.exists():
    tree = ET.parse(path); root = tree.getroot()
else:
    root = ET.Element("BrandingOptions"); tree = ET.ElementTree(root)
node = root.find("CustomCss")
if node is None:
    node = ET.SubElement(root, "CustomCss")
node.text = custom
ET.indent(tree)
tree.write(path, encoding="utf-8", xml_declaration=True)
PY
    report_ok "jellyfin (restart the server to apply)"
}

# OBS: a "Palette" variant of the catppuccin theme (base Catppuccin.obt stays upstream)
apply_obs() {
    local theme="$1"
    local cfg="$HOME/.config/obs-studio" src="$GENERATED_DIR/$theme/obs-palette.ovt"
    [[ -d "$cfg/themes" ]] || { report_skip "obs (no themes dir)"; return; }
    [[ -f "$src" ]] || { report_skip "obs (no theme file)"; return; }
    cp "$src" "$cfg/themes/Catppuccin_Palette.ovt"
    # OBS writes user.ini on exit, so only switch the selection while it's closed
    if pgrep -x obs >/dev/null; then
        report_skip "obs (running; restart it, then pick Palette in Settings > Appearance)"
        return
    fi
    [[ -f "$cfg/user.ini" ]] && sed -i 's/^Theme=.*/Theme=com.obsproject.Catppuccin.Palette/' "$cfg/user.ini"
    report_ok "obs"
}

apply_stylus() {
    local theme="$1"
    local theme_dir="$GENERATED_DIR/$theme"
    local stylus_dir="$theme_dir/stylus"

    [[ ! -d "$stylus_dir" ]] && { report_skip "stylus (no styles)"; return; }

    # Copy to current for easy access, incl. the single-file importable bundle
    if copy_to_current "$theme" "stylus"; then
        copy_to_current "$theme" "stylus-bundle.json" >/dev/null 2>&1
        # Palette-agnostic userscripts ride the same local server
        cp "$THEMES_DIR"/userscripts/*.user.js "$CURRENT_DIR/stylus/" 2>/dev/null
        report_ok "stylus (served on 127.0.0.1:$STYLUS_PORT; Stylus picks it up on its next update check)"
    else
        report_skip "stylus"
    fi
}

