#!/bin/bash

# Get all workspaces with their windows
workspaces=$(hyprctl workspaces -j)

# Get current workspace
current=$(hyprctl activeworkspace -j | jq -r '.id')

# Build JSON output for waybar
output='{'

# For each workspace, get window titles
for ws in $(echo "$workspaces" | jq -r '.[].id' | sort -n); do
    # Get windows for this workspace
    windows=$(hyprctl clients -j | jq -r --arg ws "$ws" '.[] | select(.workspace.id == ($ws | tonumber)) | .title' | sed 's/"/\\"/g')

    # Count windows
    count=$(echo "$windows" | grep -c '^' 2>/dev/null || echo "0")
    if [ -z "$windows" ] || [ "$count" -eq 0 ]; then
        count=0
        tooltip="Workspace $ws: Empty"
    else
        # Concatenate window titles
        tooltip="Workspace $ws:\n$(echo "$windows" | sed 's/^/  • /' | tr '\n' '|' | sed 's/|$//' | sed 's/|/\\n/g')"
    fi

    # Add to output (waybar custom module format)
    if [ "$ws" = "$current" ]; then
        active="true"
    else
        active="false"
    fi
done

# Output simple text - waybar will query hyprctl directly
echo '{"text": "", "tooltip": "Hover over workspaces to see windows"}'
