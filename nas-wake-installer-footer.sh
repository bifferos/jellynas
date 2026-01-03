# Main installation logic

# Create temporary files
TEMP_DAEMON=$(mktemp)
TEMP_INIT=$(mktemp)

# Cleanup on exit
cleanup() {
    rm -f "$TEMP_DAEMON" "$TEMP_INIT"
}
trap cleanup EXIT INT TERM

# Extract embedded files
info "Extracting daemon script..."
extract_daemon_script "$TEMP_DAEMON"

info "Extracting init script..."
extract_init_script "$TEMP_INIT"

# Verify extracted files
if [ ! -s "$TEMP_DAEMON" ] || [ ! -s "$TEMP_INIT" ]; then
    error "Failed to extract embedded files"
fi

# Install daemon script
info "Installing daemon script to $DAEMON_PATH..."
install -m 755 "$TEMP_DAEMON" "$DAEMON_PATH"

# Install init script
info "Installing init script to $INIT_PATH..."
install -m 755 "$TEMP_INIT" "$INIT_PATH"

# Verify installation
if [ ! -f "$DAEMON_PATH" ] || [ ! -f "$INIT_PATH" ]; then
    error "Installation failed - files not created"
fi

info "Installation successful!"
info "  Daemon: $DAEMON_PATH"
info "  Init script: $INIT_PATH"

warn ""
warn "IMPORTANT: You must edit $DAEMON_PATH to configure:"
warn "  - NAS_HOST (DNS name or IP of your NAS)"
warn "  - NAS_MAC (MAC address of NAS for Wake-on-LAN)"
warn "  - LOCAL_MAC (MAC address of this client machine)"
warn "  - INTERFACE (network interface to monitor, e.g. eth0)"
warn ""

# Check if --enable flag was provided
ENABLE_SERVICE=0
for arg in "$@"; do
    case "$arg" in
        --enable)
            ENABLE_SERVICE=1
            ;;
    esac
done

# Optionally enable service
if [ "$ENABLE_SERVICE" -eq 1 ]; then
    info "Enabling service in default runlevel..."
    if rc-update add "$SERVICE_NAME" default; then
        info "Service enabled"
        
        warn "Configure NAS_HOST and NAS_MAC in $DAEMON_PATH before starting"
        printf "Start the service now? [y/N] "
        read -r response
        case "$response" in
            [yY]*)
                info "Starting service..."
                if rc-service "$SERVICE_NAME" start; then
                    info "Service started successfully"
                else
                    warn "Failed to start service (check: rc-service $SERVICE_NAME status)"
                fi
                ;;
            *)
                info "Service not started (start manually with: rc-service $SERVICE_NAME start)"
                ;;
        esac
    else
        warn "Failed to enable service"
    fi
else
    info ""
    info "Next steps:"
    info "  1. Edit $DAEMON_PATH to configure NAS_HOST and NAS_MAC"
    info "  2. Enable the service: rc-update add $SERVICE_NAME default"
    info "  3. Start the service: rc-service $SERVICE_NAME start"
fi

info ""
info "Installation complete!"
