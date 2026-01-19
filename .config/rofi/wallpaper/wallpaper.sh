#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Rofi Wallpaper Picker
# Requires: swww, hyprpaper, or swaybg
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
    command -v convert &>/dev/null || return

    shopt -s nullglob
    for img in "$wallpaper_dir"/*.{jpg,jpeg,png,webp}; do
        [[ -f "$img" ]] || continue
        local name=$(basename "$img")
        local thumb="$cache_dir/$name"
        [[ -f "$thumb" ]] || convert "$img" -resize 200x200^ -gravity center -extent 200x200 "$thumb" 2>/dev/null &
    done
    shopt -u nullglob
    wait
}

get_wallpapers() {
    shopt -s nullglob
    for img in "$wallpaper_dir"/*.{jpg,jpeg,png,webp}; do
        [[ -f "$img" ]] || continue
        local name=$(basename "$img")
        local thumb="$cache_dir/$name"
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

    # Try different wallpaper setters (check if daemon is running)
    if pgrep -x hyprpaper &>/dev/null; then
        hyprctl hyprpaper preload "$full_path"
        hyprctl hyprpaper wallpaper ",$full_path"
    elif pgrep -x swww-daemon &>/dev/null; then
        swww img "$full_path" \
            --transition-type grow \
            --transition-pos center \
            --transition-duration 1 \
            --transition-fps 60
    elif command -v swaybg &>/dev/null; then
        pkill swaybg
        swaybg -i "$full_path" -m fill &
    else
        notify-send "Wallpaper" "No wallpaper daemon running" -u critical
        return 1
    fi

    # Save current wallpaper
    ln -sf "$full_path" "$HOME/.current_wallpaper"
    notify-send "Wallpaper" "Set to $wallpaper" 2>/dev/null
}

random_wallpaper() {
    local wallpaper
    wallpaper=$(find "$wallpaper_dir" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | shuf -n 1)
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
