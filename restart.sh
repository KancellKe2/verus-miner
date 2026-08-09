#!/usr/bin/env bash
set -e
sudo systemctl restart verus-miner
sudo systemctl --no-pager --full status verus-miner
