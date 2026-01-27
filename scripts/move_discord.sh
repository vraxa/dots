#!/bin/bash

#sleep 5

# Focus Discord window
hyprctl dispatch focuswindow class:discord

# Move the focused window
sleep 0.1  # Wait for a bit to ensure that the focus has changed (optional)
hyprctl dispatch movewindow d

# Resize the active workspace by 30%
hyprctl dispatch -- resizeactive 0 -30%
