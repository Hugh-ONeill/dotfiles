#!/bin/bash

# source theme colors (fallback to defaults)
source "$HOME/.config/themes/current/waybar-script-colors.sh" 2>/dev/null
COLOR_ERR="${COLOR_ERR:-${COLOR_ERR}}"

# Get CPU model (removed "(R)", "(TM)", and clock speed)
model=$(awk -F ': ' '/model name/{print $2}' /proc/cpuinfo 2>/dev/null | head -n 1 | sed 's/@.*//; s/ *\((R)\|(TM)\)//g; s/^[ \t]*//; s/[ \t]*$//')
model="${model:-Unknown CPU}"

# Get CPU usage percentage
if command -v vmstat &>/dev/null; then
  load=$(vmstat 1 2 2>/dev/null | tail -1 | awk '{print 100 - $15}')
fi

if [[ ! "${load:-}" =~ ^[0-9]+$ ]]; then
  echo "{\"text\": \"<span color='${COLOR_ERR}'>󰻠 N/A</span>\", \"tooltip\": \"${model}\nCPU Usage: unavailable\"}"
  exit 0
fi

# Determine CPU state based on usage
if (( load >= 80 )); then
  state="Critical"
elif (( load >= 60 )); then
  state="High"
elif (( load >= 25 )); then
  state="Moderate"
else
  state="Low"
fi

# Set color based on CPU load
if (( load >= 80 )); then
  text_output="<span color='${COLOR_ERR}'>󰀩 ${load}%</span>"
else
  text_output="󰻠 ${load}%"
fi

tooltip="${model}"
tooltip+="\nCPU Usage: ${state}"

# Module and tooltip
echo "{\"text\": \"$text_output\", \"tooltip\": \"$tooltip\"}"
