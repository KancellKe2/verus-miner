#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run: sudo ./uninstall.sh"
  exit 1
fi

systemctl disable --now verus-miner 2>/dev/null || true
rm -f /etc/systemd/system/verus-miner.service
systemctl daemon-reload
rm -rf /opt/verus-miner
rm -rf /etc/verus-miner
rm -rf /var/log/verus-miner

echo "Verus miner removed."
