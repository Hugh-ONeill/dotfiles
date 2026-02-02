#!/usr/bin/env bash
# vim:ft=bash

DIR="$(dirname "$0")"
ROFI="rofi -dmenu -i -p Notes -theme ${DIR}/style.rasi"
# ══════════════════════════════════════════════════════════════════════════════
# Rofi Notes Manager
# ══════════════════════════════════════════════════════════════════════════════
notes_dir="${XDG_DATA_HOME:-$HOME/.local/share}/notes"
editor="${EDITOR:-nvim}"

# Use terminal for console editors
case "$editor" in
    vim|nvim|nano|vi|emacs) editor="kitty -e $editor" ;;
esac

mkdir -p "$notes_dir"

# ══════════════════════════════════════════════════════════════════════════════
# Functions
# ══════════════════════════════════════════════════════════════════════════════

get_notes() {
    find "$notes_dir" -name "*.md" -type f -printf "%f\n" | sed 's/\.md$//' | sort
}

new_note() {
    local title
    title=$(zenity --entry --title="New Note" --text="Enter note title:" 2>/dev/null)
    [[ -z "$title" ]] && return

    local filename="${title,,}"
    filename="${filename// /_}.md"
    local filepath="$notes_dir/$filename"

    # Create with frontmatter
    cat > "$filepath" << EOF
---
title: $title
date: $(date +"%Y-%m-%d %H:%M")
---

# $title

EOF

    $editor "$filepath"
}

edit_note() {
    local note="$1"
    $editor "$notes_dir/${note}.md"
}

delete_note() {
    local note="$1"
    local confirm
    confirm=$(echo -e "Yes\nNo" | $ROFI)
    [[ "$confirm" == "Yes" ]] && rm -f "$notes_dir/${note}.md"
}

note_actions() {
    local note="$1"
    local action
    action=$(echo -e "  Edit\n  Delete\n  Back" | $ROFI)

    case "$action" in
        *"Edit")   edit_note "$note" ;;
        *"Delete") delete_note "$note" ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════════════
# Main Menu
# ══════════════════════════════════════════════════════════════════════════════

main_menu() {
    local notes
    notes=$(get_notes)

    local options="󰎞  New Note"
    [[ -n "$notes" ]] && options="$options\n$notes"

    echo -e "$options" | $ROFI
}

chosen=$(main_menu)

case "$chosen" in
    *"New Note") new_note ;;
    "")          exit 0 ;;
    *)           note_actions "$chosen" ;;
esac
