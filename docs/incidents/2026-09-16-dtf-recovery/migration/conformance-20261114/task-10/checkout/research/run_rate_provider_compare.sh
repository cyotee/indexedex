#!/usr/bin/env bash
# Reproduce rateProviderCompare pure-state R+ vs R− research runs.
# Usage (repo root):
#   ./research/run_rate_provider_compare.sh
#   ./research/run_rate_provider_compare.sh --high-vol   # mul=10 steps=24; fee unchanged
#   ./research/run_rate_provider_compare.sh --high-vol-25s48  # mul=25 steps=48; fee unchanged
#   ./research/run_rate_provider_compare.sh --mode-a-only
#   ./research/run_rate_provider_compare.sh --mode-c-only
#   ./research/run_rate_provider_compare.sh --plot-only
#   ./research/run_rate_provider_compare.sh --rates-on-only | --rates-off-only
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE_A=1
MODE_C=1
PLOT=1
DATA=1
RATES_ON=1
RATES_OFF=1
HIGH_VOL=0
HV_TIER=""
for arg in "$@"; do
  case "$arg" in
    --mode-a-only) MODE_C=0 ;;
    --mode-c-only) MODE_A=0 ;;
    --plot-only) DATA=0 ;;
    --data-only) PLOT=0 ;;
    --rates-on-only) RATES_OFF=0 ;;
    --rates-off-only) RATES_ON=0 ;;
    --high-vol) HIGH_VOL=1; HV_TIER="mul10" ;;
    --high-vol-25s48) HIGH_VOL=1; HV_TIER="mul25_steps48" ;;
    -h|--help) sed -n '1,16p' "$0"; exit 0 ;;
  esac
done

export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-default}"
export MPLBACKEND="${MPLBACKEND:-Agg}"
BASE="scripts/foundry/research/uniswapV2Se/rateProviderCompare"
OUT="research/out/uniswapV2Se/rateProviderCompare"

if [[ "$HIGH_VOL" -eq 1 ]]; then
  BASE="${BASE}/highVol"
  OUT="${OUT}/highVol/${HV_TIER}"
fi

run_script() {
  local contract=$1
  echo "== forge $contract =="
  forge script "${BASE}/${contract}.s.sol:${contract}" -vv --offline
}

stamp_plot() {
  local rel=$1
  local contract=$2
  local dir="${OUT}/${rel}"
  python3 research/plots/stamp_meta.py "$dir" --script "${BASE}/${contract}.s.sol:${contract}"
  python3 research/plots/plot_all_mode_a.py "$dir"
}

if [[ "$DATA" -eq 1 ]]; then
  if [[ "$HIGH_VOL" -eq 1 ]]; then
    if [[ "$HV_TIER" == "mul25_steps48" ]]; then
      if [[ "$MODE_A" -eq 1 && "$RATES_ON" -eq 1 ]]; then
        run_script Script_HV25s48_RatesOn_ModeA_MarketBuysWeth
        run_script Script_HV25s48_RatesOn_ModeA_MarketBuysUsdc
      fi
      if [[ "$MODE_A" -eq 1 && "$RATES_OFF" -eq 1 ]]; then
        run_script Script_HV25s48_RatesOff_ModeA_MarketBuysWeth
        run_script Script_HV25s48_RatesOff_ModeA_MarketBuysUsdc
      fi
      if [[ "$MODE_C" -eq 1 && "$RATES_ON" -eq 1 ]]; then
        run_script Script_HV25s48_RatesOn_ModeC_MarketBuysWeth
        run_script Script_HV25s48_RatesOn_ModeC_MarketBuysUsdc
      fi
      if [[ "$MODE_C" -eq 1 && "$RATES_OFF" -eq 1 ]]; then
        run_script Script_HV25s48_RatesOff_ModeC_MarketBuysWeth
        run_script Script_HV25s48_RatesOff_ModeC_MarketBuysUsdc
      fi
    else
      if [[ "$MODE_A" -eq 1 && "$RATES_ON" -eq 1 ]]; then
        run_script Script_HV_RatesOn_ModeA_MarketBuysWeth
        run_script Script_HV_RatesOn_ModeA_MarketBuysUsdc
      fi
      if [[ "$MODE_A" -eq 1 && "$RATES_OFF" -eq 1 ]]; then
        run_script Script_HV_RatesOff_ModeA_MarketBuysWeth
        run_script Script_HV_RatesOff_ModeA_MarketBuysUsdc
      fi
      if [[ "$MODE_C" -eq 1 && "$RATES_ON" -eq 1 ]]; then
        run_script Script_HV_RatesOn_ModeC_MarketBuysWeth
        run_script Script_HV_RatesOn_ModeC_MarketBuysUsdc
      fi
      if [[ "$MODE_C" -eq 1 && "$RATES_OFF" -eq 1 ]]; then
        run_script Script_HV_RatesOff_ModeC_MarketBuysWeth
        run_script Script_HV_RatesOff_ModeC_MarketBuysUsdc
      fi
    fi
  else
    if [[ "$MODE_A" -eq 1 && "$RATES_ON" -eq 1 ]]; then
      run_script Script_RatesOn_ModeA_MarketBuysWeth
      run_script Script_RatesOn_ModeA_MarketBuysUsdc
    fi
    if [[ "$MODE_A" -eq 1 && "$RATES_OFF" -eq 1 ]]; then
      run_script Script_RatesOff_ModeA_MarketBuysWeth
      run_script Script_RatesOff_ModeA_MarketBuysUsdc
    fi
    if [[ "$MODE_C" -eq 1 && "$RATES_ON" -eq 1 ]]; then
      run_script Script_RatesOn_ModeC_MarketBuysWeth
      run_script Script_RatesOn_ModeC_MarketBuysUsdc
    fi
    if [[ "$MODE_C" -eq 1 && "$RATES_OFF" -eq 1 ]]; then
      run_script Script_RatesOff_ModeC_MarketBuysWeth
      run_script Script_RatesOff_ModeC_MarketBuysUsdc
    fi
  fi
fi

if [[ "$PLOT" -eq 1 ]]; then
  echo "== stamp + single-run plots =="
  if [[ "$HIGH_VOL" -eq 1 ]]; then
    if [[ "$HV_TIER" == "mul25_steps48" ]]; then
      HV_PREFIX="Script_HV25s48"
    else
      HV_PREFIX="Script_HV"
    fi
    for pair in \
      "rates_on/modeA_market_buys_weth:${HV_PREFIX}_RatesOn_ModeA_MarketBuysWeth" \
      "rates_on/modeA_market_buys_usdc:${HV_PREFIX}_RatesOn_ModeA_MarketBuysUsdc" \
      "rates_off/modeA_market_buys_weth:${HV_PREFIX}_RatesOff_ModeA_MarketBuysWeth" \
      "rates_off/modeA_market_buys_usdc:${HV_PREFIX}_RatesOff_ModeA_MarketBuysUsdc" \
      "rates_on/modeC_market_buys_weth:${HV_PREFIX}_RatesOn_ModeC_MarketBuysWeth" \
      "rates_on/modeC_market_buys_usdc:${HV_PREFIX}_RatesOn_ModeC_MarketBuysUsdc" \
      "rates_off/modeC_market_buys_weth:${HV_PREFIX}_RatesOff_ModeC_MarketBuysWeth" \
      "rates_off/modeC_market_buys_usdc:${HV_PREFIX}_RatesOff_ModeC_MarketBuysUsdc"
    do
      rel="${pair%%:*}"; contract="${pair##*:}"
      [[ -d "${OUT}/${rel}" ]] && stamp_plot "$rel" "$contract" || true
    done
    CMP="${OUT}/compare"
    echo "== high-vol comparison plots -> ${CMP} =="
    if [[ -f "${OUT}/rates_on/modeA_market_buys_weth/series.jsonl" && -f "${OUT}/rates_off/modeA_market_buys_weth/series.jsonl" ]]; then
      python3 research/plots/plot_rate_provider_compare.py \
        "${OUT}/rates_on/modeA_market_buys_weth" \
        "${OUT}/rates_off/modeA_market_buys_weth" \
        --out-dir "${CMP}/A_uni_only_WETH"
    fi
    if [[ -f "${OUT}/rates_on/modeA_market_buys_usdc/series.jsonl" && -f "${OUT}/rates_off/modeA_market_buys_usdc/series.jsonl" ]]; then
      python3 research/plots/plot_rate_provider_compare.py \
        "${OUT}/rates_on/modeA_market_buys_usdc" \
        "${OUT}/rates_off/modeA_market_buys_usdc" \
        --out-dir "${CMP}/A_uni_only_USDC"
    fi
    if [[ -f "${OUT}/rates_on/modeC_market_buys_weth/series.jsonl" && -f "${OUT}/rates_off/modeC_market_buys_weth/series.jsonl" ]]; then
      python3 research/plots/plot_rate_provider_compare.py \
        "${OUT}/rates_on/modeC_market_buys_weth" \
        "${OUT}/rates_off/modeC_market_buys_weth" \
        --out-dir "${CMP}/C_uni_plus_bal_arb_WETH"
    fi
    if [[ -f "${OUT}/rates_on/modeC_market_buys_usdc/series.jsonl" && -f "${OUT}/rates_off/modeC_market_buys_usdc/series.jsonl" ]]; then
      python3 research/plots/plot_rate_provider_compare.py \
        "${OUT}/rates_on/modeC_market_buys_usdc" \
        "${OUT}/rates_off/modeC_market_buys_usdc" \
        --out-dir "${CMP}/C_uni_plus_bal_arb_USDC"
    fi
  else
    [[ -d "${OUT}/rates_on/modeA_market_buys_weth" ]] && stamp_plot rates_on/modeA_market_buys_weth Script_RatesOn_ModeA_MarketBuysWeth || true
    [[ -d "${OUT}/rates_on/modeA_market_buys_usdc" ]] && stamp_plot rates_on/modeA_market_buys_usdc Script_RatesOn_ModeA_MarketBuysUsdc || true
    [[ -d "${OUT}/rates_off/modeA_market_buys_weth" ]] && stamp_plot rates_off/modeA_market_buys_weth Script_RatesOff_ModeA_MarketBuysWeth || true
    [[ -d "${OUT}/rates_off/modeA_market_buys_usdc" ]] && stamp_plot rates_off/modeA_market_buys_usdc Script_RatesOff_ModeA_MarketBuysUsdc || true
    [[ -d "${OUT}/rates_on/modeC_market_buys_weth" ]] && stamp_plot rates_on/modeC_market_buys_weth Script_RatesOn_ModeC_MarketBuysWeth || true
    [[ -d "${OUT}/rates_on/modeC_market_buys_usdc" ]] && stamp_plot rates_on/modeC_market_buys_usdc Script_RatesOn_ModeC_MarketBuysUsdc || true
    [[ -d "${OUT}/rates_off/modeC_market_buys_weth" ]] && stamp_plot rates_off/modeC_market_buys_weth Script_RatesOff_ModeC_MarketBuysWeth || true
    [[ -d "${OUT}/rates_off/modeC_market_buys_usdc" ]] && stamp_plot rates_off/modeC_market_buys_usdc Script_RatesOff_ModeC_MarketBuysUsdc || true

    echo "== comparison plots =="
    if [[ -f "${OUT}/rates_on/modeA_market_buys_weth/series.jsonl" && -f "${OUT}/rates_off/modeA_market_buys_weth/series.jsonl" ]]; then
      python3 research/plots/plot_rate_provider_compare.py \
        "${OUT}/rates_on/modeA_market_buys_weth" \
        "${OUT}/rates_off/modeA_market_buys_weth"
    fi
    if [[ -f "${OUT}/rates_on/modeA_market_buys_usdc/series.jsonl" && -f "${OUT}/rates_off/modeA_market_buys_usdc/series.jsonl" ]]; then
      python3 research/plots/plot_rate_provider_compare.py \
        "${OUT}/rates_on/modeA_market_buys_usdc" \
        "${OUT}/rates_off/modeA_market_buys_usdc"
    fi
    if [[ -f "${OUT}/rates_on/modeC_market_buys_weth/series.jsonl" && -f "${OUT}/rates_off/modeC_market_buys_weth/series.jsonl" ]]; then
      python3 research/plots/plot_rate_provider_compare.py \
        "${OUT}/rates_on/modeC_market_buys_weth" \
        "${OUT}/rates_off/modeC_market_buys_weth"
    fi
    if [[ -f "${OUT}/rates_on/modeC_market_buys_usdc/series.jsonl" && -f "${OUT}/rates_off/modeC_market_buys_usdc/series.jsonl" ]]; then
      python3 research/plots/plot_rate_provider_compare.py \
        "${OUT}/rates_on/modeC_market_buys_usdc" \
        "${OUT}/rates_off/modeC_market_buys_usdc"
    fi
  fi
fi

echo "== done =="
echo "  artifacts: ${OUT}/"
echo "  narrative: research/scenarios/uniswapV2Se/rateProviderCompare/"
