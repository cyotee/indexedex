#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEV_ADDRESS="${DEV_ADDRESS:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
export SENDER="${SENDER:-$DEV_ADDRESS}"
# Full path: 00-05, 06a-c, 06e, Script_06, 07, 08, SimulateLaunch, 09 (TTM7-W / 06d omitted).
# Resume one leaf: bash scripts/shell/anvil_robinhood_testnet.sh stage06a
bash scripts/shell/anvil_robinhood_testnet.sh all --restart-anvil "$@"
