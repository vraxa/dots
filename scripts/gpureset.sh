#!/bin/bash

# Configuration
GPU_ADDRESS="0000:0a:00.0"
GPU_AUDIO_ADDRESS="0000:0a:00.1"
SUSPEND_DURATION=3
DISPLAY_MANAGER_SERVICE="display-manager.service"
LOG_FILE="/var/log/libvirt/qemu_hooks.log"

# Logging function
log() {
    local level="$1" msg="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp [$level] $msg" >> "$LOG_FILE"
}

prepare() {
    log "INFO" "Setting CPU governor to performance"
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null

    log "INFO" "Stopping display manager"
    systemctl stop "$DISPLAY_MANAGER_SERVICE"

    log "INFO" "Unloading amdgpu driver"
    modprobe -r amdgpu

    log "INFO" "Suspending to RAM for GPU reset"
    rtcwake -m mem -s "$SUSPEND_DURATION"
}

release() {
    log "INFO" "Suspending to RAM for GPU reset"
    rtcwake -m mem -s "$SUSPEND_DURATION"

    log "INFO" "Loading amdgpu driver"
    modprobe amdgpu

    log "INFO" "Starting display manager"
    systemctl start "$DISPLAY_MANAGER_SERVICE"

    log "INFO" "Setting CPU governor to ondemand"
    echo "ondemand" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
}

# Main - Executes based on Libvirt hook action
VM_NAME="$1"
OPERATION="$2"

case "$OPERATION" in
    "prepare")
        log "INFO" "Preparing $VM_NAME"
        prepare
        ;;
    "release")
        log "INFO" "Releasing $VM_NAME"
        release
        ;;
    *)
        log "WARN" "Unknown operation $OPERATION for $VM_NAME"
        ;;
esac
