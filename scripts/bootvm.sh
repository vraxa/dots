#!/bin/bash


# Start the VM (without sudo if permissions are set correctly)
virsh --connect qemu:///system start win11

# Optional: Wait for the VM to boot up
notify-send "Trevor's Awesome VM Script" "Booting up Windows 11..."
sleep 5

# Start Looking Glass client (adjust to your setup)
#looking-glass-client -a -F
