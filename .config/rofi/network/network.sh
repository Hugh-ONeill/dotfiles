#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Hyprlauncher Network Manager
# Requires: NetworkManager (nmcli)
# ══════════════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ══════════════════════════════════════════════════════════════════════════════

notify() {
    notify-send "Network" "$1" 2>/dev/null
}

wifi_status() {
    nmcli radio wifi
}

get_active_connection() {
    nmcli -t -f NAME,TYPE,DEVICE connection show --active | grep wireless | cut -d: -f1 | head -1
}

get_wifi_list() {
    nmcli -t -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | while IFS=: read -r ssid signal security; do
        [[ -z "$ssid" ]] && continue

        # Signal icon
        if [[ "$signal" -ge 75 ]]; then
            icon="󰤨"
        elif [[ "$signal" -ge 50 ]]; then
            icon="󰤥"
        elif [[ "$signal" -ge 25 ]]; then
            icon="󰤢"
        else
            icon="󰤟"
        fi

        # Lock icon for secured networks
        [[ "$security" != "" && "$security" != "--" ]] && icon="$icon 󰌾"

        printf "%s  %s\n" "$icon" "$ssid"
    done | sort -u
}

get_saved_connections() {
    nmcli -t -f NAME,TYPE connection show | grep wireless | cut -d: -f1
}

# ══════════════════════════════════════════════════════════════════════════════
# Actions
# ══════════════════════════════════════════════════════════════════════════════

toggle_wifi() {
    if [[ $(wifi_status) == "enabled" ]]; then
        nmcli radio wifi off
        notify "WiFi disabled"
    else
        nmcli radio wifi on
        notify "WiFi enabled"
    fi
}

connect_wifi() {
    local ssid="$1"

    # Check if already saved
    if nmcli -t -f NAME connection show | grep -qF "$ssid"; then
        nmcli connection up "$ssid" && notify "Connected to $ssid" || notify "Failed to connect"
    else
        # Need password - use zenity for secure input
        local pass
        pass=$(zenity --password --title="WiFi Password" --text="Enter password for $ssid" 2>/dev/null)
        [[ -z "$pass" ]] && return

        nmcli device wifi connect "$ssid" password "$pass" && \
            notify "Connected to $ssid" || notify "Failed to connect"
    fi
}

disconnect_wifi() {
    local connection
    connection=$(get_active_connection)
    [[ -n "$connection" ]] && nmcli connection down "$connection" && notify "Disconnected"
}

forget_network() {
    local saved
    saved=$(get_saved_connections | hyprlauncher -m)
    [[ -n "$saved" ]] && nmcli connection delete "$saved" && notify "Forgot $saved"
}

# ══════════════════════════════════════════════════════════════════════════════
# Main Menu
# ══════════════════════════════════════════════════════════════════════════════

main_menu() {
    local status=$(wifi_status)
    local active=$(get_active_connection)

    local toggle_icon="󰤮"
    local toggle_text="Turn On"
    [[ "$status" == "enabled" ]] && toggle_icon="󰤨" && toggle_text="Turn Off"

    {
        echo "$toggle_icon  WiFi $toggle_text"
        if [[ "$status" == "enabled" ]]; then
            [[ -n "$active" ]] && echo "󰤭  Disconnect ($active)"
            echo "󰑓  Rescan"
            echo "󰆴  Forget Network"
            echo "─────────────"
            get_wifi_list
        fi
    } | hyprlauncher -m
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

chosen=$(main_menu)

case "$chosen" in
    *"Turn On"|*"Turn Off") toggle_wifi ;;
    *"Disconnect"*)         disconnect_wifi ;;
    *"Rescan")              nmcli device wifi rescan; exec "$0" ;;
    *"Forget"*)             forget_network ;;
    "─────────────"|"")     exit 0 ;;
    *)
        # Extract SSID - remove icon prefix
        ssid=$(echo "$chosen" | sed 's/^[^a-zA-Z0-9]*//' | sed 's/^  //')
        [[ -n "$ssid" ]] && connect_wifi "$ssid"
        ;;
esac
