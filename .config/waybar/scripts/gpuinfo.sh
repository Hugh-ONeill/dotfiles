#!/bin/bash

# Check if nvidia-smi is available
if ! command -v nvidia-smi &>/dev/null; then
	echo "{\"text\": \"󰾲 N/A\", \"tooltip\": \"nvidia-smi utility is missing\"}"
	exit 1
fi

# Get GPU utilization
gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,nounits,noheader 2>/dev/null)

# If nvidia-smi fails, show error
if [ -z "$gpu_util" ]; then
	echo "{\"text\": \"󰾲 ERR\", \"tooltip\": \"Failed to query GPU\"}"
	exit 1
fi

# Get GPU temperature
gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,nounits,noheader)

# Get GPU memory usage (used and total in MiB)
gpu_mem_used=$(nvidia-smi --query-gpu=memory.used --format=csv,nounits,noheader)
gpu_mem_total=$(nvidia-smi --query-gpu=memory.total --format=csv,nounits,noheader)

# Calculate memory percentage
gpu_mem_percent=$(awk "BEGIN {printf \"%.0f\", ($gpu_mem_used / $gpu_mem_total) * 100}")

# Get GPU power draw and max power
gpu_power=$(nvidia-smi --query-gpu=power.draw --format=csv,nounits,noheader 2>/dev/null)
gpu_power_max=$(nvidia-smi --query-gpu=power.limit --format=csv,nounits,noheader 2>/dev/null)

# Get GPU clock speeds
gpu_clock=$(nvidia-smi --query-gpu=clocks.gr --format=csv,nounits,noheader)
gpu_mem_clock=$(nvidia-smi --query-gpu=clocks.mem --format=csv,nounits,noheader)

# Get GPU name
gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader)

# Convert memory from MiB to GiB for display
gpu_mem_used_gb=$(awk "BEGIN {printf \"%.1f\", $gpu_mem_used / 1024}")
gpu_mem_total_gb=$(awk "BEGIN {printf \"%.1f\", $gpu_mem_total / 1024}")

# Set color based on temperature
if [ "$gpu_temp" -ge 80 ]; then
	# If temperature is >= 80°C, set color to red
	text_output="<span color='#f38ba8'>󰾲 ${gpu_util}%</span>"
elif [ "$gpu_temp" -ge 70 ]; then
	# If temperature is >= 70°C, set color to yellow
	text_output="<span color='#f9e2af'>󰾲 ${gpu_util}%</span>"
else
	# Default color
	text_output="󰾲 ${gpu_util}%"
fi

# Build tooltip
tooltip="${gpu_name}\n"
tooltip+="\nUtilization: ${gpu_util}%"
tooltip+="\nTemperature: ${gpu_temp}°C"
tooltip+="\nMemory:      ${gpu_mem_used_gb} / ${gpu_mem_total_gb} GiB (${gpu_mem_percent}%)"

# Only add power if available
if [[ -n "$gpu_power" && "$gpu_power" != "[N/A]" ]]; then
	tooltip+="\nPower:       ${gpu_power} / ${gpu_power_max} W"
fi

tooltip+="\nGPU Clock:   ${gpu_clock} MHz"
tooltip+="\nMem Clock:   ${gpu_mem_clock} MHz"

# Output JSON for waybar
echo "{\"text\": \"$text_output\", \"tooltip\": \"$tooltip\"}"
