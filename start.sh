#!/usr/bin/env bash
set -e
sudo systemctl start verus-miner
sudo systemctl --no-pager --full status verus-miner
