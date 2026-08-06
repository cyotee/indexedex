#!/usr/bin/env bash
# Reproduce Uni V4 Single SE CP DETF research D0/D1 (extend as D2–D9 land).
# Usage (repo root):
#   ./research/run_uniswap_v4_cp_detf.sh
#   ./research/run_uniswap_v4_cp_detf.sh --d0
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ONLY=""
for arg in "$@"; do
  case "$arg" in
    --d0) ONLY=D0 ;;
    --d1) ONLY=D1 ;;
    -h|--help) sed -n '1,6p' "$0"; exit 0 ;;
  esac
done

export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-uv4_single_se_cp_detf}"
export FORGE_VIA_IR="${FORGE_VIA_IR:-1}"
echo "  FOUNDRY_PROFILE=$FOUNDRY_PROFILE FORGE_VIA_IR=$FORGE_VIA_IR"

BASE="scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle"
OUT_BASE="research/out/uniswapV4/detf/standardExchangeCpSingle"

run_one() {
  local id="$1"
  local script=""
  local outdir=""
  case "$id" in
    D0) script="${BASE}/Script_D0_Inert.s.sol:Script_D0_Inert"; outdir="${OUT_BASE}/D0_inert" ;;
    D1) script="${BASE}/Script_D1_FirstBond.s.sol:Script_D1_FirstBond"; outdir="${OUT_BASE}/D1_firstBond" ;;
    *) echo "unknown $id" >&2; return 1 ;;
  esac
  echo "==> forge $id"
  VIA_ARGS=()
  if [ "${FORGE_VIA_IR:-0}" = "1" ]; then VIA_ARGS+=(--via-ir); fi
  forge script "$script" -vv "${VIA_ARGS[@]}"
  python research/plots/stamp_meta.py "$outdir" --script "$script" || true
}

if [ -n "$ONLY" ]; then
  run_one "$ONLY"
else
  run_one D0
  run_one D1
fi

echo "done: $OUT_BASE"
