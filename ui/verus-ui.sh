#!/usr/bin/env bash

ui_setup() {
    if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
        UI_RESET=$'\033[0m'
        UI_BOLD=$'\033[1m'
        UI_DIM=$'\033[2m'
        UI_CYAN=$'\033[36m'
        UI_GREEN=$'\033[32m'
        UI_YELLOW=$'\033[33m'
        UI_RED=$'\033[31m'
    else
        UI_RESET=""
        UI_BOLD=""
        UI_DIM=""
        UI_CYAN=""
        UI_GREEN=""
        UI_YELLOW=""
        UI_RED=""
    fi
}

ui_setup

ui_header() {
    local subtitle="${1:-VERUSHASH CPU MINER}"

    echo
    printf '%b╭──────────────────────────────────────────────╮%b\n' \
        "$UI_CYAN" "$UI_RESET"
    printf '%b│                                              │%b\n' \
        "$UI_CYAN" "$UI_RESET"
    printf '%b│       ██╗   ██╗██████╗ ███████╗             │%b\n' \
        "$UI_CYAN$UI_BOLD" "$UI_RESET"
    printf '%b│       ██║   ██║██╔══██╗██╔════╝             │%b\n' \
        "$UI_CYAN$UI_BOLD" "$UI_RESET"
    printf '%b│       ██║   ██║██████╔╝█████╗               │%b\n' \
        "$UI_CYAN$UI_BOLD" "$UI_RESET"
    printf '%b│       ╚██╗ ██╔╝██╔══██╗██╔══╝               │%b\n' \
        "$UI_CYAN$UI_BOLD" "$UI_RESET"
    printf '%b│        ╚████╔╝ ██║  ██║███████╗             │%b\n' \
        "$UI_CYAN$UI_BOLD" "$UI_RESET"
    printf '%b│         ╚═══╝  ╚═╝  ╚═╝╚══════╝             │%b\n' \
        "$UI_CYAN$UI_BOLD" "$UI_RESET"
    printf '%b│                                              │%b\n' \
        "$UI_CYAN" "$UI_RESET"
    printf '%b╰──────────────────────────────────────────────╯%b\n' \
        "$UI_CYAN" "$UI_RESET"

    printf '  %b⛏ VERUS MINER%b %b• %s%b\n' \
        "$UI_BOLD" "$UI_RESET" "$UI_DIM" "$subtitle" "$UI_RESET"
    echo
}

ui_section() {
    printf '%b┌─ %s ───────────────────────────────────┐%b\n' \
        "$UI_CYAN$UI_BOLD" "$1" "$UI_RESET"
}

ui_row() {
    printf '│ %-15s : %-25s │\n' "$1" "$2"
}

ui_section_end() {
    printf '└─────────────────────────────────────────┘\n'
}

ui_status() {
    case "${1^^}" in
        RUNNING|ONLINE|PASS|OK)
            printf '%b● %s%b' \
                "$UI_GREEN$UI_BOLD" "${1^^}" "$UI_RESET"
            ;;
        STOPPED|OFFLINE|FAIL|ERROR)
            printf '%b● %s%b' \
                "$UI_RED$UI_BOLD" "${1^^}" "$UI_RESET"
            ;;
        *)
            printf '%b● %s%b' \
                "$UI_YELLOW$UI_BOLD" "${1^^}" "$UI_RESET"
            ;;
    esac
}

ui_ok() {
    printf '%b✓%b %s\n' \
        "$UI_GREEN$UI_BOLD" "$UI_RESET" "$1"
}

ui_error() {
    printf '%b✗%b %s\n' \
        "$UI_RED$UI_BOLD" "$UI_RESET" "$1"
}

ui_warn() {
    printf '%b!%b %s\n' \
        "$UI_YELLOW$UI_BOLD" "$UI_RESET" "$1"
}

ui_line() {
    printf '%b──────────────────────────────────────────────%b\n' \
        "$UI_DIM" "$UI_RESET"
}

ui_footer() {
    ui_line
    printf '  %bVerus Miner%b • Linux • ARM64 • x86_64\n' \
        "$UI_BOLD" "$UI_RESET"
    echo
}

ui_clear() {
    if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
        clear
    fi
}

ui_clear() {
    if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
        clear
    fi
}
