#!/bin/bash

# Get all workspaces and their windows
tooltip=""
active_ws=$(hyprctl activeworkspace -j | jq -r '.id')

# Get all workspace IDs
for ws in $(hyprctl workspaces -j | jq -r '.[].id' | sort -n); do
    # Get windows for this workspace
    windows=$(hyprctl clients -j | jq -r --arg ws "$ws" 'map(select(.workspace.id == ($ws | tonumber)) | .title) | join("\n")')

    if [ -n "$windows" ]; then
        # Add workspace header
        if [ "$ws" -eq "$active_ws" ]; then
            tooltip+="<b>Workspace $ws (active):</b>\n"
        else
            tooltip+="<b>Workspace $ws:</b>\n"
        fi

        # Add window titles with bullet points
        while IFS= read -r window; do
            # Truncate long titles
            if [ ${#window} -gt 50 ]; then
                window="${window:0:47}..."
            fi
            tooltip+="  • $window\n"
        done <<< "$windows"
        tooltip+="\n"
    fi
done

# If no windows found
if [ -z "$tooltip" ]; then
    tooltip="No windows open"
fi

# Output JSON for waybar
echo "{\"text\":\"[WS]\", \"tooltip\":\"$tooltip\"}"
