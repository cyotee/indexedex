#!/usr/bin/env bash
# Launch-only RICH on pons v1 (Anvil Robinhood 4663). No SE / DETF / market buy.
# Usage:
#   DEV_ADDRESS=0xf39F… PRIVATE_KEY=0xac09… ./scripts/shell/pons_launch_rich.sh
#   ./scripts/shell/pons_launch_rich.sh --force
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "$ROOT/scripts/foundry/anvil_robinhood_main/deploy_all.sh" pons-launch "$@"
