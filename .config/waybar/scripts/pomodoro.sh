#!/bin/bash

# Pomodoro Timer Script with Notifications
# State directory
STATE_DIR=~/.local/state/pomodoro
STATE_FILE="$STATE_DIR/state"
NOTIFIED_FILE="$STATE_DIR/notified"
mkdir -p "$STATE_DIR"

# Timer durations in seconds
WORK_DURATION=$((25 * 60))     # 25 minutes
SHORT_BREAK=$((5 * 60))        # 5 minutes
LONG_BREAK=$((15 * 60))        # 15 minutes
POMODOROS_UNTIL_LONG=4         # Long break after 4 pomodoros

# Icon paths
ICON_DIR=~/.config/dunst/icons
ICON_WORK="$ICON_DIR/POMODORO_TICKING.svg"
ICON_DONE="$ICON_DIR/POMODORO_DONE.svg"
ICON_SHORT_BREAK="$ICON_DIR/SHORT_PAUSE.svg"
ICON_LONG_BREAK="$ICON_DIR/LONG_PAUSE.svg"
ICON_AWAY="$ICON_DIR/AWAY.svg"
ICON_ESTIMATED="$ICON_DIR/POMODORO_ESTIMATED.svg"
ICON_ALERT="$ICON_DIR/bell-badge.svg"

# Initialize state file if it doesn't exist
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" <<EOF
status=idle
start_time=0
current_duration=0
pomodoro_count=0
session_type=work
paused_remaining=0
last_active=$(date +%Y-%m-%d)
EOF
    fi
    # Clear notified file on init
    [[ ! -f "$NOTIFIED_FILE" ]] && echo "" > "$NOTIFIED_FILE"
}

# Reset stale state (from previous day)
check_stale() {
    local today=$(date +%Y-%m-%d)
    if [[ "$last_active" != "$today" ]]; then
        status=idle
        start_time=0
        current_duration=0
        pomodoro_count=0
        paused_remaining=0
        last_active=$today
        save_state
        clear_notified
    fi
}

# Load state
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
    fi
}

# Save state
save_state() {
    cat > "$STATE_FILE" <<EOF
status=$status
start_time=$start_time
current_duration=$current_duration
pomodoro_count=$pomodoro_count
session_type=$session_type
paused_remaining=$paused_remaining
last_active=$(date +%Y-%m-%d)
EOF
}

# Clear notification tracking (called when starting new session)
clear_notified() {
    echo "" > "$NOTIFIED_FILE"
}

# Check if we already sent a notification
was_notified() {
    grep -q "$1" "$NOTIFIED_FILE" 2>/dev/null
}

# Mark notification as sent
mark_notified() {
    echo "$1" >> "$NOTIFIED_FILE"
}

# Send notification with sound
notify() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    local icon="${4:-}"

    if [[ -n "$icon" && -f "$icon" ]]; then
        notify-send -u "$urgency" -i "$icon" -a "Pomodoro" "$title" "$message"
    else
        notify-send -u "$urgency" -a "Pomodoro" "$title" "$message"
    fi

    # Optional: Play a sound (uncomment if you have a sound file)
    # paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
}

# Start work session
start_work() {
    status="work"
    session_type="work"
    start_time=$(date +%s)
    current_duration=$WORK_DURATION
    paused_remaining=0
    clear_notified
    save_state
    notify "Work Session Started" "$((WORK_DURATION / 60)) minutes" "normal" "$ICON_WORK"
}

# Start break session
start_break() {
    if ((pomodoro_count % POMODOROS_UNTIL_LONG == 0 && pomodoro_count > 0)); then
        # Long break
        status="long_break"
        session_type="long_break"
        current_duration=$LONG_BREAK
        notify "Long Break" "$((LONG_BREAK / 60)) minutes" "normal" "$ICON_LONG_BREAK"
    else
        # Short break
        status="short_break"
        session_type="short_break"
        current_duration=$SHORT_BREAK
        notify "Short Break" "$((SHORT_BREAK / 60)) minutes" "normal" "$ICON_SHORT_BREAK"
    fi
    start_time=$(date +%s)
    paused_remaining=0
    clear_notified
    save_state
}

# Close current session
close_session() {
    # Use session_type if paused, otherwise use status
    local current="${status}"
    [[ "$status" == "paused" ]] && current="$session_type"

    if [[ "$current" == "short_break" || "$current" == "long_break" ]]; then
        start_work
    elif [[ "$current" == "work" ]]; then
        ((pomodoro_count++))
        save_state
        notify "Work Session Closed" "Total: $pomodoro_count" "normal" "$ICON_DONE"
        start_break
    fi
}

# Pause timer
pause_timer() {
    if [[ "$status" == "work" || "$status" == "short_break" || "$status" == "long_break" ]]; then
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        paused_remaining=$((current_duration - elapsed))
        status="paused"
        save_state
        notify "Timer Paused" "$(format_time $paused_remaining) remaining" "low" "$ICON_AWAY"
    fi
}

# Resume timer
resume_timer() {
    if [[ "$status" == "paused" ]]; then
        status="$session_type"
        start_time=$(date +%s)
        current_duration=$paused_remaining
        paused_remaining=0
        save_state
        # Use appropriate icon based on session type
        local icon="$ICON_WORK"
        [[ "$session_type" == "short_break" ]] && icon="$ICON_SHORT_BREAK"
        [[ "$session_type" == "long_break" ]] && icon="$ICON_LONG_BREAK"
        notify "Timer Resumed" "$(format_time $current_duration) remaining" "low" "$icon"
    fi
}

# Stop timer (silent version for internal use)
stop_timer_silent() {
    status="idle"
    start_time=0
    current_duration=0
    paused_remaining=0
    save_state
}

# Reset timer (stop without resetting count)
reset_timer() {
    stop_timer_silent
    notify "Timer Reset" "" "low" "$ICON_ESTIMATED"
}

# Get remaining time
get_remaining() {
    local now=$(date +%s)
    local elapsed=$((now - start_time))
    local remaining=$((current_duration - elapsed))

    # Check if timer expired
    if ((remaining <= 0)); then
        if [[ "$status" == "work" ]]; then
            # Work session completed
            ((pomodoro_count++))
            save_state
            notify "Work Session Complete" "Total: $pomodoro_count" "critical" "$ICON_DONE"
            start_break
            get_remaining
            return
        elif [[ "$status" == "short_break" ]] || [[ "$status" == "long_break" ]]; then
            # Break completed - automatically start next work session
            notify "Break Complete" "Starting next work session" "critical" "$ICON_DONE"
            start_work
            get_remaining
            return
        fi
    else
        # Send interim notifications (work sessions only)
        if [[ "$status" == "work" ]]; then
            if ((remaining <= 600 && remaining > 595)) && ! was_notified "10min"; then
                mark_notified "10min"
                notify "10 minutes remaining" "" "low" "$ICON_WORK"
            elif ((remaining <= 300 && remaining > 295)) && ! was_notified "5min"; then
                mark_notified "5min"
                notify "5 minutes remaining" "" "low" "$ICON_WORK"
            elif ((remaining <= 60 && remaining > 55)) && ! was_notified "1min"; then
                mark_notified "1min"
                notify "1 minute remaining" "" "normal" "$ICON_WORK"
            fi
        fi
    fi

    echo "$remaining"
}

# Format time as MM:SS
format_time() {
    local total_seconds=$1
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))
    printf "%02d:%02d" $minutes $seconds
}

# Get status icon (pomicons - nerd font)
get_status_icon() {
    case "$status" in
        "work")
            printf '\ue003'  # POMODORO_TICKING
            ;;
        "short_break")
            printf '\ue005'  # SHORT_PAUSE
            ;;
        "long_break")
            printf '\ue006'  # LONG_PAUSE
            ;;
        "paused")
            printf '\ue007'  # AWAY
            ;;
        "idle")
            printf '\ue002'  # POMODORO_ESTIMATED
            ;;
        *)
            printf '\ue003'  # POMODORO_TICKING
            ;;
    esac
}

# Handle commands
handle_command() {
    case "$1" in
        "start_work")
            start_work
            ;;
        "start_break")
            start_break
            ;;
        "reset")
            reset_timer
            ;;
        "pause")
            pause_timer
            ;;
        "resume")
            resume_timer
            ;;
        "close")
            close_session
            ;;
        "toggle")
            if [[ "$status" == "idle" ]]; then
                start_work
            elif [[ "$status" == "paused" ]]; then
                resume_timer
            else
                pause_timer
            fi
            ;;
    esac
}

# Main logic
init_state
load_state
check_stale

# Handle command line arguments
if [[ -n "$1" ]]; then
    handle_command "$1"
    load_state
fi

# Calculate display
if [[ "$status" == "idle" ]]; then
    icon=$(get_status_icon)
    text="$icon $pomodoro_count"
    tooltip="Pomodoro Timer (Idle)\nClick to start"
    class="idle"
elif [[ "$status" == "paused" ]]; then
    icon=$(get_status_icon)
    time_text=$(format_time $paused_remaining)
    text="$icon $time_text"
    tooltip="Paused ($session_type)\n$time_text remaining\nPomodoros: $pomodoro_count"
    class="paused"
else
    remaining=$(get_remaining)
    # Reload state in case it changed
    load_state

    icon=$(get_status_icon)
    time_text=$(format_time $remaining)
    text="$icon $time_text"

    # Set warning class when under 5 minutes
    if ((remaining < 300)); then
        class="warning"
    else
        class="$status"
    fi

    case "$status" in
        "work")
            tooltip="Work Session\n$time_text remaining\nPomodoros: $pomodoro_count"
            ;;
        "short_break")
            tooltip="Short Break\n$time_text remaining\nPomodoros: $pomodoro_count"
            ;;
        "long_break")
            tooltip="Long Break\n$time_text remaining\nPomodoros: $pomodoro_count"
            ;;
        *)
            tooltip="Pomodoro Timer\nPomodoros: $pomodoro_count"
            ;;
    esac
fi

echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\", \"class\": \"$class\"}"
