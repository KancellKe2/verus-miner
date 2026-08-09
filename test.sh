#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT" || exit 1

PASS=0
FAIL=0
SKIP=0

ok() {
    printf '  [✓] %s\n' "$1"
    PASS=$((PASS + 1))
}

fail() {
    printf '  [✗] %s\n' "$1"
    FAIL=$((FAIL + 1))
}

skip() {
    printf '  [-] %s\n' "$1"
    SKIP=$((SKIP + 1))
}

check_command() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "command: $cmd"
    else
        fail "command missing: $cmd"
    fi
}

check_script() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        fail "missing: $file"
        return
    fi

    if bash -n "$file"; then
        ok "syntax: $file"
    else
        fail "syntax: $file"
    fi
}

echo
echo "╔════════════════════════════════════════════╗"
echo "║       ⛏️  VERUS MINER TEST SUITE          ║"
echo "╚════════════════════════════════════════════╝"
echo

echo "== Environment =="
printf '  Architecture : %s\n' "$(uname -m)"
printf '  CPU threads  : %s\n' "$(nproc 2>/dev/null || echo '?')"
printf '  OS           : %s\n' "$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')"
echo

echo "== Required commands =="
for cmd in bash curl sha256sum awk sed grep install; do
    check_command "$cmd"
done

echo
echo "== Project scripts =="

for file in install.sh miner.sh start.sh stop.sh restart.sh status.sh uninstall.sh; do
    check_script "$file"
done

echo
echo "== Configuration =="

if [[ -f config.env.example ]]; then
    if grep -q '^WALLET=' config.env.example &&
       grep -q '^POOL=' config.env.example &&
       grep -q '^WORKER=' config.env.example &&
       grep -q '^THREADS=' config.env.example; then
        ok "config.env.example contains required fields"
    else
        fail "config.env.example is missing required fields"
    fi
else
    fail "config.env.example missing"
fi

echo
echo "== systemd unit =="

if [[ -f systemd/verus-miner.service ]]; then
    if grep -q '^ExecStart=/opt/verus-miner/miner.sh$' systemd/verus-miner.service &&
       grep -q '^Restart=on-failure$' systemd/verus-miner.service &&
       grep -q '^Nice=10$' systemd/verus-miner.service; then
        ok "systemd unit contains expected settings"
    else
        fail "systemd unit validation failed"
    fi
else
    fail "systemd/verus-miner.service missing"
fi

if command -v systemd-analyze >/dev/null 2>&1; then
    if systemd-analyze verify systemd/verus-miner.service 2>/dev/null; then
        ok "systemd-analyze verify"
    else
        fail "systemd-analyze verify"
    fi
else
    skip "systemd-analyze unavailable in Codespace"
fi

echo
echo "== Repository safety checks =="

if grep -RInE 'sk-[A-Za-z0-9_-]{20,}|-----BEGIN (RSA|OPENSSH|EC|PRIVATE) KEY-----' \
    --exclude-dir=.git . >/dev/null 2>&1; then
    fail "possible secret detected"
else
    ok "no obvious API/private-key secret detected"
fi

if grep -RInE 'curl[^|;&]*\|[[:space:]]*(bash|sh)|wget[^|;&]*\|[[:space:]]*(bash|sh)' \
    --exclude-dir=.git . >/dev/null 2>&1; then
    fail "pipe-to-shell installer pattern detected"
else
    ok "no pipe-to-shell installer pattern detected"
fi

echo
echo "╔════════════════════════════════════════════╗"
printf '║ PASS : %-34s ║\n' "$PASS"
printf '║ FAIL : %-34s ║\n' "$FAIL"
printf '║ SKIP : %-34s ║\n' "$SKIP"
echo "╚════════════════════════════════════════════╝"

if (( FAIL > 0 )); then
    exit 1
fi

exit 0
