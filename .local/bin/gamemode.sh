#!/bin/bash

THEMES_DIR="$HOME/.config/themes"
CURRENT_THEME=$(cat "$THEMES_DIR/.current" 2>/dev/null)
HYPRBARS_SO="/var/cache/hyprpm/wiz/hyprland-plugins/hyprbars.so"

if [ -f ~/.cache/gamemode ]; then
  hyprctl reload
  # Reload hyprbars if theme uses it
  if [[ -n "$CURRENT_THEME" ]]; then
    decoration=$(jq -r '.style.decoration // "none"' "$THEMES_DIR/palettes/$CURRENT_THEME.json" 2>/dev/null)
    if [[ "$decoration" == "hyprbars" && -f "$HYPRBARS_SO" ]]; then
      hyprctl plugin load "$HYPRBARS_SO" &>/dev/null
    fi
  fi
  rm ~/.cache/gamemode
  notify-send -a "gamemode.sh" -r 3 -t 800 "Gamemode: deactivated" "animations and blur enabled"
else
  hyprctl -q --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword decoration:dim_inactive 0;\
        keyword decoration:screen_shader [[EMPTY]];\
        keyword decoration:active_opacity 1;\
        keyword decoration:inactive_opacity 1;\
        keyword decoration:fullscreen_opacity 1;\
        keyword decoration:rounding 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword render:direct_scanout 1;\
        keyword layerrule noanim,waybar;\
        keyword layerrule noanim,swaync-notification-window;\
        keyword layerrule noanim,awww-daemon;\
        keyword layerrule noanim,rofi
        "
  hyprctl 'keyword windowrulev2 opaque,class:(.*)'
  # Unload hyprbars plugin if loaded
  hyprctl plugin unload "$HYPRBARS_SO" &>/dev/null
  touch ~/.cache/gamemode
  notify-send -a "gamemode.sh" -r 3 -t 800 "Gamemode: activated" "animations, blur, shader disabled"
fi
