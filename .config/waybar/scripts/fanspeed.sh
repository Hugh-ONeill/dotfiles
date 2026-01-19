#!/bin/bash

# Check if nbfc is available
if ! command -v nbfc &>/dev/null; then
	echo "{\"text\": \" N/A\", \"tooltip\": \"nbfc utility is missing\"}"
	exit 1
fi

# Get nbfc status
nbfc_output=$(nbfc status 2>&1)

# Check if nbfc command succeeded
if [ $? -ne 0 ]; then
	echo "{\"text\": \" ERR\", \"tooltip\": \"Failed to query fan status\"}"
	exit 1
fi

# Parse fan information
config_name=$(echo "$nbfc_output" | awk -F': ' '/Selected Config Name/ {print $2}' | xargs)

# Function to get fan info by index
get_fan_info() {
	local fan_index=$1
	local fan_info=$(echo "$nbfc_output" | awk -v RS="" -v fan="$fan_index" '
		/Fan Display Name/ {
			if (++count == fan+1) {
				print
			}
		}
	')

	if [ -z "$fan_info" ]; then
		echo ""
		return 1
	fi

	local display_name=$(echo "$fan_info" | awk -F': ' '/Fan Display Name/ {print $2}' | xargs)
	local temperature=$(echo "$fan_info" | awk -F': ' '/^Temperature/ {print $2}' | xargs)
	local current_speed=$(echo "$fan_info" | awk -F': ' '/Current Fan Speed/ {print $2}' | xargs)
	local target_speed=$(echo "$fan_info" | awk -F': ' '/Target Fan Speed/ {print $2}' | xargs)
	local auto_control=$(echo "$fan_info" | awk -F': ' '/Auto Control Enabled/ {print $2}' | xargs)

	echo "${display_name}|${temperature}|${current_speed}|${target_speed}|${auto_control}"
}

# Get info for both fans
fan0_info=$(get_fan_info 0)
fan1_info=$(get_fan_info 1)

# Parse fan 0
if [ -n "$fan0_info" ]; then
	IFS='|' read -r fan0_name fan0_temp fan0_current fan0_target fan0_auto <<< "$fan0_info"
fi

# Parse fan 1
if [ -n "$fan1_info" ]; then
	IFS='|' read -r fan1_name fan1_temp fan1_current fan1_target fan1_auto <<< "$fan1_info"
fi

# Calculate average or max fan speed for display
if [ -n "$fan0_current" ] && [ -n "$fan1_current" ]; then
	# Use the higher of the two fan speeds
	if (( $(echo "$fan0_current > $fan1_current" | bc -l) )); then
		display_speed=$fan0_current
	else
		display_speed=$fan1_current
	fi
else
	display_speed=${fan0_current:-${fan1_current:-0}}
fi

# Round to integer
display_speed=$(printf "%.0f" "$display_speed" 2>/dev/null || echo "0")

# Determine color based on speed
if [ "$display_speed" -ge 80 ]; then
	text_output="<span color='#f38ba8'>${display_speed}%</span>"
elif [ "$display_speed" -ge 60 ]; then
	text_output="<span color='#f9e2af'>${display_speed}%</span>"
else
	text_output="${display_speed}%"
fi

# Build tooltip
tooltip="${config_name}\n"

if [ -n "$fan0_info" ]; then
	tooltip+="\n${fan0_name}:"
	tooltip+="\n  Temperature:  ${fan0_temp}°C"
	tooltip+="\n  Current:      ${fan0_current}%"
	tooltip+="\n  Target:       ${fan0_target}%"
	tooltip+="\n  Auto Control: ${fan0_auto}"
fi

if [ -n "$fan1_info" ]; then
	tooltip+="\n\n${fan1_name}:"
	tooltip+="\n  Temperature:  ${fan1_temp}°C"
	tooltip+="\n  Current:      ${fan1_current}%"
	tooltip+="\n  Target:       ${fan1_target}%"
	tooltip+="\n  Auto Control: ${fan1_auto}"
fi

# Output JSON for waybar
echo "{\"text\": \"$text_output\", \"tooltip\": \"$tooltip\"}"
