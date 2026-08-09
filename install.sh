#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/verus-miner"
CONFIG_DIR="/etc/verus-miner"
CONFIG_FILE="$CONFIG_DIR/config.env"
SERVICE_FILE="/etc/systemd/system/verus-miner.service"
RELEASE="v3.8.3a-CPU"
BASE_URL="https://github.com/Oink70/ccminer-verus/releases/download/${RELEASE}"

need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run: sudo ./install.sh"
    exit 1
  fi
}

need_root

echo "╔════════════════════════════════════════════╗"
echo "║              ⛏️  VERUS MINER               ║"
echo "║              INSTALLER                     ║"
echo "╚════════════════════════════════════════════╝"
echo

ARCH="$(uname -m)"
case "$ARCH" in
  aarch64|arm64)
    ASSET="ccminer-v3.8.3c-oink_ARM"
    ;;
  x86_64|amd64)
    ASSET="ccminer-v3.8.3a-oink_Ubuntu_18.04"
    ;;
  *)
    echo "[ERROR] Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "[✓] Architecture : $ARCH"
echo "[✓] Miner asset   : $ASSET"

mkdir -p "$APP_DIR" "$CONFIG_DIR"

if [[ ! -f "$CONFIG_FILE" ]]; then
  read -r -p "VRSC wallet address: " WALLET
  read -r -p "Pool [stratum+tcp://pool.verus.io:9999]: " POOL
  POOL="${POOL:-stratum+tcp://pool.verus.io:9999}"
  read -r -p "Worker [worker-01]: " WORKER
  WORKER="${WORKER:-worker-01}"
  DEFAULT_THREADS="$(nproc)"
  if (( DEFAULT_THREADS > 4 )); then DEFAULT_THREADS=4; fi
  read -r -p "CPU threads [$DEFAULT_THREADS]: " THREADS
  THREADS="${THREADS:-$DEFAULT_THREADS}"
  read -r -p "Pool password [x]: " PASSWORD
  PASSWORD="${PASSWORD:-x}"

  cat > "$CONFIG_FILE" <<EOF
WALLET=$WALLET
POOL=$POOL
WORKER=$WORKER
THREADS=$THREADS
PASSWORD=$PASSWORD
EOF
  chmod 600 "$CONFIG_FILE"
fi

echo "[1/3] Downloading CCminer..."
TMP="$APP_DIR/ccminer.download"
curl -fL --retry 3 --connect-timeout 15 \
  "$BASE_URL/$ASSET" -o "$TMP"
chmod +x "$TMP"
mv "$TMP" "$APP_DIR/ccminer"

echo "[2/3] Installing launcher..."
install -m 0755 miner.sh start.sh stop.sh restart.sh status.sh "$APP_DIR/"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Verus CPU Miner
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/miner.sh
Restart=always
RestartSec=10
KillSignal=SIGINT
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "[3/3] Enabling systemd service..."
systemctl daemon-reload
systemctl enable verus-miner

echo
echo "╭────────────────────────────────────────────╮"
echo "│          VERUS MINER INSTALLED             │"
echo "├────────────────────────────────────────────┤"
echo "│ Config : /etc/verus-miner/config.env       │"
echo "│ Binary : /opt/verus-miner/ccminer          │"
echo "│ Service: verus-miner                       │"
echo "╰────────────────────────────────────────────╯"
echo
echo "Start:  sudo systemctl start verus-miner"
echo "Status: sudo ./status.sh"
