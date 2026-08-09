#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/verus-miner"
CONFIG_DIR="/etc/verus-miner"
CONFIG_FILE="$CONFIG_DIR/config.env"
SERVICE_FILE="/etc/systemd/system/verus-miner.service"

RELEASE="v3.8.3a-CPU"
BASE_URL="https://github.com/Oink70/ccminer-verus/releases/download/${RELEASE}"

# Published SHA256 values should be added here after confirming the
# exact release assets. Leaving them empty disables checksum verification.
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

# ------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Create directories
# ------------------------------------------------------------

mkdir -p "$APP_DIR"
mkdir -p "$CONFIG_DIR"

chmod 755 "$APP_DIR"
chmod 700 "$CONFIG_DIR"

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

if [[ ! -f "$CONFIG_FILE" ]]; then

    echo "=== Mining configuration ==="
    echo

    read -r -p "VRSC wallet address: " WALLET
    [[ -n "$WALLET" ]] || die "Wallet address cannot be empty."

    read -r -p \
        "Pool [stratum+tcp://pool.verus.io:9999]: " POOL
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

    [[ "$THREADS" =~ ^[0-9]+$ ]] ||
        die "THREADS must be a positive integer."

    (( THREADS >= 1 )) ||
        die "THREADS must be at least 1."

    (( THREADS <= CPU_COUNT )) ||
        die "THREADS cannot exceed available CPU threads ($CPU_COUNT)."

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

# Lower CPU priority so other services remain responsive.
NICE_LEVEL=10
EOF

    chmod 600 "$CONFIG_FILE"

    echo
    log "Configuration saved to $CONFIG_FILE"

else

    log "Existing configuration detected."
fi

# ------------------------------------------------------------
# Download miner
# ------------------------------------------------------------

TMP_FILE="$APP_DIR/ccminer.download"
MINER="$APP_DIR/ccminer"

echo
