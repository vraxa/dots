#!/bin/bash

# Specify your primary output (monitor)
PRIMARY_OUTPUT="DP-2"

# Get the list of workspaces on the primary monitor
primary_workspaces=$(swaymsg -t get_workspaces | jq -r ".[] | select(.output == \"$PRIMARY_OUTPUT\") | .name")

# Get the currently focused workspace
current_workspace=$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused==true) | .name')

# Create an array of the currently available primary workspaces
available_workspaces=()
while IFS= read -r ws; do
    available_workspaces+=("$ws")
done <<< "$primary_workspaces"

# Count the number of available workspaces
workspace_count=${#available_workspaces[@]}

# If there are no workspaces on the primary monitor, exit
if [ "$workspace_count" -eq 0 ]; then
    exit 0
fi

# Determine the next workspace to switch to (backward)
next_workspace_number=$current_workspace
for ((i = 0; i < workspace_count; i++)); do
    if [[ "${available_workspaces[i]}" == "$current_workspace" ]]; then
        next_index=$(( (i - 1 + workspace_count) % workspace_count )) # Adjust for backward movement
        next_workspace_number=${available_workspaces[next_index]}
        break
    fi
done

# Switch to the next workspace
swaymsg workspace "$next_workspace_number"
