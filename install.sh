#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/verus-miner"
CONFIG_DIR="/etc/verus-miner"
CONFIG_FILE="$CONFIG_DIR/config.env"
SERVICE_FILE="/etc/systemd/system/verus-miner.service"

RELEASE="v3.8.3a-CPU"
BASE_URL="https://github.com/Oink70/ccminer-verus/releases/download/${RELEASE}"

# Add the published SHA256 values for the exact release assets
# before enabling mandatory checksum verification.
SHA256_ARM64=""
SHA256_X86_64=""

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

if [[ "${EUID}" -ne 0 ]]; then
    die "Run this installer with: sudo ./install.sh"
fi

echo
echo "╔════════════════════════════════════════════╗"
echo "║              ⛏️  VERUS MINER               ║"
echo "║              INSTALLER v2                  ║"
echo "╚════════════════════════════════════════════╝"
echo

for cmd in curl sha256sum install systemctl uname nproc; do
    require_command "$cmd"
done

ARCH="$(uname -m)"

case "$ARCH" in
    aarch64|arm64)
        ASSET="ccminer-v3.8.3c-oink_ARM"
        EXPECTED_SHA256="$SHA256_ARM64"
        ;;
    x86_64|amd64)
        ASSET="ccminer-v3.8.3a-oink_Ubuntu_18.04"
        EXPECTED_SHA256="$SHA256_X86_64"
        ;;
    *)
        die "Unsupported architecture: $ARCH"
        ;;
esac

DOWNLOAD_URL="${BASE_URL}/${ASSET}"

echo "╭────────────────────────────────────────────╮"
printf '│ Architecture : %-26s │\n' "$ARCH"
printf '│ CPU threads  : %-26s │\n' "$(nproc)"
printf '│ Miner asset  : %-26s │\n' "$ASSET"
printf '│ Release      : %-26s │\n' "$RELEASE"
echo "╰────────────────────────────────────────────╯"
echo

mkdir -p "$APP_DIR" "$CONFIG_DIR"
chmod 755 "$APP_DIR"
chmod 700 "$CONFIG_DIR"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "=== Mining configuration ==="
    echo

    read -r -p "VRSC wallet address: " WALLET
    [[ -n "$WALLET" ]] || die "Wallet address cannot be empty."

    read -r -p "Pool [stratum+tcp://pool.verus.io:9999]: " POOL
    POOL="${POOL:-stratum+tcp://pool.verus.io:9999}"

    read -r -p "Worker [worker-01]: " WORKER
    WORKER="${WORKER:-worker-01}"

    CPU_COUNT="$(nproc)"
    if (( CPU_COUNT > 4 )); then
        DEFAULT_THREADS=4
    else
        DEFAULT_THREADS="$CPU_COUNT"
    fi

    read -r -p "CPU threads [$DEFAULT_THREADS]: " THREADS
    THREADS="${THREADS:-$DEFAULT_THREADS}"

    [[ "$THREADS" =~ ^[0-9]+$ ]] || die "THREADS must be a positive integer."
    (( THREADS >= 1 )) || die "THREADS must be at least 1."
    (( THREADS <= CPU_COUNT )) || die "THREADS cannot exceed available CPU threads ($CPU_COUNT)."

    read -r -p "Pool password [x]: " PASSWORD
    PASSWORD="${PASSWORD:-x}"

    cat > "$CONFIG_FILE" <<EOF
# Verus Miner configuration
# Keep this file private.

WALLET=$WALLET
POOL=$POOL
WORKER=$WORKER
THREADS=$THREADS
PASSWORD=$PASSWORD
NICE_LEVEL=10
EOF

    chmod 600 "$CONFIG_FILE"
    echo
    log "Configuration saved to $CONFIG_FILE"
else
    log "Existing configuration detected."
fi

TMP_FILE="$APP_DIR/ccminer.download"
MINER="$APP_DIR/ccminer"

echo
log "Downloading CCminer..."
echo "URL: $DOWNLOAD_URL"
echo

rm -f "$TMP_FILE"

curl \
    --fail \
    --location \
    --show-error \
    --retry 3 \
    --retry-delay 2 \
    --connect-timeout 15 \
    --max-time 600 \
    "$DOWNLOAD_URL" \
    --output "$TMP_FILE" || die "Miner download failed."

[[ -s "$TMP_FILE" ]] || die "Downloaded miner is empty."

chmod 755 "$TMP_FILE"

if [[ -n "$EXPECTED_SHA256" ]]; then
    log "Verifying SHA256..."
    ACTUAL_SHA256="$(sha256sum "$TMP_FILE" | awk '{print $1}')"

    if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
        rm -f "$TMP_FILE"
        die "SHA256 verification failed."
    fi

    log "SHA256 verification passed."
else
    log "SHA256 value not configured for this asset."
    log "Download completed, but checksum verification was skipped."
fi

mv "$TMP_FILE" "$MINER"
chmod 755 "$MINER"

log "Testing miner binary..."
if ! "$MINER" --help >/dev/null 2>&1; then
    [[ -x "$MINER" ]] || die "Miner binary is not executable."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for script in miner.sh start.sh stop.sh restart.sh status.sh; do
    [[ -f "$SCRIPT_DIR/$script" ]] || die "Missing project file: $script"
    install -m 0755 "$SCRIPT_DIR/$script" "$APP_DIR/$script"
done

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Verus CPU Miner
Documentation=https://docs.verus.io/economy/start-mining.html
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/miner.sh
Restart=on-failure
RestartSec=15
KillSignal=SIGINT
TimeoutStopSec=30
LimitNOFILE=65536
Nice=10
CPUWeight=50

[Install]
WantedBy=multi-user.target
EOF

log "Reloading systemd..."
systemctl daemon-reload

log "Enabling verus-miner service..."
systemctl enable verus-miner

echo
echo "╭────────────────────────────────────────────╮"
echo "│          VERUS MINER INSTALLED             │"
echo "├────────────────────────────────────────────┤"
printf '│ Architecture : %-26s │\n' "$ARCH"
printf '│ Threads      : %-26s │\n' "$(grep '^THREADS=' "$CONFIG_FILE" | cut -d= -f2)"
printf '│ Config       : %-26s │\n' "$CONFIG_FILE"
printf '│ Binary       : %-26s │\n' "$MINER"
printf '│ Service      : %-26s │\n' "verus-miner"
echo "╰────────────────────────────────────────────╯"
echo
echo "Installation complete."
echo
echo "Start:"
echo "  sudo systemctl start verus-miner"
echo
echo "Status:"
echo "  sudo systemctl status verus-miner"
echo
echo "Logs:"
echo "  sudo journalctl -u verus-miner -f"
echo
echo "IMPORTANT: The miner is NOT started automatically."
