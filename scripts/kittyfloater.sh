#!/bin/bash

# Launch Kitty
kitty &

# Wait for a moment to allow Kitty to launch
sleep 0.5  

# Get the ID of the most recently opened Kitty window
NEW_WINDOW_ID=$(swaymsg -t get_tree | jq '.. | select(.app_id? == "kitty") | .id' | tail -n 1)

# Debugging output to confirm we have the correct window ID
echo "New Kitty window ID: $NEW_WINDOW_ID"

# Check if we have a valid ID and set it to floating and resize
if [ -n "$NEW_WINDOW_ID" ]; then
    # Enable floating mode
    swaymsg "[id=$NEW_WINDOW_ID] floating enable"
    echo "Enabled floating for window ID: $NEW_WINDOW_ID"
    
    # Wait before resizing to allow for any initialization
    sleep 0.1 

    # Resize the window
    swaymsg "[id=$NEW_WINDOW_ID] resize set 800 600"
    echo "Resized window ID: $NEW_WINDOW_ID to 800x600"
else
    echo "Kitty window ID not found."
fi
