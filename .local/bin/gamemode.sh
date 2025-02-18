#!/bin/bash

if [ -f ~/.cache/gamemode ]; then
  hyprctl reload
  rm ~/.cache/gamemode
  notify-send -a "gamemode.sh" -r 3 -t 800 "Gamemode: deactivated" "animations and blur enabled"
else
  hyprctl -q --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:shadow:xray 1;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0 ;\
        keyword decoration:active_opacity 1 ;\
        keyword decoration:inactive_opacity 1 ;\
        keyword decoration:fullscreen_opacity 1 ;\
        keyword decoration:fullscreen_opacity 1 ;\
        keyword layerrule noanim,waybar ;\
        keyword layerrule noanim,swaync-notification-window ;\
        keyword layerrule noanim,swww-daemon ;\
        keyword layerrule noanim,rofi
        "
  hyprctl 'keyword windowrulev2 opaque,class:(.*)'
  touch ~/.cache/gamemode
  notify-send -a "gamemode.sh" -r 3 -t 800 "Gamemode: activated" "animations and blur disabled"
fi
