.PHONY: all clean suspend-installer wakeup-installer

# NFS Idle Suspend (for NAS server)
SUSPEND_INSTALLER = nfs-idle-suspend-installer.sh
SUSPEND_DAEMON = nfs-idle-suspend.sh
SUSPEND_INIT = nfs-idle-suspend.initd

# NAS Wake Monitor (for NFS client)
WAKEUP_INSTALLER = nas-wake-installer.sh
WAKEUP_DAEMON = nas-wake-monitor.sh
WAKEUP_INIT = nas-wake-monitor.initd

all: $(SUSPEND_INSTALLER) $(WAKEUP_INSTALLER)

suspend-installer: $(SUSPEND_INSTALLER)

wakeup-installer: $(WAKEUP_INSTALLER)

$(SUSPEND_INSTALLER): $(SUSPEND_DAEMON) $(SUSPEND_INIT) installer-header.sh installer-footer.sh Makefile
	@echo "Generating NFS idle suspend installer..."
	@cat installer-header.sh > $(SUSPEND_INSTALLER)
	@echo "" >> $(SUSPEND_INSTALLER)
	@echo "# Embedded daemon script" >> $(SUSPEND_INSTALLER)
	@echo "extract_daemon_script() {" >> $(SUSPEND_INSTALLER)
	@echo "cat > \"\$$1\" << 'DAEMON_SCRIPT_EOF'" >> $(SUSPEND_INSTALLER)
	@cat $(SUSPEND_DAEMON) >> $(SUSPEND_INSTALLER)
	@echo "DAEMON_SCRIPT_EOF" >> $(SUSPEND_INSTALLER)
	@echo "}" >> $(SUSPEND_INSTALLER)
	@echo "" >> $(SUSPEND_INSTALLER)
	@echo "# Embedded init script" >> $(SUSPEND_INSTALLER)
	@echo "extract_init_script() {" >> $(SUSPEND_INSTALLER)
	@echo "cat > \"\$$1\" << 'INIT_SCRIPT_EOF'" >> $(SUSPEND_INSTALLER)
	@cat $(SUSPEND_INIT) >> $(SUSPEND_INSTALLER)
	@echo "INIT_SCRIPT_EOF" >> $(SUSPEND_INSTALLER)
	@echo "}" >> $(SUSPEND_INSTALLER)
	@echo "" >> $(SUSPEND_INSTALLER)
	@cat installer-footer.sh >> $(SUSPEND_INSTALLER)
	@chmod +x $(SUSPEND_INSTALLER)
	@echo "Suspend installer created: $(SUSPEND_INSTALLER)"
	@echo "Size: $$(wc -c < $(SUSPEND_INSTALLER)) bytes"

$(WAKEUP_INSTALLER): $(WAKEUP_DAEMON) $(WAKEUP_INIT) nas-wake-installer-header.sh nas-wake-installer-footer.sh Makefile
	@echo "Generating NAS wake monitor installer..."
	@cat nas-wake-installer-header.sh > $(WAKEUP_INSTALLER)
	@echo "" >> $(WAKEUP_INSTALLER)
	@echo "# Embedded daemon script" >> $(WAKEUP_INSTALLER)
	@echo "extract_daemon_script() {" >> $(WAKEUP_INSTALLER)
	@echo "cat > \"\$$1\" << 'DAEMON_SCRIPT_EOF'" >> $(WAKEUP_INSTALLER)
	@cat $(WAKEUP_DAEMON) >> $(WAKEUP_INSTALLER)
	@echo "DAEMON_SCRIPT_EOF" >> $(WAKEUP_INSTALLER)
	@echo "}" >> $(WAKEUP_INSTALLER)
	@echo "" >> $(WAKEUP_INSTALLER)
	@echo "# Embedded init script" >> $(WAKEUP_INSTALLER)
	@echo "extract_init_script() {" >> $(WAKEUP_INSTALLER)
	@echo "cat > \"\$$1\" << 'INIT_SCRIPT_EOF'" >> $(WAKEUP_INSTALLER)
	@cat $(WAKEUP_INIT) >> $(WAKEUP_INSTALLER)
	@echo "INIT_SCRIPT_EOF" >> $(WAKEUP_INSTALLER)
	@echo "}" >> $(WAKEUP_INSTALLER)
	@echo "" >> $(WAKEUP_INSTALLER)
	@cat nas-wake-installer-footer.sh >> $(WAKEUP_INSTALLER)
	@chmod +x $(WAKEUP_INSTALLER)
	@echo "Wakeup installer created: $(WAKEUP_INSTALLER)"
	@echo "Size: $$(wc -c < $(WAKEUP_INSTALLER)) bytes"

clean:
	rm -f $(SUSPEND_INSTALLER) $(WAKEUP_INSTALLER)
