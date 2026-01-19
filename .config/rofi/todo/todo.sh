#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Hyprlauncher Todo Manager
# ══════════════════════════════════════════════════════════════════════════════
todo_file="${XDG_DATA_HOME:-$HOME/.local/share}/todo.txt"

touch "$todo_file"

# ══════════════════════════════════════════════════════════════════════════════
# Functions
# ══════════════════════════════════════════════════════════════════════════════

get_todos() {
    local line_num=1
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "x "* ]]; then
            echo "  $line_num: ${line#x }"
        elif [[ -n "$line" ]]; then
            echo "  $line_num: $line"
        fi
        ((line_num++))
    done < "$todo_file"
}

add_todo() {
    local task
    task=$(zenity --entry --title="New Task" --text="Enter task:" 2>/dev/null)
    [[ -n "$task" ]] && echo "$task" >> "$todo_file"
}

toggle_todo() {
    local line_num="$1"
    local line
    line=$(sed -n "${line_num}p" "$todo_file")

    if [[ "$line" == "x "* ]]; then
        # Uncomplete
        sed -i "${line_num}s/^x //" "$todo_file"
    else
        # Complete
        sed -i "${line_num}s/^/x /" "$todo_file"
    fi
}

delete_todo() {
    local line_num="$1"
    sed -i "${line_num}d" "$todo_file"
}

todo_actions() {
    local item="$1"
    local line_num="${item%%:*}"
    line_num="${line_num##* }"

    local action
    action=$(echo -e "󰄬  Toggle Complete\n  Delete\n  Back" | hyprlauncher -m)

    case "$action" in
        *"Toggle"*) toggle_todo "$line_num" ;;
        *"Delete")  delete_todo "$line_num" ;;
    esac
}

clear_completed() {
    sed -i '/^x /d' "$todo_file"
    notify-send "Todo" "Cleared completed tasks" 2>/dev/null
}

# ══════════════════════════════════════════════════════════════════════════════
# Main Menu
# ══════════════════════════════════════════════════════════════════════════════

main_menu() {
    local todos
    todos=$(get_todos)

    local options="  Add Task\n󰃢  Clear Completed"
    [[ -n "$todos" ]] && options="$options\n$todos"

    echo -e "$options" | hyprlauncher -m
}

while true; do
    chosen=$(main_menu)

    case "$chosen" in
        *"Add Task")        add_todo ;;
        *"Clear Completed") clear_completed ;;
        "")                 exit 0 ;;
        *)                  todo_actions "$chosen" ;;
    esac
done
