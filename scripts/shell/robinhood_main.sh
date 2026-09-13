#!/usr/bin/env bash
# =============================================================================
# Public Robinhood Chain mainnet (4663) architecture launch.
# No Phase 00. --sender $DEPLOYER_ADDRESS (cast wallet).
# Catalog: pins, Crane factories, FeeCollector, Manager, TWAP, Uni V4 SE pkg,
# Morpho Blue SE pkg, CP/Weighted/Curve Quad hook pkgs, unified Uni V4 DETF pkg.
# No tokens. No Protocol DETF instances.
# Opt-in: token-staking (Phase 06-08 DFPkg + Phase 08-01 $DTF instance).
# Simulate each Foundry Stage then broadcast. Never --skip-simulation.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RH_FOUNDRY_DIR="$REPO_ROOT/scripts/foundry/anvil_robinhood_main"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/shell/lib/rh_4663_stages.sh"

resolve_foundry_rpc_alias() {
  local alias_name="$1"
  local template
  local resolved
  template="$(cd "$REPO_ROOT" && forge config --json | jq -r --arg alias_name "$alias_name" '.rpc_endpoints[$alias_name] // empty')"
  if [[ -z "$template" || "$template" == "null" ]]; then
    echo "Foundry RPC alias not found: $alias_name" >&2
    return 1
  fi
  resolved="$(eval "printf '%s' \"$template\"")"
  if [[ "$resolved" == *'${'* ]]; then
    echo "Foundry RPC alias could not be fully resolved: $alias_name" >&2
    return 1
  fi
  echo "$resolved"
}

if [[ -z "${RPC_URL:-}" ]]; then
  RPC_URL="$(resolve_foundry_rpc_alias robinhood_mainnet)"
fi
export RPC_URL

DEPLOYMENTS_DIR="${DEPLOYMENTS_DIR:-deployments/anvil_robinhood_main}"
export OUT_DIR_OVERRIDE="${OUT_DIR_OVERRIDE:-$DEPLOYMENTS_DIR}"
export NETWORK_PROFILE="${NETWORK_PROFILE:-anvil_robinhood_main}"
export CHAIN_ID="${CHAIN_ID:-4663}"

BROADCAST_FLAG="--broadcast"
BROADCAST_EXPLICIT=0
FORCE=0
FROM_PHASE=""
FROM_STAGE=""
FORGE_VERBOSITY=""
COMMAND="all"

usage() {
  cat <<EOF
Usage:
  scripts/shell/robinhood_main.sh [command] [options]

Public 4663 architecture path. Does not run Phase 00. Requires DEPLOYER_ADDRESS.
Deploys Crane factories, FeeCollector, Manager, TWAP oracle, Uni V4 SE package,
Morpho Blue SE package, CP / Weighted / Curve Quad hook packages, and the
unified Uni V4 DETF package.
No tokens. No Protocol DETF instances.

Commands:
  all             Phases 01–06 architecture catalog, then Phase 09 frontend export
  token-staking        Phase 06 Stage 08 TokenStaking DFPkg, then Phase 08 Stage 01
                       DTF instance (7-day rewardsDuration). Does not notifyRewardAmount.
                       Same as forge script: simulates unless --broadcast.
  token-staking-fund   Phase 08 Stage 02: notifyRewardAmount(sender DTF balance).
                       Same as forge script: simulates unless --broadcast.
  fee-accrual-preflight Read-only validation of the prepared fee-accrual deployment.
  fee-accrual-reconcile Verify receipts and record the reviewed deadline-script update (no broadcast).
  fee-accrual-launch   Packages, composition, first bond and full staking migration.
                       Uses the checked-in launch config and default deployment directory.
                       Requires funded WETH/DTF, DEPLOYER_ADDRESS and --broadcast.
  fee-accrual-packages Deploy prerequisite packages through the existing core, then export pins.
  fee-accrual-prepare  Deploy SEs, providers, reserve hook, DETF and purchase the first bond.
  fee-accrual-migrate   Adapter, snapshot, combined deposits/rewards migration, verification.
                       Requires DEPLOYER_ADDRESS and --broadcast. DETF must be bootstrapped.
                       Defaults to the full launch's resolved config and composition records.
  fee-accrual-verify    Read-only final state and migration receipt reconciliation.

Options:
  --broadcast       Send transactions after a successful simulate
  --dry-run         Architecture \`all\` only: simulate, do not broadcast
  --rpc-url URL     Broadcast RPC (default Foundry alias robinhood_mainnet)
  --force           FORCE=1 re-run Stages
  --from-phase PP   Resume at Phase PP
  --from-stage SS   Resume at Stage SS of --from-phase
  -v…-vvvvv         Forge verbosity
  --help, -h
EOF
}

log_info() { printf '[INFO] %s\n' "$1"; }
log_error() { printf '[ERROR] %s\n' "$1" >&2; }
log_success() { printf '[SUCCESS] %s\n' "$1"; }
log_header() {
  echo ""
  echo "============================================================================="
  echo " $1"
  echo "============================================================================="
}

if [[ -z "${DEPLOYER_ADDRESS:-}" ]]; then
  log_error "robinhood_main.sh requires DEPLOYER_ADDRESS"
  echo "Example: export DEPLOYER_ADDRESS=0x..."
  echo "Forge uses --sender \$DEPLOYER_ADDRESS; cast wallet signs."
  exit 1
fi

SENDER="$DEPLOYER_ADDRESS"
DEV_ADDRESS="${DEV_ADDRESS:-$DEPLOYER_ADDRESS}"
OWNER="${OWNER:-$DEPLOYER_ADDRESS}"
UI_WALLET="${UI_WALLET:-$DEPLOYER_ADDRESS}"
export DEPLOYER_ADDRESS SENDER DEV_ADDRESS OWNER UI_WALLET

run_forge_cmd() {
  (
    cd "$REPO_ROOT"
    OUT_DIR_OVERRIDE="$OUT_DIR_OVERRIDE" \
      NETWORK_PROFILE="$NETWORK_PROFILE" \
      DEPLOYER_ADDRESS="$DEPLOYER_ADDRESS" \
      SENDER="$SENDER" \
      DEV_ADDRESS="$DEV_ADDRESS" \
      OWNER="$OWNER" \
      UI_WALLET="$UI_WALLET" \
      FORCE="$FORCE" \
      RPC_URL="$RPC_URL" \
      "$@"
  )
}

is_transient_rpc_error_log() {
  local file="$1"
  grep -qiE 'dns error|nodename nor servname|failed to lookup|error sending request|client error \(Connect\)|timed out|timeout|connection reset|429' "$file"
}

run_forge_with_retries() {
  local attempt=1
  local max="${FORGE_RPC_RETRIES:-6}"
  local sleep_s="${FORGE_RPC_RETRY_SLEEP:-8}"
  local tmp st
  tmp="$(mktemp)"
  while true; do
    set +e
    run_forge_cmd "$@" 2>&1 | tee "$tmp"
    st=${PIPESTATUS[0]}
    set -e
    if [[ "$st" -eq 0 ]]; then
      rm -f "$tmp"
      return 0
    fi
    if [[ "$attempt" -ge "$max" ]] || ! is_transient_rpc_error_log "$tmp"; then
      rm -f "$tmp"
      return "$st"
    fi
    log_info "Transient RPC/DNS error (attempt $attempt/$max). Retry in ${sleep_s}s"
    sleep "$sleep_s"
    attempt=$((attempt + 1))
  done
}

forge_script_base() {
  local script_path="$1"
  local cmd=(forge script "$script_path" --rpc-url "$RPC_URL")
  if [[ -n "$FORGE_VERBOSITY" ]]; then
    cmd+=("$FORGE_VERBOSITY")
  fi
  cmd+=(--sender "$DEPLOYER_ADDRESS" --non-interactive)
  printf '%s\n' "${cmd[@]}"
}

run_stage() {
  local label="$1"
  local script_path="$2"
  local sim_cmd=()
  local bcast_cmd=()
  local line

  while IFS= read -r line; do
    sim_cmd+=("$line")
  done < <(forge_script_base "$script_path")

  log_info "Simulating $label"
  if ! run_forge_with_retries "${sim_cmd[@]}"; then
    log_error "$label simulation failed; not broadcasting"
    return 1
  fi
  log_success "$label simulation passed"

  if [[ -z "$BROADCAST_FLAG" ]]; then
    log_info "$label dry-run complete (no broadcast)"
    return 0
  fi

  bcast_cmd=("${sim_cmd[@]}")
  bcast_cmd+=("$BROADCAST_FLAG" --slow --gas-estimate-multiplier "${GAS_ESTIMATE_MULTIPLIER:-300}")

  log_info "Broadcasting $label"
  run_forge_with_retries "${bcast_cmd[@]}"
}

# Public migration uses the same sender/signing convention as the existing public stages.
fee_accrual_check() {
  python3 "$REPO_ROOT/scripts/shell/lib/rh_4663_fee_accrual.py" --public "$@"
}

fee_accrual_stage() {
  local pp="$1" ss="$2" mode="$3" script record before_hash="" multiplier=150
  [[ "$pp-$ss" != 08-03 ]] || multiplier=100
  script="$(rh_stage_script "$pp" "$ss")"
  record="$FOUNDRY_BROADCAST/$(basename "$script")/4663/run-latest.json"
  local args=() line
  while IFS= read -r line; do
    args+=("$line")
  done < <(forge_script_base "$script")
  args+=(--gas-estimate-multiplier "$multiplier")
  # Skip explorer/Sourcify trace lookups that consume transaction deadlines.
  # --offline still performs RPC execution, simulation and broadcast.
  args+=(--offline)
  if [[ "$mode" == broadcast && "$pp-$ss" != 08-07 ]]; then
    local prior_status=0
    fee_accrual_check stage-complete "$pp-$ss" >/dev/null 2>&1 || prior_status=$?
    if [[ "$prior_status" == 0 ]]; then
      # Confirmed money stages must never seed liquidity or buy a second first bond.
      if [[ "$pp-$ss" == 07-04 || "$pp-$ss" == 08-04 ]]; then return; fi
      run_forge_cmd "${args[@]}"
      return
    elif [[ "$prior_status" != 3 ]]; then
      log_error "Prior stage receipt validation failed for $pp-$ss; reconcile before continuing"
      return "$prior_status"
    fi
  fi
  if [[ "$mode" == read ]]; then
    run_forge_cmd "${args[@]}"
    return
  fi
  # Do not automatically retry a money stage after partial submission. Reconcile first.
  run_forge_cmd "${args[@]}" || return $?
  [[ ! -f "$record" ]] || before_hash="$(shasum -a 256 "$record")"
  run_forge_cmd "${args[@]}" --broadcast --slow || return $?
  [[ -f "$record" && "$(shasum -a 256 "$record")" != "$before_hash" ]] || {
    log_error "No fresh broadcast record; reconcile before continuing"; return 1;
  }
  fee_accrual_check receipts "$pp-$ss" "$record"
}

run_fee_accrual() {
  local default_root="$REPO_ROOT/deployments/robinhood_main_fee_accrual"
  case "$COMMAND" in
    fee-accrual-launch|fee-accrual-preflight|fee-accrual-reconcile)
      export FEE_ACCRUAL_RUN_DIR="${FEE_ACCRUAL_RUN_DIR:-$default_root}"
      export FEE_ACCRUAL_CONFIG="${FEE_ACCRUAL_CONFIG:-$RH_FOUNDRY_DIR/fee_accrual_launch.robinhood.json}"
      ;;
    fee-accrual-packages)
      export FEE_ACCRUAL_RUN_DIR="${FEE_ACCRUAL_RUN_DIR:-$default_root/packages}"
      export FEE_ACCRUAL_CONFIG="${FEE_ACCRUAL_CONFIG:-$RH_FOUNDRY_DIR/fee_accrual_launch.robinhood.json}"
      ;;
    *)
      export FEE_ACCRUAL_RUN_DIR="${FEE_ACCRUAL_RUN_DIR:-$default_root/composition}"
      export FEE_ACCRUAL_PACKAGE_DIR="${FEE_ACCRUAL_PACKAGE_DIR:-$(dirname "$FEE_ACCRUAL_RUN_DIR")/packages}"
      export FEE_ACCRUAL_CONFIG="${FEE_ACCRUAL_CONFIG:-$FEE_ACCRUAL_PACKAGE_DIR/fee-accrual-config.resolved.json}"
      ;;
  esac
  [[ -f "$FEE_ACCRUAL_CONFIG" ]] || {
    log_error "Missing fee-accrual config: $FEE_ACCRUAL_CONFIG (run fee-accrual-launch for the full deployment)"; return 1;
  }
  [[ "$FORCE" == 0 && -z "$FROM_PHASE$FROM_STAGE" ]] || {
    log_error "Fee accrual uses its receipt journal; --force and stage skipping are unsupported"; return 1;
  }
  if [[ "$COMMAND" != fee-accrual-preflight && "$COMMAND" != fee-accrual-verify && "$COMMAND" != fee-accrual-reconcile ]]; then
    [[ "$BROADCAST_EXPLICIT" == 1 && "$BROADCAST_FLAG" == --broadcast ]] || {
      log_error "$COMMAND requires explicit --broadcast"; return 1;
    }
  fi
  export OUT_DIR_OVERRIDE="$FEE_ACCRUAL_RUN_DIR"
  export FOUNDRY_BROADCAST="$OUT_DIR_OVERRIDE/broadcast"
  # Prevent PRIVATE_KEY from overriding --sender inside DeploymentBase._broadcast().
  export PRIVATE_KEY=0 OWNER="$DEPLOYER_ADDRESS" SENDER="$DEPLOYER_ADDRESS"
  if [[ "$COMMAND" == fee-accrual-reconcile ]]; then
    OUT_DIR_OVERRIDE="$FEE_ACCRUAL_RUN_DIR/packages" fee_accrual_check reconcile-scripts || return $?
    OUT_DIR_OVERRIDE="$FEE_ACCRUAL_RUN_DIR/composition" \
      FEE_ACCRUAL_CONFIG="$FEE_ACCRUAL_RUN_DIR/packages/fee-accrual-config.resolved.json" \
      fee_accrual_check reconcile-scripts
    return $?
  fi
  if [[ "$COMMAND" == fee-accrual-launch ]]; then
    # Separate immutable config/journal identities before and after package-address resolution.
    local root="$FEE_ACCRUAL_RUN_DIR"
    FEE_ACCRUAL_RUN_DIR="$root/packages" bash "$SCRIPT_DIR/robinhood_main.sh" fee-accrual-packages --broadcast || return $?
    export FEE_ACCRUAL_CONFIG="$root/packages/fee-accrual-config.resolved.json"
    export FEE_ACCRUAL_PACKAGE_DIR="$root/packages"
    FEE_ACCRUAL_RUN_DIR="$root/composition" bash "$SCRIPT_DIR/robinhood_main.sh" fee-accrual-prepare --broadcast || return $?
    FEE_ACCRUAL_RUN_DIR="$root/composition" bash "$SCRIPT_DIR/robinhood_main.sh" fee-accrual-migrate --broadcast
    return $?
  fi
  fee_accrual_check preflight || return $?
  if [[ "$COMMAND" == fee-accrual-packages ]]; then
    fee_accrual_check launch-config || return $?
    fee_accrual_stage 01 04 read || return $?
    rh_fee_accrual_copy_core || return $?
    build_rehearsal_artifacts || return $?
    run_forge_cmd forge build contracts/protocols/staking/rebasingVault/*.sol || return $?
    local pp ss
    while read -r pp ss; do
      fee_accrual_stage "$pp" "$ss" broadcast || return $?
    done <<'PACKAGES'
05 01
05 03
06 01
06 02
06 04
06 07
06 10
PACKAGES
    fee_accrual_check pin-packages
    return
  fi
  if [[ "$COMMAND" == fee-accrual-preflight ]]; then
    fee_accrual_stage 01 04 read
    return
  fi
  fee_accrual_check ready || return $?
  if [[ "$COMMAND" == fee-accrual-prepare ]]; then
    fee_accrual_check launch-config || return $?
    local package_dir="${FEE_ACCRUAL_PACKAGE_DIR:?Set FEE_ACCRUAL_PACKAGE_DIR}" manifest=phase06_stage01_bond_nft_pkg.json
    if [[ -f "$OUT_DIR_OVERRIDE/$manifest" ]]; then
      cmp -s "$package_dir/$manifest" "$OUT_DIR_OVERRIDE/$manifest" || { log_error "Conflicting bond package manifest"; return 1; }
    else
      cp "$package_dir/$manifest" "$OUT_DIR_OVERRIDE/$manifest" || return $?
    fi
    fee_accrual_stage 07 01 broadcast || return $?
    fee_accrual_stage 07 02 broadcast || return $?
    fee_accrual_stage 07 03 broadcast || return $?
    fee_accrual_stage 07 04 broadcast || return $?
    fee_accrual_stage 08 03 broadcast || return $?
    fee_accrual_stage 08 04 broadcast || return $?
    fee_accrual_stage 09 02 read
    return
  elif [[ "$COMMAND" == fee-accrual-verify ]]; then
    fee_accrual_stage 08 08 read && fee_accrual_check verify
    return
  fi
  local configured_target actual_detf remaining
  configured_target="$(cast call "$(jq -er '.tokenStaking' "$FEE_ACCRUAL_CONFIG")" 'targetDetf()(address)' --rpc-url "$RPC_URL")"
  actual_detf="$(jq -er '.feeDetf' "$OUT_DIR_OVERRIDE/phase08_stage03_fee_accrual_detf.json")"
  if [[ "$(printf '%s' "$configured_target" | tr '[:upper:]' '[:lower:]')" == "$(printf '%s' "$actual_detf" | tr '[:upper:]' '[:lower:]')" || "$configured_target" == 0x0000000000000000000000000000000000000000 ]]; then
    fee_accrual_stage 08 05 broadcast || return $?
  else
    fee_accrual_stage 08 05 read || return $?
  fi
  fee_accrual_stage 08 06 read || return $?
  fee_accrual_check begin-migration || return $?
  remaining="$(fee_accrual_check remaining)" || return $?
  while [[ "$remaining" != 0 ]]; do
    local before_remaining="$remaining"
    fee_accrual_stage 08 07 broadcast || return $?
    remaining="$(fee_accrual_check remaining)" || return $?
    [[ "$remaining" != "$before_remaining" ]] || { log_error "Migration made no progress; stopped"; return 1; }
  done
  fee_accrual_stage 08 08 read && fee_accrual_check verify
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    all|token-staking|token-staking-fund|fee-accrual-preflight|fee-accrual-packages|fee-accrual-prepare|fee-accrual-launch|fee-accrual-migrate|fee-accrual-verify|fee-accrual-reconcile)
      COMMAND="$1"
      shift
      ;;
    --broadcast)
      BROADCAST_FLAG="--broadcast"
      BROADCAST_EXPLICIT=1
      shift
      ;;
    --dry-run)
      BROADCAST_FLAG=""
      shift
      ;;
    --rpc-url)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        log_error "--rpc-url requires a URL"
        exit 1
      fi
      RPC_URL="$2"
      export RPC_URL
      shift 2
      ;;
    --rpc-url=*)
      RPC_URL="${1#--rpc-url=}"
      export RPC_URL
      shift
      ;;
    --force)
      FORCE=1
      export FORCE=1
      shift
      ;;
    --from-phase)
      FROM_PHASE="$(printf '%02d' "$((10#$2))")"
      FROM_STAGE="${FROM_STAGE:-01}"
      shift 2
      ;;
    --from-stage)
      FROM_STAGE="$(printf '%02d' "$((10#$2))")"
      shift 2
      ;;
    -v|-vv|-vvv|-vvvv|-vvvvv)
      FORGE_VERBOSITY="$1"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

# token-staking matches forge script: simulate unless --broadcast.
if [[ "$COMMAND" == "token-staking" || "$COMMAND" == "token-staking-fund" ]] && [[ "$BROADCAST_EXPLICIT" -eq 0 ]]; then
  BROADCAST_FLAG=""
fi

log_header "Public Robinhood mainnet (4663) architecture: $COMMAND"
log_info "SENDER=$DEPLOYER_ADDRESS OUT_DIR=$OUT_DIR_OVERRIDE (no Phase 00)"

CID="$(cast chain-id --rpc-url "$RPC_URL" | tr -d '[:space:]')"
if [[ "$CID" != "4663" ]]; then
  log_error "Expected chain id 4663, got ${CID:-<empty>}"
  exit 1
fi

case "$COMMAND" in
  all)
    rh_run_catalog 0 "$FROM_PHASE" "$FROM_STAGE"
    ;;
  token-staking)
    rh_run_token_staking
    ;;
  token-staking-fund)
    rh_run_token_staking_fund
    ;;
  fee-accrual-*)
    run_fee_accrual
    ;;
  *)
    log_error "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac

log_success "Command '$COMMAND' completed"
exit 0
