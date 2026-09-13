# Shared 4663 Phase/Stage catalog + forge runner.
# Sourced by anvil_robinhood_main.sh / deploy_all.sh and robinhood_main.sh.
# Never --skip-simulation. Simulate each Stage, then broadcast.
# Architecture only: no tokens, no SE/DETF instances.

RH_FOUNDRY_DIR="${RH_FOUNDRY_DIR:-}"

rh_stage_script() {
  local pp ss
  pp="$(printf '%02d' "$((10#$1))")"
  ss="$(printf '%02d' "$((10#$2))")"
  local matches=("$RH_FOUNDRY_DIR"/Phase_${pp}_Stage_${ss}_*.s.sol)
  if [[ ! -e "${matches[0]:-}" ]]; then
    echo "Unknown Stage Phase ${pp} Stage ${ss}" >&2
    return 1
  fi
  echo "${matches[0]}"
}

# Catalog order: Phase 00 Stage 01, architecture Stages of 01–06, then Phase 09 export.
# Stages 05-04/05-06 provide V3/V2 SE; 06-05 provides the current Orbital hook.
# TokenStaking (06-08 package + 08-01 $DTF instance) is opt-in: rh_run_token_staking.
# Rebasing-aware ERC4626 (06-10) is included independently of TokenStaking.
rh_catalog_rows() {
  cat <<'EOF'
00 01
01 01
01 02
01 03
02 01
02 02
02 03
03 01
04 01
05 01
05 02
05 03
05 04
05 05
05 06
06 01
06 02
06 03
06 04
06 05
06 06
06 07
06 09
06 10
09 01
EOF
}

rh_should_run_stage() {
  local pp="$1"
  local ss="$2"
  local from_pp="${3:-}"
  local from_ss="${4:-}"
  if [[ -z "$from_pp" ]]; then
    return 0
  fi
  local from_pp10=$((10#$from_pp))
  local from_ss10=$((10#$from_ss))
  local pp10=$((10#$pp))
  local ss10=$((10#$ss))
  if (( pp10 > from_pp10 )); then
    return 0
  fi
  if (( pp10 == from_pp10 && ss10 >= from_ss10 )); then
    return 0
  fi
  return 1
}

rh_run_catalog() {
  local include_phase00="$1"
  local from_pp="${2:-}"
  local from_ss="${3:-00}"
  local pp ss
  while read -r pp ss; do
    [[ -z "$pp" ]] && continue
    if [[ "$include_phase00" != "1" && "$pp" == "00" ]]; then
      continue
    fi
    if ! rh_should_run_stage "$pp" "$ss" "$from_pp" "$from_ss"; then
      log_info "Skipping Phase $pp Stage $ss (--from-phase/--from-stage)"
      continue
    fi
    run_stage "Phase ${pp} Stage ${ss}" "$(rh_stage_script "$pp" "$ss")"
  done < <(rh_catalog_rows)
}

# Opt-in: TokenStaking DFPkg then $DTF instance. Not in architecture `all`.
rh_run_token_staking() {
  run_stage "Phase 06 Stage 08" "$(rh_stage_script 06 08)"
  run_stage "Phase 08 Stage 01" "$(rh_stage_script 08 01)"
}

# Opt-in: notifyRewardAmount(sender $DTF balance). Requires Phase 08 Stage 01 JSON.
rh_run_token_staking_fund() {
  run_stage "Phase 08 Stage 02" "$(rh_stage_script 08 02)"
}

# Separate opt-in instance catalog. The architecture-only rh_catalog_rows stays unchanged.
rh_fee_accrual_catalog_rows() {
  cat <<'ROWS'
01 04
07 01
07 02
07 03
07 04
08 03
08 04
08 05
08 06
08 07
08 08
09 02
ROWS
}


# Artifact preparation and reuse-only manifests shared by both 4663 shells.
build_rehearsal_artifacts() {
  # FactoryServices load facets from artifacts. Build their implementations before scripts.
  local source
  local sources=(
    contracts/utils/foundry/CraneFactoryArtifactSeed.sol
    contracts/utils/foundry/UniswapV4DetfFactoryArtifactSeed.sol
  )
  while IFS= read -r source; do
    sources+=("$source")
  done < <(
    cd "$REPO_ROOT"
    rg --files \
      contracts/hooks/uniswap/v4/libs \
      contracts/hooks/uniswap/v4/standardExchange/constantProduct/single \
      contracts/hooks/uniswap/v4/standardExchange/weighted \
      contracts/hooks/uniswap/v4/standardExchange/orbital \
      contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve \
      contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer \
      contracts/vaults/detf/protocols/dexes/uniswap/v4/detf \
      contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft \
      contracts/vaults/detf/common/claimToken \
      contracts/vaults/detf/common/bondNft \
      contracts/vaults/detf/common/sy \
      contracts/vaults/standard/sy \
      contracts/fee/collector \
      contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange \
      contracts/vaults/standard/erc4626 \
      contracts/vaults/standard/exchange/protocols/morpho/blue \
      contracts/protocols/dexes/uniswap/v2 \
      contracts/protocols/dexes/uniswap/v3 \
      contracts/protocols/dexes/uniswap/v4 \
      | rg '(Facet|DFPkg|ExecutionDelegate|ClaimLib|ExitQuoteLib|LegLib)\.sol$' \
      | sort
  )
  log_info "Building production artifacts for the package rehearsal"
  run_forge_cmd forge build "${sources[@]}"
}

rh_fee_accrual_copy_core() {
  local seed="${FEE_ACCRUAL_CORE_DIR:-${REHEARSAL_CORE_DIR:-$REPO_ROOT/deployments/anvil_robinhood_main}}" file key actual expected
  local files=(phase01_stage01_permit2.json phase01_stage02_weth.json
    phase01_stage03_uniswap_v4.json phase02_stage01_create3_factory.json
    phase02_stage02_diamond_package_factory.json phase02_stage03_hook_factory.json
    phase03_stage01_common_facets.json phase04_stage01_fee_collector_and_manager.json
    phase05_stage02_uniswap_v4_twap_oracle.json)
  for file in "${files[@]}"; do
    [[ -f "$seed/$file" ]] || { echo "Missing existing core manifest: $file" >&2; return 1; }
    jq -e '.chainId == 4663' "$seed/$file" >/dev/null || return 1
  done
  while read -r file key; do
    actual="$(jq -er --arg key "$key" '.[$key]' "$seed/$file")" || return $?
    expected="$(jq -er --arg key "$key" '.[$key]' "$FEE_ACCRUAL_CONFIG")" || return $?
    [[ "$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')" == "$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')" ]] || {
      echo "Existing manifest does not match configured $key" >&2; return 1;
    }
  done <<'CORE'
phase02_stage01_create3_factory.json create3Factory
phase02_stage02_diamond_package_factory.json diamondPackageFactory
phase02_stage03_hook_factory.json hookFactory
phase04_stage01_fee_collector_and_manager.json indexedexManager
phase04_stage01_fee_collector_and_manager.json feeCollector
CORE
  for file in "${files[@]}"; do
    if [[ -f "$OUT_DIR_OVERRIDE/$file" ]]; then
      cmp -s "$seed/$file" "$OUT_DIR_OVERRIDE/$file" || { echo "Conflicting core manifest: $file" >&2; return 1; }
    else
      cp "$seed/$file" "$OUT_DIR_OVERRIDE/$file"
    fi
  done
}
