#!/bin/bash

# source theme colors (fallback to defaults)
source "$HOME/.config/themes/current/waybar-script-colors.sh" 2>/dev/null
COLOR_ERR="${COLOR_ERR:-${COLOR_ERR}}"
COLOR_WARN="${COLOR_WARN:-${COLOR_WARN}}"

# Check if nvidia-smi is available
if ! command -v nvidia-smi &>/dev/null; then
	echo '{"text": "<span color='"'"'${COLOR_ERR}'"'"'>󰾲 N/A</span>", "tooltip": "nvidia-smi not found"}'
	exit 0
fi

# Query all fields in a single call to detect driver issues early
gpu_query=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,power.limit,clocks.gr,clocks.mem,name --format=csv,nounits,noheader 2>&1)

if [[ $? -ne 0 ]]; then
	# grab first line of error for tooltip
	err="${gpu_query%%$'\n'*}"
	echo "{\"text\": \"<span color='${COLOR_ERR}'>󰾲 ERR</span>\", \"tooltip\": \"${err}\"}"
	exit 0
fi

# Parse CSV: "util, temp, mem_used, mem_total, power, power_max, clock, mem_clock, name"
IFS=',' read -r gpu_util gpu_temp gpu_mem_used gpu_mem_total gpu_power gpu_power_max gpu_clock gpu_mem_clock gpu_name <<< "$gpu_query"

# trim whitespace from all fields
gpu_util="${gpu_util// /}"
gpu_temp="${gpu_temp// /}"
gpu_mem_used="${gpu_mem_used// /}"
gpu_mem_total="${gpu_mem_total// /}"
gpu_power="${gpu_power// /}"
gpu_power_max="${gpu_power_max// /}"
gpu_clock="${gpu_clock// /}"
gpu_mem_clock="${gpu_mem_clock// /}"
gpu_name="${gpu_name# }"

# Validate core numeric fields
if [[ ! "$gpu_util" =~ ^[0-9]+$ ]]; then
	echo "{\"text\": \"<span color='${COLOR_ERR}'>󰾲 ERR</span>\", \"tooltip\": \"Unexpected GPU data: ${gpu_util}\"}"
	exit 0
fi

# Safe numeric defaults for optional/variable fields
[[ "$gpu_temp" =~ ^[0-9]+$ ]] || gpu_temp=0
[[ "$gpu_mem_used" =~ ^[0-9]+$ ]] || gpu_mem_used=0
[[ "$gpu_mem_total" =~ ^[0-9]+$ ]] || gpu_mem_total=1

# Calculate memory percentage
gpu_mem_percent=$(( gpu_mem_used * 100 / gpu_mem_total ))

# Convert memory from MiB to GiB for display
gpu_mem_used_gb=$(awk "BEGIN {printf \"%.1f\", $gpu_mem_used / 1024}")
gpu_mem_total_gb=$(awk "BEGIN {printf \"%.1f\", $gpu_mem_total / 1024}")

# Set color based on temperature
if (( gpu_temp >= 80 )); then
	text_output="<span color='${COLOR_ERR}'>󰾲 ${gpu_util}%</span>"
elif (( gpu_temp >= 70 )); then
	text_output="<span color='${COLOR_WARN}'>󰾲 ${gpu_util}%</span>"
else
	text_output="󰾲 ${gpu_util}%"
fi

# Build tooltip
tooltip="${gpu_name}\n"
tooltip+="\nUtilization: ${gpu_util}%"
tooltip+="\nTemperature: ${gpu_temp}°C"
tooltip+="\nMemory:      ${gpu_mem_used_gb} / ${gpu_mem_total_gb} GiB (${gpu_mem_percent}%)"

# Only add power if available
if [[ "$gpu_power" =~ ^[0-9.]+$ ]]; then
	tooltip+="\nPower:       ${gpu_power} / ${gpu_power_max} W"
fi

tooltip+="\nGPU Clock:   ${gpu_clock} MHz"
tooltip+="\nMem Clock:   ${gpu_mem_clock} MHz"

# Output JSON for waybar
echo "{\"text\": \"$text_output\", \"tooltip\": \"$tooltip\"}"
