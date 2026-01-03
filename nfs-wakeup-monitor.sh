#!/bin/sh
# NFS Wakeup Monitor
# Monitors outgoing traffic to NAS and sends WOL when activity detected

# Configuration - EDIT THESE VALUES
NAS_HOST="thirstynas"           # DNS name or IP of NAS
NAS_MAC="AA:BB:CC:DD:EE:FF"     # MAC address of NAS for WOL
LOCAL_MAC="11:22:33:44:55:66"   # MAC address of this client (get with: ip link or ifconfig)
INTERFACE="eth0"                # Network interface to monitor (eth0, enp0s3, etc.)
NFS_PORT=2049                   # NFSv4 port
WAKE_TIMEOUT=30                 # Seconds to wait for NAS to wake

# Log function
log() {
    logger -t nfs-wakeup-monitor "$1"
}

# Check for required commands
for cmd in tcpdump ether-wake nc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "ERROR: Required command not found: $cmd"
        exit 1
    fi
done

log "Starting NFS wakeup monitor for $NAS_HOST ($NAS_MAC) from $LOCAL_MAC on $INTERFACE"

# Wake sequence function
wake_nas() {
    log "Activity detected, initiating wake sequence..."
    
    # Send WOL and check after each one - NAS might already be awake
    attempts=0
    while true; do
        # Send WOL packet
        ether-wake "$NAS_MAC" 2>/dev/null || log "WARNING: Failed to send WOL packet"
        
        # Check if NAS is responding
        if nc -z -w1 "$NAS_HOST" "$NFS_PORT" 2>/dev/null; then
            log "NAS is awake and responding on port $NFS_PORT (after $attempts seconds)"
            return 0
        fi
        
        attempts=$((attempts + 1))
        
        # Log periodically so we know it's trying
        if [ $((attempts % 10)) -eq 0 ]; then
            log "Still waiting for NAS response ($attempts attempts so far)..."
        fi
        
        sleep 1
    done
}

# Main monitoring loop
while true; do
    # Wait for single packet indicating activity, then stop
    tcpdump -i "$INTERFACE" -c 1 -n "(dst host $NAS_HOST) or (arp and host $NAS_HOST and ether src $LOCAL_MAC) or (ether dst $NAS_MAC)" >/dev/null 2>&1
    
    # Stop the world and wake NAS
    wake_nas
    
    # Resume monitoring immediately (wake sequence already provided delay)
    log "Resuming monitoring..."
done
