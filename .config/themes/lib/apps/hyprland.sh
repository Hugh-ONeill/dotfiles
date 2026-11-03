#!/bin/bash
# Hyprland theme handler

# Re-export the cursor vars from the freshly applied colors.lua.
#
# Anything the theme script spawns (waybar) is a child of that script, so it
# inherits the invoking SHELL's environment -- not the compositor's. Hyprland's
# `env =` lines only reach processes the compositor itself launches, so without
# this waybar comes back carrying whatever cursor theme the terminal was
# started with, and the cursor changes as you move onto the bar.
export_cursor_env() {
    local colors="$HOME/.config/hypr/appearance/colors.lua"
    [[ -f "$colors" ]] || return 0

    local ctheme csize
    ctheme=$(sed -n 's/^M\.cursor_theme *= *"\([^"]*\)".*/\1/p' "$colors")
    csize=$(sed -n 's/^M\.cursor_size *= *\([0-9]*\).*/\1/p' "$colors")
    [[ -n "$ctheme" ]] || return 0

    export XCURSOR_THEME="$ctheme"  HYPRCURSOR_THEME="$ctheme"
    export XCURSOR_SIZE="${csize:-24}"  HYPRCURSOR_SIZE="${csize:-24}"
}

apply_hyprland() {
    local theme="$1"
    if copy_to_current "$theme" "hypr-colors.lua"; then
        # The reload re-runs the Lua config; a theme that declares M.hyprbars
        # loads the plugin from there, and one that doesn't drops it again, so
        # no plugin load/unload is needed here.
        hyprctl reload &>/dev/null || true
        # Set cursor theme
        if [[ -x "$HOME/.config/hypr/scripts/set-cursor.sh" ]]; then
            "$HOME/.config/hypr/scripts/set-cursor.sh" &>/dev/null
        fi
        report_ok "hyprland"
    else
        report_skip "hyprland (no theme file)"
    fi
}

apply_hyprlock()    { apply_simple "$1" "hyprlock-colors.conf" "hyprlock"; }
apply_hyprtoolkit() { apply_simple "$1" "hyprtoolkit.conf"     "hyprtoolkit"; }

