#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
# Anvil helper: --restart-anvil then the Anvil shell (Phase 00 then 01–09).
# Signer is Anvil Dev 0. Public 46630 uses scripts/shell/robinhood_testnet.sh.

for arg in "$@"; do
  if [[ "$arg" == "--live" ]]; then
    echo "fresh_deploy.sh is the Anvil helper. For public 46630 use:" >&2
    echo "  export DEPLOYER_ADDRESS=0x..." >&2
    echo "  bash scripts/shell/robinhood_testnet.sh all" >&2
    exit 1
  fi
done

bash scripts/shell/anvil_robinhood_testnet.sh all --restart-anvil "$@"
