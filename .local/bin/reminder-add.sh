#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Add Reminder
# Usage: reminder-add.sh YYYY-MM-DD HH:MM "message"
# ══════════════════════════════════════════════════════════════════════════════

REMINDERS_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/reminders.txt"

date="$1"
time="$2"
message="$3"

if [[ -z "$date" || -z "$time" || -z "$message" ]]; then
    echo "Usage: reminder-add.sh YYYY-MM-DD HH:MM \"message\""
    exit 1
fi

# Validate date format
if ! date -d "$date" &>/dev/null; then
    echo "Invalid date: $date"
    exit 1
fi

# Validate time format
if ! [[ "$time" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
    echo "Invalid time: $time (use HH:MM)"
    exit 1
fi

# Add reminder
echo "${date} ${time}|${message}" >> "$REMINDERS_FILE"
echo "Reminder added for $date at $time: $message"
