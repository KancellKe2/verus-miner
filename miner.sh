#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/verus-miner"
CONFIG="/etc/verus-miner/config.env"
LOG_DIR="/var/log/verus-miner"
LOG_FILE="$LOG_DIR/miner.log"
MINER="$APP_DIR/ccminer"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

die() {
    log "ERROR: $*"
    exit 1
}

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

[[ -r "$CONFIG" ]] || die "Configuration not found: $CONFIG"
[[ -x "$MINER" ]] || die "Miner binary not found or not executable: $MINER"

# shellcheck disable=SC1090
source "$CONFIG"

: "${WALLET:?WALLET is required}"
: "${POOL:?POOL is required}"
: "${WORKER:?WORKER is required}"
: "${THREADS:?THREADS is required}"

PASSWORD="${PASSWORD:-x}"
NICE_LEVEL="${NICE_LEVEL:-10}"

[[ "$THREADS" =~ ^[0-9]+$ ]] || die "THREADS must be a positive integer."
(( THREADS > 0 )) || die "THREADS must be greater than zero."

if ! [[ "$NICE_LEVEL" =~ ^-?[0-9]+$ ]]; then
    NICE_LEVEL=10
fi

# Prevent accidental shell option injection through configuration values.
case "$WALLET$POOL$WORKER$PASSWORD" in
    *$'\n'*|*$'\r'*)
        die "Configuration contains an invalid newline."
        ;;
esac

cd "$APP_DIR"

log "============================================"
log "Starting Verus Miner"
log "Architecture : $(uname -m)"
log "CPU threads  : $(nproc)"
log "Mining threads: $THREADS"
log "Worker       : $WORKER"
log "Pool         : $POOL"
log "CPU priority : nice $NICE_LEVEL"
log "============================================"

# Run through nice so the miner has lower CPU scheduling priority.
# The service itself also applies systemd CPUWeight/Nice limits.
exec nice -n "$NICE_LEVEL" \
    "$MINER" \
        -a verus \
        -o "$POOL" \
        -u "${WALLET}.${WORKER}" \
        -p "$PASSWORD" \
        -t "$THREADS" \
        2>&1 | tee -a "$LOG_FILE"
