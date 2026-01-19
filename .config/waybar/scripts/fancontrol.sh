#!/bin/bash

# Fan control script for nbfc
# Usage: fancontrol.sh [up|down|auto]

STEP=10 # Percentage to increase/decrease

# Check if nbfc is available
if ! command -v nbfc &>/dev/null; then
	notify-send "Fan Control" "nbfc utility is missing" -u critical
	exit 1
fi

# Get current fan speed (use the higher of the two fans)
get_current_speed() {
	nbfc_output=$(nbfc status 2>&1)

	fan0_speed=$(echo "$nbfc_output" | awk -v RS="" 'NR==2 {print}' | awk -F': ' '/Current Fan Speed/ {print $2}' | xargs)
	fan1_speed=$(echo "$nbfc_output" | awk -v RS="" 'NR==3 {print}' | awk -F': ' '/Current Fan Speed/ {print $2}' | xargs)

	# Return the higher speed
	if (( $(echo "$fan0_speed > $fan1_speed" | bc -l) )); then
		echo "$fan0_speed"
	else
		echo "$fan1_speed"
	fi
}

case "$1" in
	up)
		current=$(get_current_speed)
		new_speed=$(echo "$current + $STEP" | bc)

		# Cap at 100%
		if (( $(echo "$new_speed > 100" | bc -l) )); then
			new_speed=100
		fi

		new_speed=$(printf "%.0f" "$new_speed")
		nbfc set -s "$new_speed"
		notify-send "Fan Control" "Fan speed set to ${new_speed}%" -t 2000
		;;

	down)
		current=$(get_current_speed)
		new_speed=$(echo "$current - $STEP" | bc)

		# Don't go below 0%
		if (( $(echo "$new_speed < 0" | bc -l) )); then
			new_speed=0
		fi

		new_speed=$(printf "%.0f" "$new_speed")
		nbfc set -s "$new_speed"
		notify-send "Fan Control" "Fan speed set to ${new_speed}%" -t 2000
		;;

	auto)
		nbfc set -a
		notify-send "Fan Control" "Automatic fan control enabled" -t 2000
		;;

	*)
		echo "Usage: $0 [up|down|auto]"
		exit 1
		;;
esac
