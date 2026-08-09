#!/usr/bin/env bash
set -e

echo "╔════════════════════════════════════════════╗"
echo "║              ⛏️  VERUS MINER              ║"
echo "╚════════════════════════════════════════════╝"
echo

if systemctl is-active --quiet verus-miner; then
  echo "Status     : RUNNING"
else
  echo "Status     : STOPPED"
fi

echo "Architecture: $(uname -m)"
echo "CPU threads : $(nproc)"
echo
systemctl --no-pager --full status verus-miner || true
echo
echo "Recent miner output:"
journalctl -u verus-miner -n 15 --no-pager || true
