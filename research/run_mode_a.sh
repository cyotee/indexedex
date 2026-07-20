#!/usr/bin/env bash
# Reproduce Mode A (Uni V2 SE rate matrix) end-to-end: forge data + plots + meta stamp.
#
# Usage (from repo root):
#   ./research/run_mode_a.sh
#   ./research/run_mode_a.sh --plot-only    # replot existing series.jsonl
#   ./research/run_mode_a.sh --data-only    # forge only, no plots
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
# Default profile (via_ir=false). Research profile via_ir currently hits Uniswap V4 stack issues.
export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-default}"
echo "  FOUNDRY_PROFILE=$FOUNDRY_PROFILE"

RUN_USDC="research/out/uniswapV2Se/modeA_trade_usdc"
RUN_WETH="research/out/uniswapV2Se/modeA_trade_weth"
SCRIPT_USDC="scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeUsdc.s.sol:Script_ModeA_TradeUsdc"
SCRIPT_WETH="scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeWeth.s.sol:Script_ModeA_TradeWeth"

echo "== Mode A research runner =="
echo "  root: $ROOT"
echo "  docs: research/scenarios/uniswapV2Se/MODE_A_FINDINGS.md"

if [[ "$PLOT_ONLY" -eq 0 ]]; then
  echo "== forge: market buys USDC (flow WETH→USDC) =="
  forge script "$SCRIPT_WETH" -vv
  python3 research/plots/stamp_meta.py "$RUN_WETH" --script "$SCRIPT_WETH"

  echo "== forge: market buys WETH (flow USDC→WETH) =="
  forge script "$SCRIPT_USDC" -vv
  python3 research/plots/stamp_meta.py "$RUN_USDC" --script "$SCRIPT_USDC"
fi

if [[ "$DATA_ONLY" -eq 0 ]]; then
  echo "== plots =="
  python3 research/plots/plot_all_mode_a.py "$RUN_USDC" "$RUN_WETH"
fi

echo "== done =="
echo "  artifacts: $RUN_USDC  $RUN_WETH"
echo "  narrative: research/scenarios/uniswapV2Se/"
echo "  verify:    see expected end metrics in MODE_A_FINDINGS.md"
