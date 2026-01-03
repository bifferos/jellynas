.PHONY: all clean suspend-installer wakeup-installer

# NFS Idle Suspend (for NAS server)
SUSPEND_INSTALLER = nfs-idle-suspend-installer.sh
SUSPEND_DAEMON = nfs-idle-suspend.sh
SUSPEND_INIT = nfs-idle-suspend.initd

# NFS Wakeup Monitor (for NFS client)
WAKEUP_INSTALLER = nfs-wakeup-installer.sh
WAKEUP_DAEMON = nfs-wakeup-monitor.sh
WASUSPEND_INSTALLER): $(SUSPEND_DAEMON) $(SUSPEND_INIT) installer-header.sh installer-footer.sh Makefile
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

$(WAKEUP_INSTALLER): $(WAKEUP_DAEMON) $(WAKEUP_INIT) wakeup-installer-header.sh wakeup-installer-footer.sh Makefile
	@echo "Generating NFS wakeup monitor installer..."
	@cat wakeup-installer-header.sh > $(WAKEUP_INSTALLER)
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
	@cat wakeup-installer-footer.sh >> $(WAKEUP_INSTALLER)
	@chmod +x $(WAKEUP_INSTALLER)
	@echo "Wakeup installer created: $(WAKEUP_INSTALLER)"
	@echo "Size: $$(wc -c < $(WAKEUP_INSTALLER)) bytes"

clean:
	rm -f $(SUSPEND_INSTALLER) $(WAKEUP_" >> $(INSTALLER)
	@echo "" >> $(INSTALLER)
	@cat installer-footer.sh >> $(INSTALLER)
	@chmod +x $(INSTALLER)
	@echo "Installer created: $(INSTALLER)"
	@echo "Size: $$(wc -c < $(INSTALLER)) bytes"

clean:
	rm -f $(INSTALLER)
