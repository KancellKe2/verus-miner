#!/usr/bin/env bash
set -euo pipefail

RELEASE="v3.8.3a-CPU"
BASE_URL="https://github.com/Oink70/ccminer-verus/releases/download/${RELEASE}"

SHA256_ARM64="7f900233711a153cb5099e77ccd9bf735b8cf9866c693a958946a0c8314a99c5"
SHA256_X86_64="bf7d1a01e88322991a824676601b46be7625b50a9d8ee8de085cc86ba76f7bc2"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

die() {
    echo "[FAIL] $*"
    exit 1
}

echo
echo "╔════════════════════════════════════════════╗"
echo "║       ⛏️  VERUS MINER BINARY TEST         ║"
echo "╚════════════════════════════════════════════╝"
echo

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64|amd64)
        ASSET="ccminer-v3.8.3a-oink_Ubuntu_18.04"
        EXPECTED="$SHA256_X86_64"
        ;;
    aarch64|arm64)
        ASSET="ccminer-v3.8.3c-oink_ARM"
        EXPECTED="$SHA256_ARM64"
        ;;
    *)
        die "Unsupported architecture: $ARCH"
        ;;
esac

URL="${BASE_URL}/${ASSET}"
BINARY="$TMP_DIR/ccminer"

echo "Architecture : $ARCH"
echo "Release      : $RELEASE"
echo "Asset        : $ASSET"
echo

echo "[1/4] Downloading official release asset..."
curl \
    --fail \
    --location \
    --show-error \
    --retry 3 \
    --connect-timeout 15 \
    --max-time 600 \
    "$URL" \
    --output "$BINARY" ||
    die "Download failed"

[[ -s "$BINARY" ]] || die "Downloaded file is empty"

echo "[2/4] Checking SHA256..."
ACTUAL="$(sha256sum "$BINARY" | awk '{print $1}')"

echo "Expected: $EXPECTED"
echo "Actual  : $ACTUAL"

[[ "$ACTUAL" == "$EXPECTED" ]] ||
    die "SHA256 mismatch"

echo "[3/4] Checking executable..."
chmod +x "$BINARY"
[[ -x "$BINARY" ]] || die "Binary is not executable"

if command -v file >/dev/null 2>&1; then
    file "$BINARY"
fi

echo "[4/4] Running non-mining binary check..."

# --help must not connect to a mining pool.
if "$BINARY" --help >/tmp/verus-miner-help.txt 2>&1; then
    echo "Binary executed successfully."
else
    # Some ccminer builds return non-zero for --help but still execute.
    if grep -qiE 'ccminer|usage|verus|algorithm' /tmp/verus-miner-help.txt 2>/dev/null; then
        echo "Binary started and returned help output."
    else
        die "Binary could not be executed."
    fi
fi

echo
echo "╭────────────────────────────────────────────╮"
echo "│              TEST RESULT                   │"
echo "├────────────────────────────────────────────┤"
echo "│ Asset        : VERIFIED                    │"
echo "│ SHA256       : PASS                        │"
echo "│ Executable   : PASS                        │"
echo "│ Mining       : NOT STARTED                 │"
echo "╰────────────────────────────────────────────╯"
echo
echo "Binary test completed successfully."
