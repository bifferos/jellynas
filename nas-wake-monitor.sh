#!/bin/sh
# NAS Wake Monitor
# Monitors bidirectional NAS traffic to send WOL only when needed

# Configuration - EDIT THESE VALUES
NAS_HOST="thirstynas"           # DNS name or IP of NAS
NAS_MAC="AA:BB:CC:DD:EE:FF"     # MAC address of NAS for WOL
INTERFACE="eth0"                # Network interface to monitor (eth0, enp0s3, etc.)
ACTIVITY_FILE="/tmp/nas-activity"  # Timestamp file for NAS heartbeat
ACTIVITY_THRESHOLD=2            # Seconds - skip wake if NAS responded recently

# Log function
log() {
    logger -t nas-wake-monitor "$1"
}

# Check for required commands
for cmd in tcpdump ether-wake; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "ERROR: Required command not found: $cmd"
        exit 1
    fi
done

# Auto-detect local MAC address from interface
LOCAL_MAC=$(cat /sys/class/net/"$INTERFACE"/address 2>/dev/null)
if [ -z "$LOCAL_MAC" ]; then
    log "ERROR: Cannot detect MAC address for interface $INTERFACE"
    exit 1
fi

# Resolve NAS hostname to IP once at startup (avoids DNS lookup every iteration)
NAS_IP=$(getent hosts "$NAS_HOST" | awk '{print $1}')
if [ -z "$NAS_IP" ]; then
    log "ERROR: Cannot resolve $NAS_HOST to IP address"
    exit 1
fi

log "Starting NAS wake monitor for $NAS_HOST ($NAS_IP -> $NAS_MAC) from $LOCAL_MAC on $INTERFACE"

# Cleanup function - ensures background monitor stops when service stops
cleanup() {
    log "Shutting down..."
    [ -n "$INCOMING_PID" ] && kill "$INCOMING_PID" 2>/dev/null
    exit 0
}
trap cleanup INT TERM

# Background job: Monitor incoming traffic from NAS
monitor_incoming() {
    # Monitor incoming traffic with 0.1s sampling rate
    INCOMING_FROM_NAS="ether src $NAS_MAC and ether dst $LOCAL_MAC"
    while true; do
        # Wait for single packet, update timestamp, then brief delay
        tcpdump -i "$INTERFACE" -c 1 -n "$INCOMING_FROM_NAS" >/dev/null 2>&1
        touch "$ACTIVITY_FILE"
        sleep 0.1
    done
}

# Start incoming monitor in background
monitor_incoming &
INCOMING_PID=$!
log "Incoming traffic monitor started (PID $INCOMING_PID)"

# Wake sequence function - sends magic packets until timeout
wake_nas() {
    log "Sending wake packet to $NAS_MAC"
    ether-wake -i "$INTERFACE" "$NAS_MAC" 2>/dev/null
}

# BPF filters for outgoing traffic detection
OUTGOING_UNICAST="ether dst $NAS_MAC and ether src $LOCAL_MAC"
OUTGOING_ARP="arp and host $NAS_IP and ether src $LOCAL_MAC"

# Main monitoring loop - watches outgoing traffic
while true; do
    # Wait for single packet indicating outgoing activity
    tcpdump -i "$INTERFACE" -c 1 -n "($OUTGOING_UNICAST) or ($OUTGOING_ARP)" >/dev/null 2>&1
    
    # Check if NAS has responded recently (activity file updated by incoming monitor)
    if [ -f "$ACTIVITY_FILE" ]; then
        ACTIVITY_TIME=$(stat -c %Y "$ACTIVITY_FILE" 2>/dev/null || echo 0)
        CURRENT_TIME=$(date +%s)
        AGE=$((CURRENT_TIME - ACTIVITY_TIME))
        
        if [ "$AGE" -lt "$ACTIVITY_THRESHOLD" ]; then
            # NAS responded recently - definitely awake, skip magic packet
            continue
        fi
    fi
    
    # No recent response from NAS - send magic packet
    wake_nas
    
    # Brief delay to avoid packet storm
    sleep 1
done
