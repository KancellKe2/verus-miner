#!/usr/bin/env bash
set -u

APP_DIR="/opt/verus-miner"
CONFIG="/etc/verus-miner/config.env"
SERVICE="verus-miner"
MINER="$APP_DIR/ccminer"
LOG_FILE="/var/log/verus-miner/miner.log"
UI="$APP_DIR/ui/verus-ui.sh"

if [[ -r "$UI" ]]; then
    # shellcheck disable=SC1090
    source "$UI"
else
    echo "ERROR: UI library not found: $UI"
    exit 1
fi

get_config() {
    local key="$1"

    [[ -r "$CONFIG" ]] || return 0

    awk -F= -v k="$key" '$1 == k {
        sub(/^[^=]*=/, "")
        print
        exit
    }' "$CONFIG"
}

format_uptime() {
    local seconds="${1:-0}"

    (( seconds < 0 )) && seconds=0

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

get_cpu_usage() {
    local pid="$1"

    if [[ -n "$pid" ]] &&
       [[ "$pid" =~ ^[0-9]+$ ]] &&
       ps -p "$pid" >/dev/null 2>&1; then
        ps -p "$pid" -o %cpu= | xargs
    else
        echo "0%"
    fi
}

get_uptime() {
    local pid="$1"

    if [[ -n "$pid" ]] &&
       [[ "$pid" =~ ^[0-9]+$ ]] &&
       [[ -r "/proc/$pid/stat" ]]; then

        local start_ticks
        local uptime
        local hz

        start_ticks="$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || echo 0)"
        hz="$(getconf CLK_TCK 2>/dev/null || echo 100)"
        uptime="$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)"

        if [[ "$start_ticks" =~ ^[0-9]+$ ]] &&
           [[ "$hz" =~ ^[0-9]+$ ]] &&
           [[ "$uptime" =~ ^[0-9]+$ ]] &&
           (( hz > 0 )); then

            local process_start=$((start_ticks / hz))
            local seconds=$((uptime - process_start))

            format_uptime "$seconds"
            return
        fi
    fi

    echo "—"
}

get_hashrate() {
    local result=""

    if [[ -f "$LOG_FILE" ]]; then
        result="$(
            grep -Eio \
                '[0-9]+([.][0-9]+)?[[:space:]]*(KH/s|MH/s|GH/s|H/s)' \
                "$LOG_FILE" 2>/dev/null |
            tail -n 1 |
            xargs
        )"
    fi

    if [[ -n "$result" ]]; then
        echo "$result"
    else
        echo "Waiting..."
    fi
}

get_pool_display() {
    local pool="$1"

    pool="${pool#stratum+tcp://}"
    pool="${pool#stratum+ssl://}"
    echo "$pool"
}

# ----------------------------------------------------
# Collect data
# ----------------------------------------------------

ARCH="$(uname -m)"
CPU_COUNT="$(nproc 2>/dev/null || echo "?")"

THREADS="$(get_config THREADS)"
WORKER="$(get_config WORKER)"
POOL="$(get_config POOL)"

[[ -n "$THREADS" ]] || THREADS="—"
[[ -n "$WORKER" ]] || WORKER="—"
[[ -n "$POOL" ]] || POOL="—"

POOL_DISPLAY="$(get_pool_display "$POOL")"

if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
    STATE="RUNNING"
else
    STATE="STOPPED"
fi

PID="$(systemctl show -p MainPID --value "$SERVICE" 2>/dev/null || true)"

if [[ "$PID" == "0" ]]; then
    PID=""
fi

if [[ "$STATE" == "RUNNING" ]]; then
    CPU_USAGE="$(get_cpu_usage "$PID")"
    SERVICE_UPTIME="$(get_uptime "$PID")"
    HASHRATE="$(get_hashrate)"
else
    CPU_USAGE="0%"
    SERVICE_UPTIME="—"
    HASHRATE="—"
fi

# ----------------------------------------------------
# Dashboard
# ----------------------------------------------------

ui_clear
ui_header "MINING DASHBOARD"

ui_section "SYSTEM"
ui_row "Architecture" "$ARCH"
ui_row "CPU" "$CPU_COUNT cores"
ui_row "Threads" "$THREADS"
ui_row "CPU usage" "$CPU_USAGE"
ui_row "Uptime" "$SERVICE_UPTIME"
ui_section_end

echo

ui_section "MINING"

printf '│ %-15s : ' "Status"
ui_status "$STATE"
printf ' %*s│\n' 18 ''

ui_row "Worker" "$WORKER"
ui_row "Algorithm" "VerusHash"
ui_row "Hashrate" "$HASHRATE"
ui_row "Pool" "$POOL_DISPLAY"
ui_row "PID" "${PID:-—}"

ui_section_end

echo

if [[ "$STATE" == "RUNNING" ]]; then
    ui_ok "Verus miner is running"
else
    ui_warn "Verus miner is stopped"
fi

ui_footer
