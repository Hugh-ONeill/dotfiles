#!/usr/bin/env bash
# vim:ft=bash

DIR="$(dirname "$0")"
ROFI="rofi -dmenu -i -p Power -theme ${DIR}/style.rasi"
# ══════════════════════════════════════════════════════════════════════════════
# Rofi Powermenu
# ══════════════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════════════
# Options
# ══════════════════════════════════════════════════════════════════════════════

shutdown='  Shutdown'
reboot='  Reboot'
lock='  Lock'
suspend='  Suspend'
logout='󰍃  Logout'

# ══════════════════════════════════════════════════════════════════════════════
# Confirmation
# ══════════════════════════════════════════════════════════════════════════════

confirm_exit() {
    echo -e "Yes\nNo" | $ROFI
}

# ══════════════════════════════════════════════════════════════════════════════
# Main Menu
# ══════════════════════════════════════════════════════════════════════════════

run_menu() {
    echo -e "$lock\n$suspend\n$logout\n$reboot\n$shutdown" | $ROFI
}

# ══════════════════════════════════════════════════════════════════════════════
# Actions
# ══════════════════════════════════════════════════════════════════════════════

chosen=$(run_menu)

case "$chosen" in
    "$shutdown")
        ans=$(confirm_exit)
        [[ "$ans" == "Yes" ]] && systemctl poweroff
        ;;
    "$reboot")
        ans=$(confirm_exit)
        [[ "$ans" == "Yes" ]] && systemctl reboot
        ;;
    "$lock")
        hyprlock
        ;;
    "$suspend")
        ans=$(confirm_exit)
        if [[ "$ans" == "Yes" ]]; then
            playerctl pause 2>/dev/null
            hyprlock &
            sleep 0.5
            systemctl suspend
        fi
        ;;
    "$logout")
        ans=$(confirm_exit)
        if [[ "$ans" == "Yes" ]]; then
            case "$XDG_CURRENT_DESKTOP" in
                Hyprland) hyprctl dispatch 'hl.dsp.exit()' ;;
                sway) swaymsg exit ;;
                i3) i3-msg exit ;;
                *) loginctl terminate-user "$USER" ;;
            esac
        fi
        ;;
esac
