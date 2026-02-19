#!/bin/bash

# Check if wlogout is already running, and terminate if so
if pgrep -x "wlogout" >/dev/null; then
  pkill -x "wlogout"
  exit 0
fi

config="$HOME/.config/wlogout"
layout="${config}/layout"
style="${config}/style.css"

# Detect monitor resolution and scaling
screen_width=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .width')
screen_height=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .height')
scale_factor=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .scale' | sed 's/\.//')

# Outer margin to center the grid
margin_tb=$((screen_height * 30 / scale_factor))
margin_lr=$((screen_width * 30 / scale_factor))

# Substitute variables in the style template
style_content=$(envsubst <"$style")

# Launch wlogout — 3 columns, 2 rows, centered with outer margins
wlogout -b 3 -c 10 -r 10 \
  -T "$margin_tb" -B "$margin_tb" \
  -L "$margin_lr" -R "$margin_lr" \
  --layout "${layout}" --css <(echo "${style_content}") --protocol layer-shell
