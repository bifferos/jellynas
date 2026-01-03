#!/bin/sh
# NFS Idle Suspend Daemon
# Monitors NFSv4 activity and suspends system after idle period

# Configuration
CHECK_INTERVAL=5        # Check every 5 seconds
IDLE_THRESHOLD=30       # Suspend after 30 seconds of inactivity
IDLE_CHECKS=$((IDLE_THRESHOLD / CHECK_INTERVAL))  # Number of consecutive idle checks needed

# NFS stats file
NFS_STATS="/proc/net/rpc/nfsd"

# Log function
log() {
    logger -t nfs-idle-suspend "$1"
}

# Check if NFS is running
if [ ! -f "$NFS_STATS" ]; then
    log "ERROR: $NFS_STATS not found. Is NFS server running?"
    exit 1
fi

# Get NFS stats snapshot
get_nfs_stats() {
    cat "$NFS_STATS"
}

log "Starting NFS idle monitor (check every ${CHECK_INTERVAL}s, suspend after ${IDLE_THRESHOLD}s idle)"

# Initialize
prev_stats=$(get_nfs_stats)
idle_count=0

while true; do
    sleep "$CHECK_INTERVAL"
    
    current_stats=$(get_nfs_stats)
    
    if [ "$current_stats" = "$prev_stats" ]; then
        # No activity detected
        idle_count=$((idle_count + 1))
        
        if [ $idle_count -ge $IDLE_CHECKS ]; then
            log "No NFS activity for ${IDLE_THRESHOLD}s. Suspending system..."
            sync
            echo mem > /sys/power/state
            # After resume
            log "System resumed from suspend"
            idle_count=0
        fi
    else
        # Activity detected
        if [ $idle_count -gt 0 ]; then
            log "NFS activity detected, resetting idle counter"
        fi
        idle_count=0
        prev_stats="$current_stats"
    fi
done
