#!/bin/sh
# Start provider using existing JWT on disk (no re-authentication)

set -e

APP_DIR="/app"
JWT_FILE="/root/.urnetwork/jwt"
ENABLE_VNSTAT="${ENABLE_VNSTAT:-true}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') >>> UrNetwork >>> $*"; }

func_get_architecture() {
    case "$(uname -m)" in
      x86_64)  A_SYS_ARCH=amd64 ;;
      aarch64) A_SYS_ARCH=arm64 ;;
      *) log "[ERROR] Unsupported arch: $(uname -m)" >&2; exit 1 ;;
    esac
}

func_check_jwt() {
    if [ ! -s "$JWT_FILE" ]; then
        log "[ERROR] No JWT found at $JWT_FILE"
        log "[ERROR] Run: urnetwork auth <auth_code> -f on the host, then mount ~/.urnetwork"
        exit 1
    fi
    log "[INFO] JWT found at $JWT_FILE"
}

func_check_proxy() {
    rm -f ~/.urnetwork/proxy || true
    if [ -f "/app/proxy.txt" ]; then
        log "[INFO] proxy.txt found; adding proxy"
        PROVIDER_BIN="$APP_DIR/urnetwork_${A_SYS_ARCH}_stable"
        "$PROVIDER_BIN" proxy add --proxy_file="/app/proxy.txt"
    else
        log "[INFO] No proxy.txt; skipping proxy"
    fi
}

func_start_vnstat() {
    VNSTAT_LC="$(printf '%s' "$ENABLE_VNSTAT" | tr '[:upper:]' '[:lower:]')"
    if [ "$VNSTAT_LC" = "true" ]; then
        if [ ! -f /var/lib/vnstat/vnstat.db ] && [ ! -f /var/lib/vnstat/.config ]; then
            vnstatd --initdb
        fi
        vnstatd -d --alwaysadd >/dev/null 2>&1
        log "[INFO] vnstatd started"
        httpd -f -p 8080 -h /app &
        log "[INFO] HTTP server started on port 8080"
    fi
}

func_start_provider() {
    PROVIDER_BIN="$APP_DIR/urnetwork_${A_SYS_ARCH}_stable"
    BIN_VER="$($PROVIDER_BIN --version)"
    log "[INFO] Running URnetwork build v${BIN_VER}"
    exec "$PROVIDER_BIN" provide
}

func_get_architecture
func_check_jwt
func_check_proxy
func_start_vnstat
func_start_provider
