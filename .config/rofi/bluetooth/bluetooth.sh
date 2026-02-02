#!/usr/bin/env bash
# vim:ft=bash

DIR="$(dirname "$0")"
ROFI="rofi -dmenu -i -p Bluetooth -theme ${DIR}/style.rasi"
# ══════════════════════════════════════════════════════════════════════════════
# Rofi Bluetooth Menu
# Requires: bluez-utils (bluetoothctl)
# ══════════════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ══════════════════════════════════════════════════════════════════════════════

power_status() {
    bluetoothctl show | grep -q "Powered: yes" && echo "on" || echo "off"
}

connected_devices() {
    bluetoothctl devices Connected | cut -d ' ' -f 3-
}

device_menu() {
    bluetoothctl devices | cut -d ' ' -f 2- | $ROFI
}

# ══════════════════════════════════════════════════════════════════════════════
# Main Menu
# ══════════════════════════════════════════════════════════════════════════════

main_menu() {
    local power=$(power_status)
    local connected=$(connected_devices)

    local toggle_icon="󰂲"
    local toggle_text="Turn On"
    [[ "$power" == "on" ]] && toggle_icon="󰂯" && toggle_text="Turn Off"

    local options="$toggle_icon  $toggle_text\n󰂰  Scan Devices\n󰂱  Paired Devices"
    [[ -n "$connected" ]] && options="$options\n󰂳  Disconnect ($connected)"

    echo -e "$options" | $ROFI
}

# ══════════════════════════════════════════════════════════════════════════════
# Device Actions
# ══════════════════════════════════════════════════════════════════════════════

device_actions() {
    local mac="$1"
    local name="$2"

    local is_connected=$(bluetoothctl info "$mac" | grep -q "Connected: yes" && echo "yes")
    local is_paired=$(bluetoothctl info "$mac" | grep -q "Paired: yes" && echo "yes")
    local is_trusted=$(bluetoothctl info "$mac" | grep -q "Trusted: yes" && echo "yes")

    local options=""
    [[ "$is_connected" == "yes" ]] && options="󰂳  Disconnect" || options="󰂱  Connect"
    [[ "$is_paired" == "yes" ]] && options="$options\n󰂲  Unpair" || options="$options\n󰂰  Pair"
    [[ "$is_trusted" == "yes" ]] && options="$options\n󰜺  Untrust" || options="$options\n󰄬  Trust"

    local action=$(echo -e "$options" | $ROFI)

    case "$action" in
        *"Connect")
            bluetoothctl connect "$mac" && \
                notify-send "Bluetooth" "Connected to $name" 2>/dev/null || \
                notify-send "Bluetooth" "Failed to connect to $name" 2>/dev/null
            ;;
        *"Disconnect")
            bluetoothctl disconnect "$mac" && \
                notify-send "Bluetooth" "Disconnected from $name" 2>/dev/null
            ;;
        *"Pair")
            bluetoothctl pair "$mac" && \
                notify-send "Bluetooth" "Paired with $name" 2>/dev/null || \
                notify-send "Bluetooth" "Failed to pair with $name" 2>/dev/null
            ;;
        *"Unpair")
            bluetoothctl remove "$mac" && \
                notify-send "Bluetooth" "Removed $name" 2>/dev/null
            ;;
        *"Trust")
            bluetoothctl trust "$mac" && \
                notify-send "Bluetooth" "Trusted $name" 2>/dev/null
            ;;
        *"Untrust")
            bluetoothctl untrust "$mac" && \
                notify-send "Bluetooth" "Untrusted $name" 2>/dev/null
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

chosen=$(main_menu)

case "$chosen" in
    *"Turn On")
        bluetoothctl power on
        notify-send "Bluetooth" "Powered on" 2>/dev/null
        ;;
    *"Turn Off")
        bluetoothctl power off
        notify-send "Bluetooth" "Powered off" 2>/dev/null
        ;;
    *"Scan"*)
        notify-send "Bluetooth" "Scanning for devices..." 2>/dev/null
        bluetoothctl --timeout 5 scan on &
        sleep 5
        device=$(device_menu)
        if [[ -n "$device" ]]; then
            mac=$(echo "$device" | cut -d ' ' -f 1)
            name=$(echo "$device" | cut -d ' ' -f 2-)
            device_actions "$mac" "$name"
        fi
        ;;
    *"Paired"*)
        device=$(bluetoothctl devices Paired | cut -d ' ' -f 2- | $ROFI)
        if [[ -n "$device" ]]; then
            mac=$(echo "$device" | cut -d ' ' -f 1)
            name=$(echo "$device" | cut -d ' ' -f 2-)
            device_actions "$mac" "$name"
        fi
        ;;
    *"Disconnect"*)
        mac=$(bluetoothctl devices Connected | head -1 | cut -d ' ' -f 2)
        [[ -n "$mac" ]] && bluetoothctl disconnect "$mac"
        ;;
esac
