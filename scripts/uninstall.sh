#!/bin/sh
# URnetwork provider test build uninstaller

set -e

INSTALL_DIR="$HOME/.local/share/urnetwork-provider-test"
SERVICE_NAME="urnetwork-test"

log() { printf '[uninstall] %s\n' "$*"; }

if command -v systemctl >/dev/null 2>&1; then
    service_file="$HOME/.config/systemd/user/${SERVICE_NAME}.service"
    if [ -f "$service_file" ]; then
        log "Stopping and disabling service"
        systemctl --user disable --now "${SERVICE_NAME}.service" 2>/dev/null || true
        rm -f "$service_file"
        systemctl --user daemon-reload
    fi
fi

if [ -d "$INSTALL_DIR" ]; then
    log "Removing $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
fi

rm -rf "$HOME/.urnetwork"

log "Uninstall complete."
