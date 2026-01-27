#!/bin/bash

# Define the target CIFS mount point
mount_point="/mnt/tt-s2"

# Check if the mount point exists and is mounted
if mount | grep -q "$mount_point"; then
    # Get the used, total, and percentage from df in GiB (trim spaces using awk)
    used=$(df -h --output=used "$mount_point" | tail -n 1 | awk '{$1=$1; print}')
    total=$(df -h --output=size "$mount_point" | tail -n 1 | awk '{$1=$1; print}')
    percentage=$(df -h --output=pcent "$mount_point" | tail -n 1 | tr -d '%' | awk '{$1=$1; print}')

    # Format and display the output
    echo -e "${used} / ${total} ($(tput setaf 2)${percentage}%$(tput sgr0))"
else
    echo "Drive $mount_point not mounted."
fi
