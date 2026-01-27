#!/bin/bash
echo 1 > /sys/bus/pci/devices/0000:0a:00.0/remove
echo 1 > /sys/bus/pci/devices/0000:0a:00.1/remove
echo "Suspending..."
rtcwake -m no -s 3
systemctl suspend
sleep 2s
openrgb -p /home/tt/.config/OpenRGB/1.orp
echo 1 > /sys/bus/pci/rescan   
echo "Reset done"
