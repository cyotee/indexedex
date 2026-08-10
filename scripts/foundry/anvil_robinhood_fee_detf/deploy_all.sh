#!/usr/bin/env bash
# =============================================================================
# Anvil Robinhood fee-DETF launch — pons RICH + Uni V3 SE + Buffer CP + CHIR
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
ANVIL_LOG_DIR="${ANVIL_LOG_DIR:-$REPO_ROOT/deployments/anvil_robinhood_fee_detf/runtime}"

DEPLOYMENTS_DIR="${DEPLOYMENTS_DIR:-deployments/anvil_robinhood_fee_detf}"
export OUT_DIR_OVERRIDE="${OUT_DIR_OVERRIDE:-$DEPLOYMENTS_DIR}"
export NETWORK_PROFILE="${NETWORK_PROFILE:-anvil_robinhood_fee_detf}"
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
  scripts/shell/anvil_robinhood_fee_detf.sh [command] [options]
  scripts/foundry/anvil_robinhood_fee_detf/deploy_all.sh [command] [options]

Commands:
  all           Full pipeline stages 00-13
  foundation    Stages 00-03
  pons          Stage 04
  se            Stages 05-06
  packages      Stages 07-08
  instance      Stage 09
  bootstrap     Stages 10-12
  export        Stage 13
  stageNN       Single stage (00-13)

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
  CREATION_PAIR_PER_DETF_WAD (default 10e18)
  LARGE_RICH_BUY_WETH / FIRST_BOND_WETH
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
    # shellcheck disable=SC2086
    kill $pid 2>/dev/null || true
    sleep 1
    pid="$(port_pid)"
    if [[ -n "$pid" ]]; then
      # shellcheck disable=SC2086
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

require_localhost_broadcast() {
  if [[ -z "$BROADCAST_FLAG" ]]; then
    return 0
  fi
  case "$RPC_URL" in
    http://127.0.0.1:*|http://localhost:*|https://127.0.0.1:*|https://localhost:*)
      ;;
    *)
      log_error "Refusing broadcast to non-localhost RPC_URL=$RPC_URL (safety)"
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
    cmd+=("$BROADCAST_FLAG" --slow --gas-estimate-multiplier "${GAS_ESTIMATE_MULTIPLIER:-300}")
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
    03) echo "$SCRIPT_DIR/Script_03_DeployHookDiamondFactory.s.sol" ;;
    04) echo "$SCRIPT_DIR/Script_04_PonsLaunchRich.s.sol" ;;
    05) echo "$SCRIPT_DIR/Script_05_DeployUniV3SeOnRichPool.s.sol" ;;
    06) echo "$SCRIPT_DIR/Script_06_DeployRateProvider.s.sol" ;;
    07) echo "$SCRIPT_DIR/Script_07_DeployFeeDetfChildren.s.sol" ;;
    08) echo "$SCRIPT_DIR/Script_08_DeployFeeDetfPackage.s.sol" ;;
    09) echo "$SCRIPT_DIR/Script_09_DeployChirInstance.s.sol" ;;
    10) echo "$SCRIPT_DIR/Script_10_BootstrapMarketBuyRich.s.sol" ;;
    11) echo "$SCRIPT_DIR/Script_11_BootstrapFirstBond.s.sol" ;;
    12) echo "$SCRIPT_DIR/Script_12_FundUiWalletEth.s.sol" ;;
    13) echo "$SCRIPT_DIR/Script_13_ExportFrontendArtifacts.s.sol" ;;
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
while [[ $# -gt 0 ]]; do
  case "$1" in
    all|foundation|pons|se|packages|instance|bootstrap|export)
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

CID="$(cast chain-id --rpc-url "$RPC_URL")"
if [[ "$CID" != "4663" ]]; then
  log_error "Expected chain id 4663, got $CID — start Anvil with --chain-id 4663"
  exit 1
fi
log_success "Anvil chain id $CID"

log_header "Anvil Robinhood fee-DETF deploy: $COMMAND"
log_info "SENDER=$SENDER OUT_DIR=$OUT_DIR_OVERRIDE"

case "$COMMAND" in
  all)
    run_stages 00 01 02 03 04 05 06 07 08 09 10 11 12 13
    ;;
  foundation)
    run_stages 00 01 02 03
    ;;
  pons)
    run_stages 04
    ;;
  se)
    run_stages 05 06
    ;;
  packages)
    run_stages 07 08
    ;;
  instance)
    run_stages 09
    ;;
  bootstrap)
    run_stages 10 11 12
    ;;
  export)
    run_stages 13
    ;;
  stage*)
    n="${COMMAND#stage}"
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
echo ""
log_info "Artifacts: $REPO_ROOT/$DEPLOYMENTS_DIR"
log_info "Frontend: frontend/packages/protocol/src/addresses/chain/4663/"
log_info "UI wallet #1: $UI_WALLET — RPC http://127.0.0.1:8545 chain 4663"
exit 0
