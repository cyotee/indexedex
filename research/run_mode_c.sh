#!/usr/bin/env bash
# Reproduce Mode C (Uni demand + Balancer arb closer) end-to-end.
#
# Usage (from repo root):
#   ./research/run_mode_c.sh
#   ./research/run_mode_c.sh --plot-only
#   ./research/run_mode_c.sh --data-only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLOT_ONLY=0
DATA_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --plot-only) PLOT_ONLY=1 ;;
    --data-only) DATA_ONLY=1 ;;
    -h|--help)
      sed -n '1,12p' "$0"
      exit 0
      ;;
  esac
done

export MPLBACKEND="${MPLBACKEND:-Agg}"
export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-default}"

RUN_USDC="research/out/uniswapV2Se/modeC_market_buys_usdc"
RUN_WETH="research/out/uniswapV2Se/modeC_market_buys_weth"
SCRIPT_USDC="scripts/foundry/research/uniswapV2Se/Script_ModeC_MarketBuysUsdc.s.sol:Script_ModeC_MarketBuysUsdc"
SCRIPT_WETH="scripts/foundry/research/uniswapV2Se/Script_ModeC_MarketBuysWeth.s.sol:Script_ModeC_MarketBuysWeth"

echo "== Mode C research runner =="
echo "  root: $ROOT"
echo "  docs: research/scenarios/uniswapV2Se/MODE_C_FINDINGS.md"

if [[ "$PLOT_ONLY" -eq 0 ]]; then
  echo "== forge: Mode C market buys USDC + arb =="
  forge script "$SCRIPT_USDC" -vv
  python3 research/plots/stamp_meta.py "$RUN_USDC" --script "$SCRIPT_USDC"

  echo "== forge: Mode C market buys WETH + arb =="
  forge script "$SCRIPT_WETH" -vv
  python3 research/plots/stamp_meta.py "$RUN_WETH" --script "$SCRIPT_WETH"
fi

if [[ "$DATA_ONLY" -eq 0 ]]; then
  echo "== plots (Mode A pack is valid for Mode C series schema) =="
  python3 research/plots/plot_all_mode_a.py "$RUN_USDC" "$RUN_WETH"
fi

echo "== done =="
echo "  artifacts: $RUN_USDC  $RUN_WETH"
echo "  narrative: research/scenarios/uniswapV2Se/"
