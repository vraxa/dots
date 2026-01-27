
#!/bin/bash

if pgrep -f "gpu-screen-recorder" > /dev/null; then
    # Stop recording if already running
   killall -SIGINT gpu-screen-recorder
   notify-send "Recording Stopped"
else
    # Start recording if not running
    notify-send "Recording Started"
    gpu-screen-recorder -w screen -f 60 -a default_output -o ~/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4
fi
