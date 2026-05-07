#!/bin/bash

# source theme colors (fallback to defaults)
source "$HOME/.config/themes/current/waybar-script-colors.sh" 2>/dev/null
COLOR_ERR="${COLOR_ERR:-${COLOR_ERR}}"

# Get CPU clock speeds
get_cpu_frequency() {
	freqlist=$(awk '/cpu MHz/ {print $4}' /proc/cpuinfo 2>/dev/null)
	maxfreq=$(sed 's/...$//' /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
	if [[ -z "$freqlist" || -z "$maxfreq" ]]; then
		echo "N/A"
		return
	fi
	average_freq=$(echo "$freqlist" | tr ' ' '\n' | awk "{sum+=\$1} END {printf \"%.0f/%s MHz\", sum/NR, $maxfreq}")
	echo "$average_freq"
}

# Get CPU temperature
get_cpu_temperature() {
	if ! command -v sensors &>/dev/null; then
		echo "N/A N/A"
		return
	fi

	local sensors_out
	sensors_out=$(sensors 2>/dev/null) || { echo "N/A N/A"; return; }

	temp=$(echo "$sensors_out" | awk '/Package id 0/ {print $4}' | awk -F '[+.]' '{print $2}')
	if [[ -z "$temp" ]]; then
		temp=$(echo "$sensors_out" | awk '/Tctl/ {print $2}' | awk -F '[+.]' '{print $2}')
	fi
	if [[ -z "$temp" || ! "$temp" =~ ^[0-9]+$ ]]; then
		echo "N/A N/A"
	else
		temp_f=$(awk "BEGIN {printf \"%.1f\", ($temp * 9 / 5) + 32}")
		echo "$temp $temp_f"
	fi
}

# Get the corresponding icon based on temperature
get_temperature_icon() {
	temp_value=$1
  icon=""

	if [ "$temp_value" -ge 80 ]; then
		icon="󰸁" # High temperature
	elif [ "$temp_value" -ge 70 ]; then
		icon="󱃂" # Medium temperature
	elif [ "$temp_value" -ge 60 ]; then
		icon="󰔏" # Normal temperature
	else
		icon="󱃃" # Low temperature
	fi

	echo "$icon"
}

# Main script execution
cpu_frequency=$(get_cpu_frequency)
read -r temp_info < <(get_cpu_temperature)
temp=$(echo "$temp_info" | awk '{print $1}')   # Celsius
temp_f=$(echo "$temp_info" | awk '{print $2}') # Fahrenheit

# Determine the temperature icon — guard non-numeric values
if [[ "$temp" =~ ^[0-9]+$ ]]; then
	thermo_icon=$(get_temperature_icon "$temp")
	if (( temp >= 80 )); then
		text_output="<span color='${COLOR_ERR}'>${thermo_icon} ${temp}°C</span>"
	else
		text_output="${thermo_icon} ${temp}°C"
	fi
	tooltip="Temperature: ${temp_f}°F\nClock Speed: ${cpu_frequency}"
else
	text_output="<span color='${COLOR_ERR}'>󰔏 N/A</span>"
	tooltip="Temperature: unavailable\nClock Speed: ${cpu_frequency}"
fi

# Module and tooltip
echo "{\"text\": \"$text_output\", \"tooltip\": \"$tooltip\"}"
