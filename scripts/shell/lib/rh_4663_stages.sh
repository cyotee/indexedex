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
