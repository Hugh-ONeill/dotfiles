#!/bin/bash

# source theme colors (fallback to defaults)
source "$HOME/.config/themes/current/waybar-script-colors.sh" 2>/dev/null
COLOR_ERR="${COLOR_ERR:-${COLOR_ERR}}"
COLOR_WARN="${COLOR_WARN:-${COLOR_WARN}}"
COLOR_OK="${COLOR_OK:-${COLOR_OK}}"
COLOR_INFO="${COLOR_INFO:-${COLOR_INFO}}"

# Battery information script with detailed tooltip

BATTERY_PATH="/sys/class/power_supply/BAT0"

# Check if battery exists
if [ ! -d "$BATTERY_PATH" ]; then
	echo "{\"text\": \"󰂎 N/A\", \"tooltip\": \"No battery found\"}"
	exit 0
fi

# Get battery information
capacity=$(cat "$BATTERY_PATH/capacity" 2>/dev/null || echo "0")
status=$(cat "$BATTERY_PATH/status" 2>/dev/null || echo "Unknown")

# Use upower for more accurate status if available
if command -v upower &>/dev/null; then
	upower_state=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "state:" | awk '{print $2}')
	case "$upower_state" in
		"fully-charged") status="Full" ;;
		"charging") status="Charging" ;;
		"discharging") status="Discharging" ;;
		"pending-charge") status="Charging" ;;
		"pending-discharge") status="Discharging" ;;
	esac
fi
charge_now=$(cat "$BATTERY_PATH/charge_now" 2>/dev/null || echo "0")
charge_full=$(cat "$BATTERY_PATH/charge_full" 2>/dev/null || echo "0")
charge_full_design=$(cat "$BATTERY_PATH/charge_full_design" 2>/dev/null || echo "0")
current_now=$(cat "$BATTERY_PATH/current_now" 2>/dev/null || echo "0")
cycle_count=$(cat "$BATTERY_PATH/cycle_count" 2>/dev/null || echo "N/A")
manufacturer=$(cat "$BATTERY_PATH/manufacturer" 2>/dev/null || echo "Unknown")
model_name=$(cat "$BATTERY_PATH/model_name" 2>/dev/null || echo "Unknown")
technology=$(cat "$BATTERY_PATH/technology" 2>/dev/null || echo "Unknown")

# Calculate battery health (current full capacity vs design capacity)
if [ "$charge_full_design" -gt 0 ]; then
	health=$(awk "BEGIN {printf \"%.1f\", ($charge_full / $charge_full_design) * 100}")
else
	health="N/A"
fi

# Convert charge values from µAh to mAh or Ah for display
charge_now_mah=$(awk "BEGIN {printf \"%.0f\", $charge_now / 1000}")
charge_full_mah=$(awk "BEGIN {printf \"%.0f\", $charge_full / 1000}")
charge_full_design_mah=$(awk "BEGIN {printf \"%.0f\", $charge_full_design / 1000}")

# Calculate power consumption in watts
if [ "$current_now" -gt 0 ]; then
	# Get voltage (in µV)
	voltage=$(cat "$BATTERY_PATH/voltage_now" 2>/dev/null || echo "0")
	if [ "$voltage" -gt 0 ]; then
		# Power = Current × Voltage (convert from µW to W)
		power=$(awk "BEGIN {printf \"%.2f\", ($current_now * $voltage) / 1000000000000}")
	else
		power="N/A"
	fi
else
	power="0.00"
fi

# Calculate time remaining
time_remaining="N/A"

# Try using upower first (more accurate)
if command -v upower &>/dev/null; then
	upower_output=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null)

	# Get time to empty or time to full from upower
	if echo "$upower_output" | grep -q "time to empty"; then
		time_remaining=$(echo "$upower_output" | grep "time to empty" | awk '{print $4, $5}' | sed 's/minutes/m/;s/hours/h/')
	elif echo "$upower_output" | grep -q "time to full"; then
		time_remaining=$(echo "$upower_output" | grep "time to full" | awk '{print $4, $5}' | sed 's/minutes/m/;s/hours/h/')
	fi
fi

# Fallback to manual calculation if upower didn't provide time or isn't available
if [ "$time_remaining" = "N/A" ] && [ "$current_now" -gt 0 ]; then
	if [ "$status" = "Discharging" ]; then
		# Time to empty = charge_now / current_now (in hours)
		hours=$(awk "BEGIN {printf \"%.2f\", $charge_now / $current_now}")
		hours_int=$(printf "%.0f" "$hours")
		minutes=$(awk "BEGIN {printf \"%.0f\", ($hours - $hours_int) * 60}")
		time_remaining="${hours_int}h ${minutes}m"
	elif [ "$status" = "Charging" ]; then
		# Time to full = (charge_full - charge_now) / current_now
		hours=$(awk "BEGIN {printf \"%.2f\", ($charge_full - $charge_now) / $current_now}")
		hours_int=$(printf "%.0f" "$hours")
		minutes=$(awk "BEGIN {printf \"%.0f\", ($hours - $hours_int) * 60}")
		time_remaining="${hours_int}h ${minutes}m"
	fi
fi

# Determine icon based on status and capacity
determine_icon() {
	local cap=$1
	local stat=$2

	if [ "$stat" = "Charging" ]; then
		printf '\uE00A'
	elif [ "$stat" = "Full" ]; then
		printf '\uE00A'
	elif [ "$cap" -le 10 ]; then
		echo "󱃍"
	elif [ "$cap" -le 20 ]; then
		echo "󰁻"
	elif [ "$cap" -le 30 ]; then
		echo "󰁼"
	elif [ "$cap" -le 40 ]; then
		echo "󰁽"
	elif [ "$cap" -le 50 ]; then
		echo "󰁾"
	elif [ "$cap" -le 60 ]; then
		echo "󰁿"
	elif [ "$cap" -le 70 ]; then
		echo "󰂀"
	elif [ "$cap" -le 80 ]; then
		echo "󰂁"
	elif [ "$cap" -le 90 ]; then
		echo "󰂂"
	else
		echo "󰁹"
	fi
}

icon=$(determine_icon "$capacity" "$status")

# Determine text color based on status
if [ "$capacity" -le 15 ]; then
	# Critical - red
	text_output="<span color='${COLOR_ERR}'>${icon} ${capacity}%</span>"
elif [ "$capacity" -le 30 ]; then
	# Warning - yellow
	text_output="<span color='${COLOR_WARN}'>${icon} ${capacity}%</span>"
elif [ "$status" = "Charging" ]; then
	# Charging - blue
	text_output="<span color='${COLOR_INFO}'>${icon} ${capacity}%</span>"
elif [ "$status" = "Discharging" ] && [ "$capacity" -gt 50 ]; then
	# Good battery level while unplugged - green
	text_output="<span color='${COLOR_OK}'>${icon} ${capacity}%</span>"
else
	# Normal (includes Full, and discharging 31-50%)
	text_output="${icon} ${capacity}%"
fi

# Build detailed tooltip
tooltip="${manufacturer} ${model_name}\n"
tooltip+="\nStatus:       ${status}"
tooltip+="\nCapacity:     ${capacity}%"

if [ "$time_remaining" != "N/A" ]; then
	if [ "$status" = "Discharging" ]; then
		tooltip+="\nTime Left:    ${time_remaining}"
	elif [ "$status" = "Charging" ]; then
		tooltip+="\nTime to Full: ${time_remaining}"
	fi
fi

tooltip+="\n\nBattery Health:"
tooltip+="\n  Current:      ${charge_full_mah} mAh"
tooltip+="\n  Design:       ${charge_full_design_mah} mAh"

if [ "$health" != "N/A" ]; then
	tooltip+="\n  Health:       ${health}%"
fi

if [ "$cycle_count" != "N/A" ]; then
	tooltip+="\n  Cycles:       ${cycle_count}"
fi

tooltip+="\n\nPower Info:"

if [ "$power" != "N/A" ]; then
	tooltip+="\n  Draw:         ${power} W"
fi

tooltip+="\n  Technology:   ${technology}"

# Output JSON for waybar
echo "{\"text\": \"$text_output\", \"tooltip\": \"$tooltip\", \"class\": \"${status,,}\"}"
