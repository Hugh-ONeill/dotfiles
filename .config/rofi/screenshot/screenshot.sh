#!/usr/bin/env bash
# vim:ft=bash

DIR="$(dirname "$0")"
ROFI="rofi -dmenu -i -p Screenshot -theme ${DIR}/style.rasi"
# ══════════════════════════════════════════════════════════════════════════════
# Rofi Screenshot Menu
# Requires: hyprshot, tesseract (for OCR), obs-cli or obs (for recording)
# ══════════════════════════════════════════════════════════════════════════════

# Ensure XDG directories are set
[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs

screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$screenshot_dir"

# ══════════════════════════════════════════════════════════════════════════════
# Options
# ══════════════════════════════════════════════════════════════════════════════

area='󰆞  Area'
fullscreen='  Fullscreen'
window='  Window'
ocr='󱄽  OCR (copy text)'

# Check if OBS is recording
recording=false
if pgrep -x obs >/dev/null; then
    if command -v obs-cli &>/dev/null; then
        obs-cli recording status 2>/dev/null | grep -q "recording" && recording=true
    else
        # Fallback: check via dbus
        dbus-send --print-reply --dest=org.obs.Studio /org/obs/Studio \
            org.freedesktop.DBus.Properties.Get string:org.obs.Studio string:RecordingActive \
            2>/dev/null | grep -q "true" && recording=true
    fi
fi

if [[ "$recording" == true ]]; then
    record='  Stop Recording'
else
    record='  Start Recording'
fi

open='  Open folder'

# ══════════════════════════════════════════════════════════════════════════════
# Menu
# ══════════════════════════════════════════════════════════════════════════════

run_menu() {
    echo -e "$area\n$fullscreen\n$window\n$ocr\n$record\n$open" | $ROFI
}

# ══════════════════════════════════════════════════════════════════════════════
# Actions
# ══════════════════════════════════════════════════════════════════════════════

ocr_screenshot() {
    local tmpfile="/tmp/ocr_screenshot.png"

    hyprshot -m region -o /tmp -f ocr_screenshot.png --silent && \
    tesseract "$tmpfile" - 2>/dev/null | wl-copy && \
    notify-send "OCR" "Text copied to clipboard" 2>/dev/null

    rm -f "$tmpfile"
}

toggle_recording() {
    if ! pgrep -x obs >/dev/null; then
        notify-send "OBS" "Starting OBS..." 2>/dev/null
        obs --minimize-to-tray &
        sleep 2
    fi

    if [[ "$recording" == true ]]; then
        obs-cli recording stop 2>/dev/null || \
            dbus-send --dest=org.obs.Studio /org/obs/Studio org.obs.Studio.StopRecording 2>/dev/null
        notify-send "OBS" "Recording stopped" 2>/dev/null
    else
        obs-cli recording start 2>/dev/null || \
            dbus-send --dest=org.obs.Studio /org/obs/Studio org.obs.Studio.StartRecording 2>/dev/null
        notify-send "OBS" "Recording started" 2>/dev/null
    fi
}

chosen=$(run_menu)

case "$chosen" in
    "$area")
        sleep 0.2
        ~/.local/bin/screenshot region
        ;;
    "$fullscreen")
        sleep 0.2
        ~/.local/bin/screenshot output
        ;;
    "$window")
        sleep 0.2
        ~/.local/bin/screenshot window
        ;;
    "$ocr")
        sleep 0.2
        ocr_screenshot
        ;;
    "$record"|*"Recording"*)
        toggle_recording
        ;;
    "$open")
        xdg-open "$screenshot_dir"
        ;;
esac
