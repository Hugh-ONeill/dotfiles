#!/usr/bin/env bash
# Waybar recording indicator
# Usage: called by waybar custom module, signaled via RTMIN+8

PID_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/screenshot-recording.pid"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo '{"text": " REC", "class": "recording", "tooltip": "Recording in progress — click to stop"}'
else
    echo '{"text": "", "class": "", "tooltip": ""}'
fi
