#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Rofi Wallpaper Picker
# Requires: awww (awww-daemon)
# ══════════════════════════════════════════════════════════════════════════════

theme="$HOME/.config/rofi/wallpaper/style.rasi"

# Ensure XDG directories are set
[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs

wallpaper_dir="${XDG_PICTURES_DIR:-$HOME/Documents/Pictures}/Backgrounds"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-thumbs"

mkdir -p "$cache_dir"

# ══════════════════════════════════════════════════════════════════════════════
# Functions
# ══════════════════════════════════════════════════════════════════════════════

generate_thumbs() {
    # Requires ImageMagick for thumbnail generation
    local magick_cmd
    if command -v magick &>/dev/null; then
        magick_cmd="magick"
    elif command -v convert &>/dev/null; then
        magick_cmd="convert"
    else
        return
    fi

    shopt -s nullglob
    for img in "$wallpaper_dir"/*.{jpg,jpeg,png,webp,gif}; do
        [[ -f "$img" ]] || continue
        local name=$(basename "$img")
        local thumb="$cache_dir/${name%.*}.png"
        if [[ ! -f "$thumb" ]]; then
            # For GIFs, extract first frame with [0]
            if [[ "$img" == *.gif ]]; then
                $magick_cmd "${img}[0]" -resize 200x200^ -gravity center -extent 200x200 "$thumb" 2>/dev/null &
            else
                $magick_cmd "$img" -resize 200x200^ -gravity center -extent 200x200 "$thumb" 2>/dev/null &
            fi
        fi
    done
    shopt -u nullglob
    wait
}

get_wallpapers() {
    shopt -s nullglob
    for img in "$wallpaper_dir"/*.{jpg,jpeg,png,webp,gif}; do
        [[ -f "$img" ]] || continue
        local name=$(basename "$img")
        local thumb="$cache_dir/${name%.*}.png"
        if [[ -f "$thumb" ]]; then
            echo -en "$name\x00icon\x1f$thumb\n"
        else
            echo "$name"
        fi
    done
    shopt -u nullglob
}

set_wallpaper() {
    local wallpaper="$1"
    local full_path="$wallpaper_dir/$wallpaper"

    # awww handles both static images and animated GIFs. It owns the background
    # layer, so make sure hyprpaper isn't also running.
    pkill -x hyprpaper 2>/dev/null

    if ! pgrep -x awww-daemon &>/dev/null; then
        awww-daemon &
        for _ in $(seq 1 50); do
            awww query &>/dev/null && break
            sleep 0.2
        done
    fi

    if ! awww img "$full_path" \
        --transition-type grow \
        --transition-pos center \
        --transition-duration 1 \
        --transition-fps 60; then
        notify-send "Wallpaper" "awww failed to set wallpaper" -u critical 2>/dev/null
        return 1
    fi

    # Save current wallpaper
    ln -sf "$full_path" "${XDG_CACHE_HOME:-$HOME/.cache}/current_wallpaper"
    notify-send "Wallpaper" "Set to $wallpaper" 2>/dev/null
}

random_wallpaper() {
    local wallpaper
    wallpaper=$(find "$wallpaper_dir" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.gif" \) | shuf -n 1)
    [[ -n "$wallpaper" ]] && set_wallpaper "$(basename "$wallpaper")"
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

# Generate thumbnails in background
generate_thumbs &

chosen=$(
    {
        echo -e "󰒟  Random\n󰉋  Open Folder"
        get_wallpapers
    } | rofi -dmenu -i -p "  Wallpaper" -theme "$theme" -show-icons
)

case "$chosen" in
    *"Random")      random_wallpaper ;;
    *"Open Folder") xdg-open "$wallpaper_dir" ;;
    "")             exit 0 ;;
    *)              set_wallpaper "$chosen" ;;
esac
