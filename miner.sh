#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/verus-miner"
CONFIG="/etc/verus-miner/config.env"
LOG_DIR="/var/log/verus-miner"
LOG_FILE="$LOG_DIR/miner.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

if [[ ! -r "$CONFIG" ]]; then
  echo "Missing configuration: $CONFIG" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG"

: "${WALLET:?WALLET is required}"
: "${POOL:?POOL is required}"
: "${WORKER:?WORKER is required}"
: "${THREADS:?THREADS is required}"
: "${PASSWORD:=x}"

cd "$APP_DIR"

echo "[$(date '+%F %T')] Starting Verus miner: worker=$WORKER threads=$THREADS pool=$POOL" | tee -a "$LOG_FILE"

exec "$APP_DIR/ccminer" \
  -a verus \
  -o "$POOL" \
  -u "${WALLET}.${WORKER}" \
  -p "$PASSWORD" \
  -t "$THREADS" \
  2>&1 | tee -a "$LOG_FILE"
