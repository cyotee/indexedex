#!/usr/bin/env bash
# Thin wrapper — exec deploy_all.sh with same args
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../foundry/anvil_robinhood_fee_detf/deploy_all.sh" "$@"
