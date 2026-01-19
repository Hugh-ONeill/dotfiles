#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Reminder Checker
# Checks for reminders matching today's date/time and shows notifications
# Format: YYYY-MM-DD HH:MM|message
# ══════════════════════════════════════════════════════════════════════════════

REMINDERS_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/reminders.txt"
SHOWN_FILE="${XDG_RUNTIME_DIR:-/tmp}/reminders-shown-$(date +%Y-%m-%d)"

[[ ! -f "$REMINDERS_FILE" ]] && exit 0

today=$(date +%Y-%m-%d)
now=$(date +%H:%M)
now_minutes=$(( 10#$(date +%H) * 60 + 10#$(date +%M) ))

while IFS='|' read -r datetime message; do
    [[ -z "$datetime" || "$datetime" == \#* ]] && continue

    # Parse date and time
    reminder_date="${datetime% *}"
    reminder_time="${datetime#* }"

    # Skip if not today
    [[ "$reminder_date" != "$today" ]] && continue

    # Convert reminder time to minutes
    reminder_hour="${reminder_time%:*}"
    reminder_min="${reminder_time#*:}"
    reminder_minutes=$(( 10#$reminder_hour * 60 + 10#$reminder_min ))

    # Show if current time >= reminder time (within the hour window)
    if [[ $now_minutes -ge $reminder_minutes ]]; then
        # Create hash of this reminder to track if shown
        hash=$(echo "$datetime|$message" | md5sum | cut -d' ' -f1)

        # Only show if not already shown today
        if ! grep -q "$hash" "$SHOWN_FILE" 2>/dev/null; then
            notify-send "󰃭 Reminder ($reminder_time)" "$message" -u normal
            echo "$hash" >> "$SHOWN_FILE"
        fi
    fi
done < "$REMINDERS_FILE"
