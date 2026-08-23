#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
# Staged test env: 00-05, 03b (Weighted+Orbital pkgs), 03c (Morpho Blue SE pkg),
# 04b, 06t (DTF-DETF), 06e (TTDOL-Q), 09. No Morpho SE instances.
# Local default: Anvil Dev 0 + --unlocked on a 46630 fork.
# Pass --anvil-dev0 when DEPLOYER_ADDRESS is set (live wallet) so Anvil signs as Dev 0.
#
#   bash scripts/foundry/anvil_robinhood_testnet/fresh_deploy.sh
#   bash scripts/foundry/anvil_robinhood_testnet/fresh_deploy.sh --anvil-dev0
# Live 46630:
#   export DEPLOYER_ADDRESS=0x...
#   bash scripts/foundry/anvil_robinhood_testnet/fresh_deploy.sh --live
# Gas estimate (do not mix with a completed staged deploy):
#   bash scripts/shell/anvil_robinhood_testnet.sh simulate --restart-anvil
# Resume fee DETF: stage06t. Resume USD quad: stage06e.

live=0
for arg in "$@"; do
  if [[ "$arg" == "--live" ]]; then
    live=1
    break
  fi
done

if [[ "$live" -eq 1 ]]; then
  if [[ -z "${DEPLOYER_ADDRESS:-${SENDER:-${DEV_ADDRESS:-}}}" ]]; then
    echo "fresh_deploy.sh --live requires DEPLOYER_ADDRESS" >&2
    echo "Example: export DEPLOYER_ADDRESS=0x..." >&2
    exit 1
  fi
  bash scripts/shell/anvil_robinhood_testnet.sh all "$@"
else
  bash scripts/shell/anvil_robinhood_testnet.sh all --restart-anvil "$@"
fi
