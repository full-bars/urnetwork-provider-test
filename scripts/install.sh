#!/bin/sh
# URnetwork provider test build installer
# Based on urnetwork/connect PR#180 (outage log spam reduction)
# Repo: https://github.com/full-bars/urnetwork-provider-test

set -e

REPO="full-bars/urnetwork-provider-test"
INSTALL_DIR="$HOME/.local/share/urnetwork-provider-test"
BIN_DIR="$INSTALL_DIR/bin"
SERVICE_NAME="urnetwork-test"

log()  { printf '[install] %s\n' "$*"; }
err()  { printf '[install] ERROR: %s\n' "$*" >&2; exit 1; }

detect_arch() {
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *) err "Unsupported architecture: $(uname -m)" ;;
    esac
}

fetch_release_url() {
    arch="$1"
    api_url="https://api.github.com/repos/${REPO}/releases/tags/latest-build"
    pattern="urnetwork-provider-.*-linux-${arch}\.tar\.gz"

    if command -v curl >/dev/null 2>&1; then
        response="$(curl -fsSL "$api_url")"
    elif command -v wget >/dev/null 2>&1; then
        response="$(wget -qO- "$api_url")"
    else
        err "curl or wget is required"
    fi

    if command -v jq >/dev/null 2>&1; then
        echo "$response" | jq -r --arg arch "$arch" \
            '[.assets[] | select(.name | startswith("urnetwork-provider-") and endswith("-linux-\($arch).tar.gz"))] | last | .browser_download_url'
    elif command -v python3 >/dev/null 2>&1; then
        echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
arch = '$arch'
suffix = '-linux-' + arch + '.tar.gz'
matches = [a for a in data.get('assets', []) if a['name'].startswith('urnetwork-provider-') and a['name'].endswith(suffix)]
if matches:
    print(matches[-1]['browser_download_url'])
"
    else
        err "jq or python3 is required to parse the release"
    fi
}

install_binary() {
    arch="$(detect_arch)"
    log "Detected architecture: $arch"

    log "Fetching latest release..."
    dl_url="$(fetch_release_url "$arch")"
    [ -n "$dl_url" ] || err "Could not find release asset for arch: $arch"

    log "Downloading: $dl_url"
    mkdir -p "$BIN_DIR"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$dl_url" | tar -xz -C "$tmp"
    else
        wget -qO- "$dl_url" | tar -xz -C "$tmp"
    fi

    binary="$(find "$tmp" -name "urnetwork" -type f | head -1)"
    [ -n "$binary" ] || err "Binary not found in tarball"
    chmod +x "$binary"
    cp "$binary" "$BIN_DIR/urnetwork"
    log "Binary installed to $BIN_DIR/urnetwork"
}

install_service() {
    if ! command -v systemctl >/dev/null 2>&1; then
        log "systemd not found - skipping service installation"
        log "Run manually: $BIN_DIR/urnetwork provide"
        return
    fi

    service_dir="$HOME/.config/systemd/user"
    mkdir -p "$service_dir"

    cat > "$service_dir/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=URnetwork provider (test build - PR#180)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$BIN_DIR/urnetwork provide
Restart=on-failure
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    log "Service installed: ${SERVICE_NAME}.service"
    log ""
    log "Authenticate first:"
    log "  $BIN_DIR/urnetwork auth --user_auth=EMAIL --password=PASSWORD -f"
    log ""
    log "Then start:"
    log "  systemctl --user enable --now ${SERVICE_NAME}.service"
    log "  journalctl --user -u ${SERVICE_NAME}.service -f"
}

main() {
    log "Installing URnetwork provider test build (PR#180)"
    install_binary
    install_service
    log "Done."
}

main "$@"
