#!/bin/sh
# NAS Wake Monitor - Self-Extracting Installer
# This installer embeds all required files using here-documents for transparency
# 
# Usage: sh nas-wake-installer.sh [--enable]
#        --enable: Also enable the service in default runlevel

set -e

# Installation paths
DAEMON_PATH="/usr/local/bin/nas-wake-monitor.sh"
INIT_PATH="/etc/init.d/nas-wake-monitor"
SERVICE_NAME="nas-wake-monitor"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
    exit 1
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    error "This installer must be run as root (use sudo)"
fi

# Check if already installed
check_installation() {
    if [ -f "$DAEMON_PATH" ] && [ -f "$INIT_PATH" ]; then
        info "NAS Wake Monitor is already installed"
        info "Daemon script: $DAEMON_PATH"
        info "Init script: $INIT_PATH"
        
        # Check if service is enabled
        if rc-status default 2>/dev/null | grep -q "$SERVICE_NAME"; then
            info "Service is enabled in default runlevel"
        else
            info "Service is NOT enabled (use --enable or: rc-update add $SERVICE_NAME default)"
        fi
        
        # Check if service is running
        if rc-service "$SERVICE_NAME" status >/dev/null 2>&1; then
            info "Service is currently running"
        else
            info "Service is not running (start with: rc-service $SERVICE_NAME start)"
        fi
        
        warn "Installation already complete. Exiting."
        exit 0
    fi
}

info "Starting NAS Wake Monitor installation..."

# Check if already installed
check_installation

# Check for required commands
for cmd in rc-update rc-service; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command not found: $cmd (is this Alpine Linux with OpenRC?)"
    fi
done

# Check for runtime dependencies
info "Checking for required runtime dependencies..."
MISSING_DEPS=""
for cmd in tcpdump ether-wake; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    printf "${RED}[ERROR]${NC} Missing required dependencies:%s\n" "$MISSING_DEPS"
    printf "        Install with: apk add tcpdump net-tools\n"
    exit 1
fi
