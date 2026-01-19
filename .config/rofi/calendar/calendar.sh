#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Rofi Calendar
# ══════════════════════════════════════════════════════════════════════════════

theme="$HOME/.config/rofi/calendar/style.rasi"
input_theme="$HOME/.config/rofi/calendar/input.rasi"

# Current date info
current_month=$(date +%-m)
current_year=$(date +%Y)
current_day=$(date +%-d)

# Navigation state
month=${1:-$current_month}
year=${2:-$current_year}

# ══════════════════════════════════════════════════════════════════════════════
# Functions
# ══════════════════════════════════════════════════════════════════════════════

get_month_name() {
    date -d "$year-$month-01" +"%B %Y"
}

get_days_in_month() {
    cal "$month" "$year" | awk 'NF {DAYS = $NF}; END {print DAYS}'
}

get_first_day_offset() {
    # Get day of week for first of month (1=Monday, 7=Sunday)
    date -d "$year-$month-01" +%u
}

generate_calendar() {
    local days_in_month=$(get_days_in_month)
    local first_day=$(get_first_day_offset)

    # Navigation row (7 cells: arrow, empty x2, reminders, empty x2, arrow)
    echo "◀"
    echo ""
    echo ""
    echo "󰃭"
    echo ""
    echo ""
    echo "▶"

    # Weekday headers
    echo "Mo"
    echo "Tu"
    echo "We"
    echo "Th"
    echo "Fr"
    echo "Sa"
    echo "Su"

    # Empty cells before first day
    for ((i = 1; i < first_day; i++)); do
        echo ""
    done

    # Day numbers
    for ((day = 1; day <= days_in_month; day++)); do
        echo "$day"
    done
}

calendar_menu() {
    local month_name=$(get_month_name)
    local first_day=$(get_first_day_offset)

    # Calculate index for highlighting current day
    local highlight=""
    local selected=""
    if [[ "$month" -eq "$current_month" && "$year" -eq "$current_year" ]]; then
        # 7 nav cells + 7 header cells + offset + day
        local index=$((14 + first_day - 1 + current_day - 1))
        highlight="-a $index"
        selected="-selected-row $index"
    fi

    generate_calendar | rofi -dmenu \
        -p "$month_name" \
        -theme "$theme" \
        $highlight $selected
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

chosen=$(calendar_menu)

case "$chosen" in
    "◀")
        # Previous month
        ((month--))
        if [[ $month -lt 1 ]]; then
            month=12
            ((year--))
        fi
        exec "$0" "$month" "$year"
        ;;
    "▶")
        # Next month
        ((month++))
        if [[ $month -gt 12 ]]; then
            month=1
            ((year++))
        fi
        exec "$0" "$month" "$year"
        ;;
    "󰃭")
        # View/manage reminders
        ~/.local/bin/reminder-list.sh
        exec "$0" "$month" "$year"
        ;;
    "Mo"|"Tu"|"We"|"Th"|"Fr"|"Sa"|"Su"|"")
        exit 0
        ;;
    *)
        if [[ "$chosen" =~ ^[0-9]+$ ]]; then
            selected_date=$(date -d "$year-$month-$chosen" +"%Y-%m-%d" 2>/dev/null)
            display_date=$(date -d "$selected_date" +"%A, %B %-d, %Y" 2>/dev/null)
            default_time=$(date +%H:%M)

            if [[ -n "$selected_date" ]]; then
                # Prompt for reminder message
                message=$(rofi -dmenu -p "󰃭  $display_date" -theme "$input_theme")
                [[ -z "$message" ]] && exit 0

                # Prompt for time with current time as default
                reminder_time=$(echo "$default_time" | rofi -dmenu -p "󰅐  Time" -theme "$input_theme")
                [[ -z "$reminder_time" ]] && reminder_time="$default_time"

                ~/.local/bin/reminder-add.sh "$selected_date" "$reminder_time" "$message"
                notify-send "󰃭 Reminder Set" "$display_date at $reminder_time: $message" 2>/dev/null
            fi
        fi
        ;;
esac
