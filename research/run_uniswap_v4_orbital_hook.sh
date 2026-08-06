#!/usr/bin/env bash
# Reproduce Uni V4 Orbital Swap Hook research scenarios H0/H1/H2.
# Usage (repo root):
#   ./research/run_uniswap_v4_orbital_hook.sh
#   ./research/run_uniswap_v4_orbital_hook.sh --h0
#   ./research/run_uniswap_v4_orbital_hook.sh --plot-only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLOT_ONLY=0
DATA_ONLY=0
ONLY=""

for arg in "$@"; do
  case "$arg" in
    --plot-only) PLOT_ONLY=1 ;;
    --data-only) DATA_ONLY=1 ;;
    --h0) ONLY=H0 ;;
    --h1) ONLY=H1 ;;
    --h2) ONLY=H2 ;;
    -h|--help)
      sed -n '1,8p' "$0"
      exit 0
      ;;
  esac
done

export MPLBACKEND="${MPLBACKEND:-Agg}"
# Narrow orbital profile + via-ir (stack-too-deep on research fixture inheritance without IR).
export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-orbital}"
export FORGE_VIA_IR="${FORGE_VIA_IR:-1}"
echo "  FOUNDRY_PROFILE=$FOUNDRY_PROFILE FORGE_VIA_IR=$FORGE_VIA_IR"

BASE="scripts/foundry/research/uniswapV4/hooks/orbital"
OUT_BASE="research/out/uniswapV4/hooks/orbital"

run_one() {
  local id="$1"
  local script=""
  local outdir=""
  case "$id" in
    H0) script="${BASE}/Script_H0_Smoke.s.sol:Script_H0_Smoke"; outdir="${OUT_BASE}/H0_smoke" ;;
    H1a) script="${BASE}/Script_H1_Demand01.s.sol:Script_H1_Demand01"; outdir="${OUT_BASE}/H1_demand_01" ;;
    H1b) script="${BASE}/Script_H1_Demand10.s.sol:Script_H1_Demand10"; outdir="${OUT_BASE}/H1_demand_10" ;;
    H2) script="${BASE}/Script_H2_Preview.s.sol:Script_H2_Preview"; outdir="${OUT_BASE}/H2_preview" ;;
    *) echo "unknown $id" >&2; return 1 ;;
  esac

  if [ "$PLOT_ONLY" -eq 0 ]; then
    echo "==> forge $id"
    VIA_ARGS=()
    if [ "${FORGE_VIA_IR:-0}" = "1" ]; then VIA_ARGS+=(--via-ir); fi
    forge script "$script" -vv "${VIA_ARGS[@]}"
    python research/plots/stamp_meta.py "$outdir" --script "$script" || true
  fi
  if [ "$DATA_ONLY" -eq 0 ] && [ -f "$outdir/series.jsonl" ]; then
    python research/plots/plot_uniswap_v4_hook_mids.py "$outdir" || true
  fi
}

if [ -n "$ONLY" ]; then
  if [ "$ONLY" = "H1" ]; then
    run_one H1a
    run_one H1b
  else
    run_one "$ONLY"
  fi
else
  run_one H0
  run_one H1a
  run_one H1b
  run_one H2
fi

echo "done: $OUT_BASE"
