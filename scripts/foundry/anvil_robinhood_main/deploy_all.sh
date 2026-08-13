#!/usr/bin/env bash
# =============================================================================
# Anvil Robinhood mainnet fork — Uni V4 DETF + hook staged deploy (chain 4663)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=../../shell/lib/sanitize_dev_accounts.sh
if [[ -f "$REPO_ROOT/scripts/shell/lib/sanitize_dev_accounts.sh" ]]; then
  # shellcheck disable=SC1091
  source "$REPO_ROOT/scripts/shell/lib/sanitize_dev_accounts.sh"
fi

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

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
ANVIL_HOST="${ANVIL_HOST:-127.0.0.1}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
ANVIL_CHAIN_ID="${ANVIL_CHAIN_ID:-4663}"
FOUNDRY_FORK_RPC_ALIAS="${FOUNDRY_FORK_RPC_ALIAS:-robinhood_mainnet_alchemy}"
ANVIL_FORK_URL="${ANVIL_FORK_URL:-}"
if [[ -z "$ANVIL_FORK_URL" ]]; then
  if ! ANVIL_FORK_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_FORK_RPC_ALIAS" 2>/dev/null)"; then
    FOUNDRY_FORK_RPC_ALIAS="robinhood_mainnet"
    ANVIL_FORK_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_FORK_RPC_ALIAS")"
  fi
fi
ANVIL_FORK_BLOCK_NUMBER="${ANVIL_FORK_BLOCK_NUMBER:-20714383}"
ANVIL_COMPUTE_UNITS_PER_SECOND="${ANVIL_COMPUTE_UNITS_PER_SECOND:-50}"
ANVIL_FORK_RETRY_BACKOFF="${ANVIL_FORK_RETRY_BACKOFF:-1000}"
ANVIL_LOG_DIR="${ANVIL_LOG_DIR:-$REPO_ROOT/deployments/anvil_robinhood_main/runtime}"

DEPLOYMENTS_DIR="${DEPLOYMENTS_DIR:-deployments/anvil_robinhood_main}"
export OUT_DIR_OVERRIDE="${OUT_DIR_OVERRIDE:-$DEPLOYMENTS_DIR}"
export NETWORK_PROFILE="${NETWORK_PROFILE:-anvil_robinhood_main}"
export CHAIN_ID="${CHAIN_ID:-4663}"

DEV_ADDRESS="${DEV_ADDRESS:-}"
SENDER="${SENDER:-$DEV_ADDRESS}"
export OWNER="${OWNER:-$DEV_ADDRESS}"
export UI_WALLET="${UI_WALLET:-0x70997970C51812dc3A010C7d01b50e0d17dc79C8}"

BROADCAST_FLAG="--broadcast"
RESTART_ANVIL=0
KILL_ANVIL=0
FORCE=0
FORGE_VERBOSITY=""
COMMAND="all"

usage() {
  cat <<EOF
Usage:
  scripts/shell/anvil_robinhood_main.sh [command] [options]
  scripts/foundry/anvil_robinhood_main/deploy_all.sh [command] [options]

Commands:
  all           Full pipeline stages 00-22 (lab demos + fee-DETF CHIR)
  foundation    Stages 00-03
  assets        Stage 04
  pools         Stages 05-06
  se            Stages 07-09
  packages      Stages 10-12
  demos         Stage 13
  pons-launch   Stage 14 only — pons v1 RICH launch + frontend pons-launch.json (no SE/DETF)
  fee-detf      Stages 14-21 (pons RICH → CHIR live + UI ETH)
  export        Stage 22
  stageNN       Single stage (00-22)

Options:
  --dry-run         Simulate without broadcasting
  --restart-anvil   Kill port + start fresh RH fork at chain id 4663
  --kill-anvil      Kill Anvil and exit
  --force           Re-run stages (purge stage JSON first when restarting)
  -v…-vvvvv         Forge verbosity
  --help, -h

Required env:
  DEV_ADDRESS   Anvil account(0) typically 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

Optional:
  ANVIL_FORK_URL / FOUNDRY_FORK_RPC_ALIAS (default robinhood_mainnet_alchemy)
  ANVIL_FORK_BLOCK_NUMBER (default 20714383)
  RPC_URL (default http://127.0.0.1:8545) — must be localhost for broadcast
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

port_pid() {
  lsof -tiTCP:"$ANVIL_PORT" -sTCP:LISTEN 2>/dev/null || true
}

kill_anvil() {
  local pid
  pid="$(port_pid)"
  if [[ -n "$pid" ]]; then
    log_info "Killing Anvil on port $ANVIL_PORT (pid $pid)"
    kill "$pid" 2>/dev/null || true
    sleep 1
    pid="$(port_pid)"
    if [[ -n "$pid" ]]; then
      kill -9 $pid 2>/dev/null || true
    fi
  else
    log_info "No Anvil process found on port $ANVIL_PORT"
  fi
}

purge_stage_artifacts() {
  local dir="$REPO_ROOT/$DEPLOYMENTS_DIR"
  mkdir -p "$dir"
  local files=("$dir"/[0-9]*.json)
  if [[ -e "${files[0]:-}" ]]; then
    log_info "Purging stage JSONs in $DEPLOYMENTS_DIR"
    rm -f "${files[@]}"
  fi
}

wait_for_rpc() {
  local attempts=0
  until cast block-number --rpc-url "$RPC_URL" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ "$attempts" -ge 120 ]]; then
      log_error "Timed out waiting for Anvil RPC at $RPC_URL"
      if [[ -f "$ANVIL_LOG_DIR/anvil.log" ]]; then
        log_error "Last 30 lines of $ANVIL_LOG_DIR/anvil.log:"
        tail -30 "$ANVIL_LOG_DIR/anvil.log" >&2 || true
      fi
      exit 1
    fi
    sleep 1
  done
}

start_anvil() {
  if cast block-number --rpc-url "$RPC_URL" >/dev/null 2>&1; then
    log_info "Reusing Anvil at $RPC_URL"
    return 0
  fi

  mkdir -p "$ANVIL_LOG_DIR"
  # V4 SE OutFacet exceeds EIP-170 24kb (product size); hermetic tests also run without
  # the mainnet code-size cap. Disable for this local RH fork pipeline only.
  local anvil_cmd=(
    anvil
    --host "$ANVIL_HOST"
    --port "$ANVIL_PORT"
    --chain-id "$ANVIL_CHAIN_ID"
    --fork-url "$ANVIL_FORK_URL"
    --fork-block-number "$ANVIL_FORK_BLOCK_NUMBER"
    --compute-units-per-second "$ANVIL_COMPUTE_UNITS_PER_SECOND"
    --fork-retry-backoff "$ANVIL_FORK_RETRY_BACKOFF"
    --disable-code-size-limit
  )

  log_info "Starting Anvil chain $ANVIL_CHAIN_ID forking $FOUNDRY_FORK_RPC_ALIAS @ block $ANVIL_FORK_BLOCK_NUMBER"
  nohup "${anvil_cmd[@]}" >"$ANVIL_LOG_DIR/anvil.log" 2>&1 &
  wait_for_rpc

  if declare -F sanitize_dev_accounts >/dev/null 2>&1; then
    sanitize_dev_accounts "$RPC_URL" || true
  fi
}

# Pons v1 factory on RH may have launchEnabled=false at recent tip. Forge vm.store does not
# always persist to the Anvil node before broadcast, so set storage via RPC for local fixtures.
ensure_pons_launch_enabled() {
  local factory="${PONS_FACTORY:-0xA5aAb3F0c6EeadF30Ef1D3Eb997108E976351feB}"
  # Empirically: live factory launchEnabled is storage slot 3 (bool).
  local slot="0x0000000000000000000000000000000000000000000000000000000000000003"
  local one="0x0000000000000000000000000000000000000000000000000000000000000001"
  local enabled
  enabled="$(cast call "$factory" "launchEnabled()(bool)" --rpc-url "$RPC_URL" 2>/dev/null || echo "false")"
  if [[ "$enabled" == "true" ]]; then
    log_info "pons launchEnabled already true"
    return 0
  fi
  log_info "Forcing pons launchEnabled=true via anvil_setStorageAt (slot 3)"
  cast rpc anvil_setStorageAt "$factory" "$slot" "$one" --rpc-url "$RPC_URL" >/dev/null
  enabled="$(cast call "$factory" "launchEnabled()(bool)" --rpc-url "$RPC_URL")"
  if [[ "$enabled" != "true" ]]; then
    log_error "Failed to force pons launchEnabled (got $enabled)"
    exit 1
  fi
  log_success "pons launchEnabled forced true"
}

require_localhost_broadcast() {
  if [[ -z "$BROADCAST_FLAG" ]]; then
    return 0
  fi
  case "$RPC_URL" in
    http://127.0.0.1:*|http://localhost:*|https://127.0.0.1:*|https://localhost:*)
      ;;
    *)
      log_error "Refusing broadcast to non-localhost RPC_URL=$RPC_URL (PRD safety)"
      exit 1
      ;;
  esac
}

require_dev_address() {
  if [[ -z "$DEV_ADDRESS" && -z "$SENDER" ]]; then
    log_error "DEV_ADDRESS / SENDER is not set"
    echo "Example: export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    exit 1
  fi
  SENDER="${SENDER:-$DEV_ADDRESS}"
  DEV_ADDRESS="${DEV_ADDRESS:-$SENDER}"
  export SENDER DEV_ADDRESS
  export OWNER="${OWNER:-$DEV_ADDRESS}"
}

run_stage() {
  local label="$1"
  local script_path="$2"
  log_info "Running $label"

  local cmd=(forge script "$script_path" --rpc-url "$RPC_URL")
  if [[ -n "$FORGE_VERBOSITY" ]]; then
    cmd+=("$FORGE_VERBOSITY")
  fi
  if [[ -n "$SENDER" ]]; then
    cmd+=(--unlocked --sender "$SENDER")
  fi
  if [[ -n "$BROADCAST_FLAG" ]]; then
    # Large CREATE3 facets (V4 SE Out / DETF packages) need headroom beyond default 130%.
    cmd+=("$BROADCAST_FLAG" --slow --gas-estimate-multiplier "${GAS_ESTIMATE_MULTIPLIER:-300}")
    # Fork RPC DNS blips break eth_feeHistory / EIP-1559 fee fetch. Prefer legacy + pinned gas.
    cmd+=(--legacy --gas-price "${FORGE_GAS_PRICE:-2000000000}")
  fi

  (
    cd "$REPO_ROOT"
    OUT_DIR_OVERRIDE="$OUT_DIR_OVERRIDE" \
      NETWORK_PROFILE="$NETWORK_PROFILE" \
      SENDER="$SENDER" \
      OWNER="$OWNER" \
      UI_WALLET="$UI_WALLET" \
      FORCE="$FORCE" \
      "${cmd[@]}"
  )
}

stage_script() {
  local n="$1"
  case "$n" in
    00) echo "$SCRIPT_DIR/Script_00_Preflight.s.sol" ;;
    01) echo "$SCRIPT_DIR/Script_01_DeployCraneFoundation.s.sol" ;;
    02) echo "$SCRIPT_DIR/Script_02_DeployIndexedexCore.s.sol" ;;
    03) echo "$SCRIPT_DIR/Script_03_DeployHookFactory.s.sol" ;;
    04) echo "$SCRIPT_DIR/Script_04_DeployTestTokens.s.sol" ;;
    05) echo "$SCRIPT_DIR/Script_05_DeployUniV3PoolsAndSeed.s.sol" ;;
    06) echo "$SCRIPT_DIR/Script_06_DeployUniV4PoolsAndSeed.s.sol" ;;
    07) echo "$SCRIPT_DIR/Script_07_DeployUniV3StandardExchange.s.sol" ;;
    08) echo "$SCRIPT_DIR/Script_08_DeployUniV4StandardExchange.s.sol" ;;
    09) echo "$SCRIPT_DIR/Script_09_DeployRateProviders.s.sol" ;;
    10) echo "$SCRIPT_DIR/Script_10_DeployHookPackages.s.sol" ;;
    11) echo "$SCRIPT_DIR/Script_11_DeployDetfChildren.s.sol" ;;
    12) echo "$SCRIPT_DIR/Script_12_DeployDetfPackages.s.sol" ;;
    13) echo "$SCRIPT_DIR/Script_13_DeployInertDemos.s.sol" ;;
    14) echo "$SCRIPT_DIR/Script_14_PonsLaunchRich.s.sol" ;;
    15) echo "$SCRIPT_DIR/Script_15_DeployUniV3SeOnRichPool.s.sol" ;;
    16) echo "$SCRIPT_DIR/Script_16_DeployFeeDetfRateProvider.s.sol" ;;
    17) echo "$SCRIPT_DIR/Script_17_DeployFeeDetfPackage.s.sol" ;;
    18) echo "$SCRIPT_DIR/Script_18_DeployChirInstance.s.sol" ;;
    19) echo "$SCRIPT_DIR/Script_19_BootstrapMarketBuyRich.s.sol" ;;
    20) echo "$SCRIPT_DIR/Script_20_BootstrapFirstBond.s.sol" ;;
    21) echo "$SCRIPT_DIR/Script_21_FundUiWalletEth.s.sol" ;;
    22) echo "$SCRIPT_DIR/Script_22_ExportFrontendArtifacts.s.sol" ;;
    *)
      log_error "Unknown stage $n"
      exit 1
      ;;
  esac
}

run_stages() {
  local stages=("$@")
  for n in "${stages[@]}"; do
    run_stage "Stage $n" "$(stage_script "$n")"
  done
}

# --- args ---
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    all|foundation|assets|pools|se|packages|demos|pons-launch|fee-detf|export)
      COMMAND="$1"
      shift
      ;;
    stage[0-9][0-9]|stage[0-9])
      COMMAND="$1"
      shift
      ;;
    --dry-run)
      BROADCAST_FLAG=""
      shift
      ;;
    --restart-anvil)
      RESTART_ANVIL=1
      shift
      ;;
    --kill-anvil)
      KILL_ANVIL=1
      shift
      ;;
    --force)
      FORCE=1
      export FORCE=1
      shift
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

if [[ "$KILL_ANVIL" -eq 1 ]]; then
  kill_anvil
  exit 0
fi

require_dev_address
require_localhost_broadcast

if [[ "$RESTART_ANVIL" -eq 1 ]]; then
  kill_anvil
  purge_stage_artifacts
fi

start_anvil

# Guard chain id
CID="$(cast chain-id --rpc-url "$RPC_URL")"
if [[ "$CID" != "4663" ]]; then
  log_error "Expected chain id 4663, got $CID — start Anvil with --chain-id 4663"
  exit 1
fi
log_success "Anvil chain id $CID"

log_header "Anvil Robinhood deploy: $COMMAND"
log_info "SENDER=$SENDER OUT_DIR=$OUT_DIR_OVERRIDE"

case "$COMMAND" in
  all)
    # Lab path (inert demos) then fee-DETF (CHIR live) then unified export
    # Stage 14 needs public launches open (or force-enabled on Anvil).
    ensure_pons_launch_enabled
    run_stages 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22
    ;;
  foundation)
    run_stages 00 01 02 03
    ;;
  assets)
    run_stages 04
    ;;
  pools)
    run_stages 05 06
    ;;
  se)
    run_stages 07 08 09
    ;;
  packages)
    run_stages 10 11 12
    ;;
  demos)
    run_stages 13
    ;;
  pons-launch)
    # Launch-only: pons v1 RICH + frontend buy-page artifact. No SE wrap / DETF / market buy.
    ensure_pons_launch_enabled
    run_stages 14
    ;;
  fee-detf)
    # Requires foundation + stage 11 children (bond NFT / claim pkgs)
    ensure_pons_launch_enabled
    run_stages 14 15 16 17 18 19 20 21
    ;;
  export)
    run_stages 22
    ;;
  stage*)
    n="${COMMAND#stage}"
    # zero-pad if single digit
    if [[ ${#n} -eq 1 ]]; then
      n="0$n"
    fi
    run_stages "$n"
    ;;
  *)
    log_error "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac

log_success "Command '$COMMAND' completed"
exit 0
