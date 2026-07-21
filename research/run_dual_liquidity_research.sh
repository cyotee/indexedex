#!/usr/bin/env bash
# DualLiquidity Linked Cross-Version research runner.
# Requires Base fork RPC (foundry.toml base_mainnet_alchemy + ALCHEMY_KEY).
#
# Usage (repo root):
#   ./research/run_dual_liquidity_research.sh
#   ./research/run_dual_liquidity_research.sh --mode-a-only
#   ./research/run_dual_liquidity_research.sh --mode-b-only
#   ./research/run_dual_liquidity_research.sh --plot-only
#   ./research/run_dual_liquidity_research.sh --rates-on-only | --rates-off-only
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE_A=1
MODE_B=1
PLOT=1
DATA=1
RATES_ON=1
RATES_OFF=1
for arg in "$@"; do
  case "$arg" in
    --mode-a-only) MODE_B=0 ;;
    --mode-b-only) MODE_A=0 ;;
    --plot-only) DATA=0 ;;
    --data-only) PLOT=0 ;;
    --rates-on-only) RATES_OFF=0 ;;
    --rates-off-only) RATES_ON=0 ;;
    -h|--help) sed -n '1,14p' "$0"; exit 0 ;;
  esac
done

export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-default}"
export MPLBACKEND="${MPLBACKEND:-Agg}"
BASE="scripts/foundry/research/dualLiquidityLinkedCrossVersion"
OUT="research/out/dualLiquidityLinkedCrossVersion"

run_script() {
  local contract=$1
  echo "== forge $contract =="
  # Fork via foundry.toml RPC endpoint name (same as TestBase_BaseFork)
  forge script "${BASE}/${contract}.s.sol:${contract}" -vv --fork-url base_mainnet_alchemy
}

stamp_plot_dir() {
  local rel=$1
  local contract=$2
  local dir="${OUT}/${rel}"
  [[ -f "${dir}/series.jsonl" ]] || return 0
  python3 research/plots/stamp_meta.py "$dir" --script "${BASE}/${contract}.s.sol:${contract}"
  # DualLiquidity-specific single-run residual quick plot via compare if both exist later
}

if [[ "$DATA" -eq 1 ]]; then
  if [[ "$MODE_A" -eq 1 && "$RATES_OFF" -eq 1 ]]; then
    run_script Script_RatesOff_ModeA_LegDemand
  fi
  if [[ "$MODE_A" -eq 1 && "$RATES_ON" -eq 1 ]]; then
    run_script Script_RatesOn_ModeA_LegDemand
  fi
  if [[ "$MODE_B" -eq 1 && "$RATES_OFF" -eq 1 ]]; then
    run_script Script_RatesOff_ModeB_DepositCommon
  fi
  if [[ "$MODE_B" -eq 1 && "$RATES_ON" -eq 1 ]]; then
    run_script Script_RatesOn_ModeB_DepositCommon
  fi
fi

if [[ "$PLOT" -eq 1 ]]; then
  echo "== stamp + compare =="
  for item in \
    "rates_off/modeA_legDemand:Script_RatesOff_ModeA_LegDemand" \
    "rates_on/modeA_legDemand:Script_RatesOn_ModeA_LegDemand" \
    "rates_off/modeB_depositCommon:Script_RatesOff_ModeB_DepositCommon" \
    "rates_on/modeB_depositCommon:Script_RatesOn_ModeB_DepositCommon"
  do
    rel="${item%%:*}"; c="${item##*:}"
    stamp_plot_dir "$rel" "$c" || true
  done
  if [[ -f "${OUT}/rates_on/modeA_legDemand/series.jsonl" && -f "${OUT}/rates_off/modeA_legDemand/series.jsonl" ]]; then
    python3 research/plots/plot_dual_liquidity_compare.py \
      "${OUT}/rates_on/modeA_legDemand" \
      "${OUT}/rates_off/modeA_legDemand" \
      --out-dir "${OUT}/compare/modeA_legDemand"
  fi
  if [[ -f "${OUT}/rates_on/modeB_depositCommon/series.jsonl" && -f "${OUT}/rates_off/modeB_depositCommon/series.jsonl" ]]; then
    python3 research/plots/plot_dual_liquidity_compare.py \
      "${OUT}/rates_on/modeB_depositCommon" \
      "${OUT}/rates_off/modeB_depositCommon" \
      --out-dir "${OUT}/compare/modeB_depositCommon"
  fi
fi

echo "== done =="
echo "  artifacts: ${OUT}/"
echo "  narrative: research/scenarios/dualLiquidityLinkedCrossVersion/"
