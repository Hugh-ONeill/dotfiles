#!/bin/bash

# Get the direction from argument (+1 or -1)
direction=$1

# Count active displays (connected monitors)
active_displays=$(hyprctl monitors -j | jq 'length')

# Determine scroll increment based on number of displays
if [ "$active_displays" -eq 1 ]; then
    # Single display: move by 1 workspace
    increment=1
else
    # Multiple displays: move by 2 workspaces (keeps odd/even on same screen)
    increment=2
fi

# Get current workspace
current_ws=$(hyprctl activeworkspace -j | jq '.id')

# Get all workspace IDs and find min/max
workspaces=$(hyprctl workspaces -j | jq '[.[].id] | sort | .[]' | tr '\n' ' ')
min_ws=$(echo $workspaces | awk '{print $1}')
max_ws=$(echo $workspaces | awk '{print $NF}')

# Set absolute maximum limit to prevent infinite scrolling
absolute_max=20

# Set bounds: minimum is the current minimum, maximum expands as workspaces are created
# but never exceeds the absolute maximum
max_allowed=$((max_ws + increment))
if [ "$max_allowed" -gt "$absolute_max" ]; then
    max_allowed=$absolute_max
fi

# Calculate target workspace
if [ "$direction" = "up" ]; then
    target_ws=$((current_ws - increment))
elif [ "$direction" = "down" ]; then
    target_ws=$((current_ws + increment))
else
    exit 1
fi

# Check if target workspace exists
target_exists=$(echo "$workspaces" | grep -w "$target_ws")

# Check if the adjacent workspace in the sequence exists (for sequential creation)
if [ "$direction" = "down" ]; then
    # When going down, check if previous workspace exists and has windows
    adjacent_ws=$((target_ws - increment))
elif [ "$direction" = "up" ]; then
    # When going up, check if next workspace exists
    adjacent_ws=$((target_ws + increment))
fi
adjacent_exists=$(echo "$workspaces" | grep -w "$adjacent_ws")

# Check if adjacent workspace has windows (only for extended workspaces beyond 12)
if [ -n "$adjacent_exists" ] && [ "$direction" = "down" ] && [ "$target_ws" -gt 12 ]; then
    adjacent_windows=$(hyprctl workspaces -j | jq ".[] | select(.id == $adjacent_ws) | .windows")
    if [ "$adjacent_windows" -eq 0 ]; then
        # Previous workspace is empty, don't allow creating new one beyond workspace 12
        exit 0
    fi
fi

# Only switch if:
# 1. Within bounds AND
# 2. Either the target workspace exists OR the adjacent workspace exists (and has windows if going down)
if [ "$target_ws" -ge "$min_ws" ] && [ "$target_ws" -le "$max_allowed" ]; then
    if [ -n "$target_exists" ] || [ -n "$adjacent_exists" ]; then
        hyprctl dispatch workspace "$target_ws"
    fi
fi
