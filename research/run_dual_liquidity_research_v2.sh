#!/usr/bin/env bash
# DualLiquidity Research v2 runner — linked volume + share-book (rates-off hero).
# Requires Base fork RPC (foundry.toml base_mainnet_alchemy + ALCHEMY_KEY).
#
# Usage (repo root):
#   ./research/run_dual_liquidity_research_v2.sh
#   ./research/run_dual_liquidity_research_v2.sh --smoke
#   ./research/run_dual_liquidity_research_v2.sh --mode-b-only
#   ./research/run_dual_liquidity_research_v2.sh --mode-a-only
#   ./research/run_dual_liquidity_research_v2.sh --routes p0
#   ./research/run_dual_liquidity_research_v2.sh --routes p0p1
#   ./research/run_dual_liquidity_research_v2.sh --route deposit_common
#   ./research/run_dual_liquidity_research_v2.sh --plot-only
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SMOKE=0
MODE_A=1
MODE_B=1
PLOT=1
DATA=1
ROUTES="p0p1"
SINGLE_ROUTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --smoke) SMOKE=1; MODE_A=0; MODE_B=0; shift ;;
    --mode-a-only) MODE_B=0; shift ;;
    --mode-b-only) MODE_A=0; shift ;;
    --plot-only) DATA=0; shift ;;
    --data-only) PLOT=0; shift ;;
    --routes) ROUTES="${2:-p0p1}"; shift 2 ;;
    --route) SINGLE_ROUTE="${2:-}"; MODE_A=0; MODE_B=1; shift 2 ;;
    -h|--help) sed -n '1,18p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1"; exit 1 ;;
  esac
done

export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-default}"
export MPLBACKEND="${MPLBACKEND:-Agg}"
BASE="scripts/foundry/research/dualLiquidityLinkedCrossVersion"
OUT="research/out/dualLiquidityLinkedCrossVersion/v2"

run_script() {
  local contract=$1
  echo "== forge $contract =="
  forge script "${BASE}/${contract}.s.sol:${contract}" -vv --fork-url base_mainnet_alchemy
}

stamp_dir() {
  local rel=$1
  local contract=$2
  local dir="${OUT}/${rel#v2/}"
  # runId already includes v2/ prefix; out path is product/runId
  dir="research/out/dualLiquidityLinkedCrossVersion/${rel}"
  [[ -f "${dir}/series.jsonl" ]] || return 0
  python3 research/plots/stamp_meta.py "$dir" --script "${BASE}/${contract}.s.sol:${contract}" || true
}

plot_route() {
  local dir=$1
  [[ -f "${dir}/series.jsonl" ]] || return 0
  python3 research/plots/plot_dual_liquidity_v2.py "$dir" || true
}

if [[ "$DATA" -eq 1 ]]; then
  if [[ "$SMOKE" -eq 1 ]]; then
    run_script Script_V2_RatesOff_Smoke
  fi

  if [[ -n "$SINGLE_ROUTE" ]]; then
    case "$SINGLE_ROUTE" in
      deposit_common|modeB_depositCommon)
        run_script Script_V2_RatesOff_ModeB_DepositCommon ;;
      deposit_tokenA|modeB_depositTokenA)
        run_script Script_V2_RatesOff_ModeB_DepositTokenA ;;
      deposit_tokenB|modeB_depositTokenB)
        run_script Script_V2_RatesOff_ModeB_DepositTokenB ;;
      deposit_pairShare|modeB_depositPairShare)
        run_script Script_V2_RatesOff_ModeB_DepositPairShare ;;
      deposit_vaultAShare|modeB_depositVaultAShare)
        run_script Script_V2_RatesOff_ModeB_DepositVaultAShare ;;
      swap_tokenA_tokenB|modeB_swapTokenATokenB)
        run_script Script_V2_RatesOff_ModeB_SwapTokenATokenB ;;
      modeA_legDemand|legDemand)
        run_script Script_V2_RatesOff_ModeA_LegDemand ;;
      smoke)
        run_script Script_V2_RatesOff_Smoke ;;
      *) echo "unknown --route $SINGLE_ROUTE"; exit 1 ;;
    esac
  else
    if [[ "$MODE_B" -eq 1 ]]; then
      # P0 always
      run_script Script_V2_RatesOff_ModeB_DepositCommon
      run_script Script_V2_RatesOff_ModeB_DepositTokenA
      run_script Script_V2_RatesOff_ModeB_DepositTokenB
      if [[ "$ROUTES" == "p0p1" || "$ROUTES" == "all" ]]; then
        run_script Script_V2_RatesOff_ModeB_DepositPairShare || echo "WARN: deposit_pairShare failed (deferred)"
        run_script Script_V2_RatesOff_ModeB_DepositVaultAShare || echo "WARN: deposit_vaultAShare failed (deferred)"
        run_script Script_V2_RatesOff_ModeB_SwapTokenATokenB || echo "WARN: swap_tokenA_tokenB failed (deferred)"
      fi
    fi
    if [[ "$MODE_A" -eq 1 ]]; then
      run_script Script_V2_RatesOff_ModeA_LegDemand
    fi
  fi
fi

if [[ "$PLOT" -eq 1 ]]; then
  echo "== stamp + plot v2 =="
  for item in \
    "v2/rates_off/smoke:Script_V2_RatesOff_Smoke" \
    "v2/rates_off/modeB_depositCommon:Script_V2_RatesOff_ModeB_DepositCommon" \
    "v2/rates_off/modeB_depositTokenA:Script_V2_RatesOff_ModeB_DepositTokenA" \
    "v2/rates_off/modeB_depositTokenB:Script_V2_RatesOff_ModeB_DepositTokenB" \
    "v2/rates_off/modeB_depositPairShare:Script_V2_RatesOff_ModeB_DepositPairShare" \
    "v2/rates_off/modeB_depositVaultAShare:Script_V2_RatesOff_ModeB_DepositVaultAShare" \
    "v2/rates_off/modeB_swapTokenATokenB:Script_V2_RatesOff_ModeB_SwapTokenATokenB" \
    "v2/rates_off/modeA_legDemand:Script_V2_RatesOff_ModeA_LegDemand"
  do
    rel="${item%%:*}"; c="${item##*:}"
    stamp_dir "$rel" "$c" || true
    plot_route "research/out/dualLiquidityLinkedCrossVersion/${rel}" || true
  done
fi

echo "== done =="
echo "  artifacts: research/out/dualLiquidityLinkedCrossVersion/v2/"
echo "  narrative: research/scenarios/dualLiquidityLinkedCrossVersion/"
