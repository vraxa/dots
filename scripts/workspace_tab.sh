#!/bin/bash

# Specify your primary output (monitor)
PRIMARY_OUTPUT="DP-2"

# Get the list of all workspaces on the primary monitor
primary_workspaces=$(swaymsg -t get_workspaces | jq -r ".[] | select(.output == \"$PRIMARY_OUTPUT\") | .name")

# Count the number of workspaces on the primary monitor
workspace_count=$(echo "$primary_workspaces" | wc -l)

# If there are no workspaces, exit
if [ "$workspace_count" -eq 0 ]; then
    exit 0
fi

# Get the currently focused workspace
current_workspace=$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused==true) | .name')

# Convert the current workspace to an integer
current_workspace_number=$(echo "$current_workspace" | grep -o '[0-9]*')

# Create an array of the currently available primary workspaces
available_workspaces=()
for ws in $primary_workspaces; do
    available_workspaces+=("$ws")
done

# Determine the next workspace
if [ "$current_workspace_number" -eq "${available_workspaces[-1]}" ]; then
    next_workspace_number="${available_workspaces[0]}" # Wrap around to the first workspace
else
    for i in "${!available_workspaces[@]}"; do
        if [[ "${available_workspaces[$i]}" -eq "$current_workspace_number" ]]; then
            next_workspace_number="${available_workspaces[$(( (i + 1) % workspace_count ))]}"
            break
        fi
    done
fi

# Switch to the next workspace
swaymsg workspace "$next_workspace_number"

