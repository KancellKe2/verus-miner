#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/verus-miner/config.env"
SERVICE="verus-miner"
MINER="/opt/verus-miner/ccminer"
LOG_FILE="/var/log/verus-miner/miner.log"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

get_config() {
    local key="$1"
    if [[ -r "$CONFIG" ]]; then
        awk -F= -v k="$key" '$1 == k {sub(/^[^=]*=/, ""); print; exit}' "$CONFIG"
    fi
}

format_uptime() {
    local seconds="${1:-0}"
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))

    if (( days > 0 )); then
        printf '%dd %02dh %02dm' "$days" "$hours" "$minutes"
    elif (( hours > 0 )); then
        printf '%02dh %02dm' "$hours" "$minutes"
    else
        printf '%02dm' "$minutes"
    fi
}

echo
echo "╔══════════════════════════════════════════════════╗"
echo "║                 ⛏️  VERUS MINER                  ║"
echo "║                    STATUS                        ║"
echo "╚══════════════════════════════════════════════════╝"
echo

if systemctl is-active --quiet "$SERVICE"; then
    STATUS="RUNNING"
else
    STATUS="STOPPED"
fi

ARCH="$(uname -m)"
CPU_COUNT="$(nproc 2>/dev/null || echo "?")"
THREADS="$(get_config THREADS)"
WORKER="$(get_config WORKER)"
POOL="$(get_config POOL)"

PID=""
if command_exists systemctl; then
    PID="$(systemctl show -p MainPID --value "$SERVICE" 2>/dev/null || true)"
fi

[[ "$PID" == "0" ]] && PID=""

CPU_USAGE=""
if [[ -n "$PID" ]] && [[ "$PID" =~ ^[0-9]+$ ]] && command_exists ps; then
    if ps -p "$PID" >/dev/null 2>&1; then
        CPU_USAGE="$(ps -p "$PID" -o %cpu= | xargs)"
    fi
fi

UPTIME_SECONDS=0
if command_exists systemctl; then
    ACTIVE_TS="$(systemctl show -p ActiveEnterTimestampMonotonic --value "$SERVICE" 2>/dev/null || true)"
    NOW_MONO="$(awk '{print $1 * 1000000}' /proc/uptime 2>/dev/null || echo 0)"

    if [[ "$ACTIVE_TS" =~ ^[0-9]+$ ]] && [[ "$NOW_MONO" =~ ^[0-9]+$ ]]; then
        # systemd monotonic timestamps are microseconds.
        UPTIME_SECONDS=$(( (NOW_MONO - ACTIVE_TS) / 1000000 ))
        (( UPTIME_SECONDS < 0 )) && UPTIME_SECONDS=0
    fi
fi

echo "╭──────────────────────────────────────────────────╮"
printf '│ Status       : %-34s │\n' "$STATUS"
printf '│ Architecture : %-34s │\n' "$ARCH"
printf '│ CPU threads  : %-34s │\n' "$CPU_COUNT"
printf '│ Mining threads: %-33s │\n' "${THREADS:-unknown}"
printf '│ Worker       : %-34s │\n' "${WORKER:-unknown}"
printf '│ PID          : %-34s │\n' "${PID:-unknown}"
printf '│ CPU usage    : %-34s │\n' "${CPU_USAGE:-unknown}"
printf '│ Uptime       : %-34s │\n' "$(format_uptime "$UPTIME_SECONDS")"
echo "╰──────────────────────────────────────────────────╯"

echo
echo "Pool:"
echo "  ${POOL:-unknown}"

echo
echo "Miner:"
if [[ -x "$MINER" ]]; then
    echo "  ✓ $MINER"
else
    echo "  ✗ Miner binary not found"
fi

echo
echo "Configuration:"
if [[ -f "$CONFIG" ]]; then
    echo "  ✓ $CONFIG"
else
    echo "  ✗ Configuration not found"
fi

echo
echo "Recent miner output:"
echo "────────────────────────────────────────────────────"

if [[ -f "$LOG_FILE" ]]; then
    tail -n 15 "$LOG_FILE"
else
    echo "No miner log available yet."
fi

echo "────────────────────────────────────────────────────"

echo
echo "Service commands:"
echo "  Start   : sudo systemctl start $SERVICE"
echo "  Stop    : sudo systemctl stop $SERVICE"
echo "  Restart : sudo systemctl restart $SERVICE"
echo "  Logs    : sudo journalctl -u $SERVICE -f"
echo
