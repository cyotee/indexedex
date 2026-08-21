#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
# Staged test env: 00-05, 06t (TTCHIR), 06e (TTDOL-Q), 09.
# Requires DEPLOYER_ADDRESS (forge --sender; cast wallet signs).
#
# Local Anvil rehearsal:
#   export DEPLOYER_ADDRESS=0x...
#   bash scripts/foundry/anvil_robinhood_testnet/fresh_deploy.sh --public-rpc --fork-latest
# Live 46630:
#   export DEPLOYER_ADDRESS=0x...
#   bash scripts/foundry/anvil_robinhood_testnet/fresh_deploy.sh --live
# Gas estimate (do not mix with a completed staged deploy):
#   bash scripts/shell/anvil_robinhood_testnet.sh simulate --restart-anvil
# Resume fee DETF: stage06t. Resume USD quad: stage06e.

if [[ -z "${DEPLOYER_ADDRESS:-}" ]]; then
  echo "fresh_deploy.sh requires DEPLOYER_ADDRESS" >&2
  echo "Example: export DEPLOYER_ADDRESS=0x..." >&2
  exit 1
fi

live=0
for arg in "$@"; do
  if [[ "$arg" == "--live" ]]; then
    live=1
    break
  fi
done

if [[ "$live" -eq 1 ]]; then
  bash scripts/shell/anvil_robinhood_testnet.sh all "$@"
else
  bash scripts/shell/anvil_robinhood_testnet.sh all --restart-anvil "$@"
fi
