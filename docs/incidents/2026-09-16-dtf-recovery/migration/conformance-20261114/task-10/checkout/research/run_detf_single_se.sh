#!/usr/bin/env bash
# Reproduce Single SE DETF Phase 3 research: D0–D9 forge + stamp + plots.
# Compatible with macOS bash 3.2 (no associative arrays).
#
# Usage (from repo root):
#   ./research/run_detf_single_se.sh
#   ./research/run_detf_single_se.sh --d3
#   ./research/run_detf_single_se.sh --from D5
#   ./research/run_detf_single_se.sh --plot-only
#   ./research/run_detf_single_se.sh --data-only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLOT_ONLY=0
DATA_ONLY=0
ONLY=""
FROM=""
PREV=""

for arg in "$@"; do
  case "$arg" in
    --plot-only) PLOT_ONLY=1 ;;
    --data-only) DATA_ONLY=1 ;;
    --d0) ONLY=D0 ;;
    --d1) ONLY=D1 ;;
    --d2) ONLY=D2 ;;
    --d3) ONLY=D3 ;;
    --d4) ONLY=D4 ;;
    --d5) ONLY=D5 ;;
    --d6) ONLY=D6 ;;
    --d7) ONLY=D7 ;;
    --d8) ONLY=D8 ;;
    --d9) ONLY=D9 ;;
    --from) : ;;
    -h|--help)
      sed -n '1,14p' "$0"
      exit 0
      ;;
    D0|D1|D2|D3|D4|D5|D6|D7|D8|D9)
      if [ "$PREV" = "--from" ]; then FROM="$arg"; else ONLY="$arg"; fi
      ;;
  esac
  PREV="$arg"
done

export MPLBACKEND="${MPLBACKEND:-Agg}"
export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-default}"
echo "  FOUNDRY_PROFILE=$FOUNDRY_PROFILE"

BASE="scripts/foundry/research/detf/singleSe"
OUT_BASE="research/out/detf/singleSe"

script_for() {
  case "$1" in
    D0) echo "${BASE}/Script_D0_Inert.s.sol:Script_D0_Inert" ;;
    D1) echo "${BASE}/Script_D1_FirstBond.s.sol:Script_D1_FirstBond" ;;
    D2) echo "${BASE}/Script_D2_PolicyDeadband.s.sol:Script_D2_PolicyDeadband" ;;
    D3) echo "${BASE}/Script_D3_PolicyMintAllowed.s.sol:Script_D3_PolicyMintAllowed" ;;
    D4) echo "${BASE}/Script_D4_PolicyBurnGate.s.sol:Script_D4_PolicyBurnGate" ;;
    D5) echo "${BASE}/Script_D5_OpenControl.s.sol:Script_D5_OpenControl" ;;
    D6) echo "${BASE}/Script_D6_CapitalSeigniorageDilution.s.sol:Script_D6_CapitalSeigniorageDilution" ;;
    D7) echo "${BASE}/Script_D7_BondVsMintBooks.s.sol:Script_D7_BondVsMintBooks" ;;
    D8) echo "${BASE}/Script_D8_NaturalExpansion.s.sol:Script_D8_NaturalExpansion" ;;
    D9) echo "${BASE}/Script_D9_ProtocolCompound.s.sol:Script_D9_ProtocolCompound" ;;
    *) echo "unknown id $1" >&2; return 1 ;;
  esac
}

rundir_for() {
  case "$1" in
    D0) echo "${OUT_BASE}/D0_inert" ;;
    D1) echo "${OUT_BASE}/D1_firstBond" ;;
    D2) echo "${OUT_BASE}/D2_policyDeadband" ;;
    D3) echo "${OUT_BASE}/D3_policyMintAllowed" ;;
    D4) echo "${OUT_BASE}/D4_policyBurnGate" ;;
    D5) echo "${OUT_BASE}/D5_openControl" ;;
    D6) echo "${OUT_BASE}/D6_capitalSeigniorage" ;;
    D7) echo "${OUT_BASE}/D7_bondVsMint" ;;
    D8) echo "${OUT_BASE}/D8_naturalExpansion" ;;
    D9) echo "${OUT_BASE}/D9_protocolCompound" ;;
    *) echo "unknown id $1" >&2; return 1 ;;
  esac
}

echo "== Single SE DETF Phase 3 research runner =="
echo "  root: $ROOT"
echo "  docs: research/scenarios/detf/singleSe/"

should_run() {
  id="$1"
  if [ -n "$ONLY" ]; then
    [ "$id" = "$ONLY" ]
    return
  fi
  if [ -n "$FROM" ]; then
    started=0
    for x in D0 D1 D2 D3 D4 D5 D6 D7 D8 D9; do
      if [ "$x" = "$FROM" ]; then started=1; fi
      if [ "$started" -eq 1 ] && [ "$x" = "$id" ]; then return 0; fi
    done
    return 1
  fi
  return 0
}

if [ "$PLOT_ONLY" -eq 0 ]; then
  for id in D0 D1 D2 D3 D4 D5 D6 D7 D8 D9; do
    if ! should_run "$id"; then continue; fi
    SCRIPT_PATH="$(script_for "$id")"
    RUNDIR="$(rundir_for "$id")"
    echo "== forge: $id =="
    forge script "$SCRIPT_PATH" -vv
    python3 research/plots/stamp_meta.py "$RUNDIR" --script "$SCRIPT_PATH"
  done
fi

if [ "$DATA_ONLY" -eq 0 ]; then
  echo "== plots =="
  python3 research/plots/plot_detf_single_se_all.py
fi

echo "== done =="
echo "  artifacts: $OUT_BASE"
echo "  figures:   $OUT_BASE/figures/"
echo "  narrative: research/scenarios/detf/singleSe/"
