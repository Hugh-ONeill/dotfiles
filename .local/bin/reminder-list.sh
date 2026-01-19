#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Reminder List/Delete
# View and manage reminders via rofi
# ══════════════════════════════════════════════════════════════════════════════

REMINDERS_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/reminders.txt"
theme="$HOME/.config/rofi/calendar/input.rasi"

[[ ! -f "$REMINDERS_FILE" ]] && touch "$REMINDERS_FILE"

show_reminders() {
    if [[ ! -s "$REMINDERS_FILE" ]]; then
        echo "No reminders"
        return
    fi

    while IFS='|' read -r datetime message; do
        [[ -z "$datetime" || "$datetime" == \#* ]] && continue
        echo "$datetime  $message"
    done < "$REMINDERS_FILE" | sort
}

main() {
    while true; do
        chosen=$(show_reminders | rofi -dmenu -i -p "󰃭  Reminders" -theme "$theme")

        [[ -z "$chosen" ]] && exit 0
        [[ "$chosen" == "No reminders" ]] && exit 0

        # Extract datetime from selection
        datetime=$(echo "$chosen" | awk '{print $1, $2}')
        message="${chosen#*  }"
        message="${message#* }"

        # Confirm deletion
        action=$(echo -e "󰆴  Delete\n  Back" | rofi -dmenu -p "󰃭  $datetime" -theme "$theme")

        case "$action" in
            *"Delete")
                # Escape special chars for sed
                escaped_datetime=$(printf '%s\n' "$datetime" | sed 's/[[\.*^$()+?{|/]/\\&/g')
                escaped_message=$(printf '%s\n' "$message" | sed 's/[[\.*^$()+?{|/]/\\&/g')
                sed -i "/${escaped_datetime}|${escaped_message}/d" "$REMINDERS_FILE"
                notify-send "󰃭 Reminder Deleted" "$datetime: $message" 2>/dev/null
                ;;
            *)
                continue
                ;;
        esac
    done
}

main
