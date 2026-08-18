#!/usr/bin/env bash
# =============================================================================
# Anvil Robinhood Testnet fork — 46630 launch groups 00-09
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

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
ANVIL_CHAIN_ID="${ANVIL_CHAIN_ID:-46630}"
FOUNDRY_FORK_RPC_ALIAS="${FOUNDRY_FORK_RPC_ALIAS:-robinhood_testnet_alchemy}"
ANVIL_FORK_URL="${ANVIL_FORK_URL:-}"
CLI_FORK_ALIAS=""
# D35: Crane ROBINHOOD_TESTNET.DEFAULT_FORK_BLOCK. Public RPCs do not keep this
# archive window — start_anvil retargets the pin on the public fallback.
ANVIL_FORK_BLOCK_NUMBER="${ANVIL_FORK_BLOCK_NUMBER:-101800000}"
ANVIL_PUBLIC_PIN_LAG="${ANVIL_PUBLIC_PIN_LAG:-64}"
ANVIL_ALCHEMY_START_ATTEMPTS="${ANVIL_ALCHEMY_START_ATTEMPTS:-3}"
# 50 CU/s starves fork storage reads (Mag7 deployVault looks hung). Alchemy default is 330.
ANVIL_COMPUTE_UNITS_PER_SECOND="${ANVIL_COMPUTE_UNITS_PER_SECOND:-330}"
ANVIL_FORK_RETRY_BACKOFF="${ANVIL_FORK_RETRY_BACKOFF:-1000}"
ANVIL_LOG_DIR="${ANVIL_LOG_DIR:-$REPO_ROOT/deployments/anvil_robinhood_testnet/runtime}"

DEPLOYMENTS_DIR="${DEPLOYMENTS_DIR:-deployments/anvil_robinhood_testnet}"
export OUT_DIR_OVERRIDE="${OUT_DIR_OVERRIDE:-$DEPLOYMENTS_DIR}"
export NETWORK_PROFILE="${NETWORK_PROFILE:-anvil_robinhood_testnet}"
export CHAIN_ID="${CHAIN_ID:-46630}"
export RPC_URL

DEV_ADDRESS="${DEV_ADDRESS:-}"
SENDER="${SENDER:-$DEV_ADDRESS}"
export OWNER="${OWNER:-$DEV_ADDRESS}"
export UI_WALLET="${UI_WALLET:-0x70997970C51812dc3A010C7d01b50e0d17dc79C8}"

BROADCAST_FLAG="--broadcast"
RESTART_ANVIL=0
KILL_ANVIL=0
FORCE=0
FORK_LATEST=0
FORGE_VERBOSITY=""
COMMAND="all"

usage() {
  cat <<EOF
Usage:
  scripts/shell/anvil_robinhood_testnet.sh [command] [options]
  scripts/foundry/anvil_robinhood_testnet/deploy_all.sh [command] [options]

Commands:
  all           Every launch script: 00-05, 06a-c, 06e, 06, 07, 08, SimulateLaunch, 09 (no 06d / TTM7-W)
  foundation    Groups 00-03
  assets        Group 04
  pools         Group 05
  leaves        Script_06 + 06a-e
  nests         Group 07
  feesink       Group 08
  simulate      Script_SimulateLaunch (01-08)
  export        Group 09
  stageNN       Single group (00-09, 06a-e)
  stagesimulate Script_SimulateLaunch

Options:
  --dry-run         Simulate without broadcasting
  --restart-anvil   Kill port + start fresh RH testnet fork at chain id 46630
  --kill-anvil      Kill Anvil and exit
  --force           Re-run stages (purge stage JSON first when restarting)
  --fork-alias NAME Foundry [rpc_endpoints] alias (default robinhood_testnet_alchemy)
  --public-rpc      Same as --fork-alias robinhood_testnet (official public RPC)
  --fork-latest     Do not pass --fork-block-number; Anvil uses the remote tip
  -v…-vvvvv         Forge verbosity
  --help, -h

Required env:
  DEV_ADDRESS   Anvil account(0) typically 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  ALCHEMY_KEY   For robinhood_testnet_alchemy (not needed with --public-rpc)

Optional:
  ANVIL_FORK_URL / FOUNDRY_FORK_RPC_ALIAS (default robinhood_testnet_alchemy)
  ANVIL_FORK_BLOCK_NUMBER (default Crane pin; set to latest to omit the pin)
  RPC_URL (default http://127.0.0.1:8545) — must be localhost for broadcast
  --public-rpc without --fork-latest retargets the pin to head-64.
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
    kill $pid 2>/dev/null || true
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

# Bound `cast` so a wedged Anvil cannot hang the until-loop (macOS has no GNU timeout).
cast_bounded() {
  perl -e 'alarm shift; exec @ARGV' 5 cast "$@"
}

dump_anvil_log() {
  if [[ -f "$ANVIL_LOG_DIR/anvil.log" ]]; then
    log_error "Last 30 lines of $ANVIL_LOG_DIR/anvil.log:"
    tail -30 "$ANVIL_LOG_DIR/anvil.log" >&2 || true
  fi
}

wait_for_rpc() {
  local pid="${1:-}"
  local attempts=0
  until cast_bounded block-number --rpc-url "$RPC_URL" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ "$pid" =~ ^[0-9]+$ ]] && ! kill -0 "$pid" 2>/dev/null; then
      log_error "Anvil exited before RPC was ready (pid $pid)"
      dump_anvil_log
      return 1
    fi
    if [[ "$attempts" -ge 120 ]]; then
      log_error "Timed out waiting for Anvil RPC at $RPC_URL"
      dump_anvil_log
      return 1
    fi
    sleep 1
  done
  return 0
}

rpc_block_number() {
  local url="$1"
  perl -e 'alarm shift; exec @ARGV' 8 cast block-number --rpc-url "$url" 2>/dev/null
}

# Public 46630 nodes prune historical state. Pin a few blocks behind tip (D35: still pinned).
retarget_pin_for_public() {
  local head
  head="$(rpc_block_number "$ANVIL_FORK_URL" || true)"
  if [[ ! "$head" =~ ^[0-9]+$ ]]; then
    log_error "Could not read head from $ANVIL_FORK_URL"
    return 1
  fi
  local lag="$ANVIL_PUBLIC_PIN_LAG"
  if (( head > lag )); then
    ANVIL_FORK_BLOCK_NUMBER=$((head - lag))
  else
    ANVIL_FORK_BLOCK_NUMBER="$head"
  fi
  log_info "Public RPC has no archive at 101800000; pinning $ANVIL_FORK_BLOCK_NUMBER (head $head - $lag)"
}

# stdout is the child pid only — do not log here (callers capture stdout).
launch_anvil() {
  local fork_url="$1"
  local fork_block="${2:-$ANVIL_FORK_BLOCK_NUMBER}"
  local anvil_cmd=(
    anvil
    --host "$ANVIL_HOST"
    --port "$ANVIL_PORT"
    --chain-id "$ANVIL_CHAIN_ID"
    --fork-url "$fork_url"
    --compute-units-per-second "$ANVIL_COMPUTE_UNITS_PER_SECOND"
    --fork-retry-backoff "$ANVIL_FORK_RETRY_BACKOFF"
    --disable-code-size-limit
  )
  if [[ "$FORK_LATEST" -eq 0 && -n "$fork_block" && "$fork_block" != "latest" ]]; then
    anvil_cmd+=(--fork-block-number "$fork_block")
  fi
  nohup "${anvil_cmd[@]}" >"$ANVIL_LOG_DIR/anvil.log" 2>&1 &
  echo $!
}

start_anvil() {
  if cast_bounded block-number --rpc-url "$RPC_URL" >/dev/null 2>&1; then
    log_info "Reusing Anvil at $RPC_URL"
    return 0
  fi

  mkdir -p "$ANVIL_LOG_DIR"
  local pid
  local attempt
  local started=0
  if [[ "$FORK_LATEST" -eq 0 && "$FOUNDRY_FORK_RPC_ALIAS" != *alchemy* ]]; then
    retarget_pin_for_public || exit 1
  fi
  if [[ "$FORK_LATEST" -eq 1 ]]; then
    log_info "Starting Anvil chain $ANVIL_CHAIN_ID forking $FOUNDRY_FORK_RPC_ALIAS at remote latest"
  else
    log_info "Starting Anvil chain $ANVIL_CHAIN_ID forking $FOUNDRY_FORK_RPC_ALIAS @ block $ANVIL_FORK_BLOCK_NUMBER"
  fi
  for ((attempt = 1; attempt <= ANVIL_ALCHEMY_START_ATTEMPTS; attempt++)); do
    pid="$(launch_anvil "$ANVIL_FORK_URL")"
    if wait_for_rpc "$pid"; then
      started=1
      break
    fi
    kill_anvil
    if [[ "$FOUNDRY_FORK_RPC_ALIAS" == *alchemy* && "$attempt" -lt "$ANVIL_ALCHEMY_START_ATTEMPTS" ]]; then
      log_info "Alchemy Anvil start failed (attempt $attempt/$ANVIL_ALCHEMY_START_ATTEMPTS); retrying"
      sleep 2
    else
      break
    fi
  done

  if [[ "$started" -eq 0 ]]; then
    if [[ "$FOUNDRY_FORK_RPC_ALIAS" == *alchemy* ]]; then
      FOUNDRY_FORK_RPC_ALIAS="robinhood_testnet"
      ANVIL_FORK_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_FORK_RPC_ALIAS")"
      if [[ "$FORK_LATEST" -eq 0 ]]; then
        retarget_pin_for_public || exit 1
        log_info "Retrying Anvil with $FOUNDRY_FORK_RPC_ALIAS @ block $ANVIL_FORK_BLOCK_NUMBER"
      else
        log_info "Retrying Anvil with $FOUNDRY_FORK_RPC_ALIAS at remote latest"
      fi
      pid="$(launch_anvil "$ANVIL_FORK_URL")"
      if ! wait_for_rpc "$pid"; then
        log_error "Anvil failed to start with $FOUNDRY_FORK_RPC_ALIAS"
        exit 1
      fi
    else
      log_error "Anvil failed to start with $FOUNDRY_FORK_RPC_ALIAS"
      exit 1
    fi
  fi

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
      log_error "Refusing broadcast to non-localhost RPC_URL=$RPC_URL"
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
    cmd+=(--legacy --gas-price "${FORGE_GAS_PRICE:-2000000000}")
    # Pre-sim of CREATE3 / deployVault is silent and looks hung. Broadcast as we go.
    case "$label" in
      Group\ 00|Group\ 09) ;;
      *)
        cmd+=(--skip-simulation)
        log_info "$label broadcasts without pre-sim — txs print as they land"
        ;;
    esac
  fi

  (
    cd "$REPO_ROOT"
    OUT_DIR_OVERRIDE="$OUT_DIR_OVERRIDE" \
      NETWORK_PROFILE="$NETWORK_PROFILE" \
      SENDER="$SENDER" \
      OWNER="$OWNER" \
      UI_WALLET="$UI_WALLET" \
      FORCE="$FORCE" \
      RPC_URL="$RPC_URL" \
      "${cmd[@]}"
  )
}

stage_script() {
  local n="$1"
  case "$n" in
    00) echo "$SCRIPT_DIR/Script_00_Preflight.s.sol" ;;
    01) echo "$SCRIPT_DIR/Script_01_Factories.s.sol" ;;
    02) echo "$SCRIPT_DIR/Script_02_Platform.s.sol" ;;
    03) echo "$SCRIPT_DIR/Script_03_UniV4Packages.s.sol" ;;
    04) echo "$SCRIPT_DIR/Script_04_Tokens.s.sol" ;;
    05) echo "$SCRIPT_DIR/Script_05_LeafPoolsAndSEs.s.sol" ;;
    06) echo "$SCRIPT_DIR/Script_06_LeafDETFs.s.sol" ;;
    06a) echo "$SCRIPT_DIR/Script_06a_NvdaS.s.sol" ;;
    06b) echo "$SCRIPT_DIR/Script_06b_NvdaSmhO.s.sol" ;;
    06c) echo "$SCRIPT_DIR/Script_06c_IdxQ.s.sol" ;;
    06d) echo "$SCRIPT_DIR/Script_06d_M7W.s.sol" ;;
    06e) echo "$SCRIPT_DIR/Script_06e_DolQ.s.sol" ;;
    07) echo "$SCRIPT_DIR/Script_07_NestDETFs.s.sol" ;;
    08) echo "$SCRIPT_DIR/Script_08_FeeSink.s.sol" ;;
    09) echo "$SCRIPT_DIR/Script_09_ExportFrontend.s.sol" ;;
    simulate) echo "$SCRIPT_DIR/Script_SimulateLaunch.s.sol" ;;
    *)
      log_error "Unknown stage $n"
      exit 1
      ;;
  esac
}

run_stages() {
  local stages=("$@")
  for n in "${stages[@]}"; do
    run_stage "Group $n" "$(stage_script "$n")"
  done
}

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    all|foundation|assets|pools|leaves|nests|feesink|export|simulate)
      COMMAND="$1"
      shift
      ;;
    stage[0-9][0-9]|stage[0-9]|stage06[a-e]|stagesimulate)
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
    --fork-alias)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        log_error "--fork-alias requires a foundry.toml [rpc_endpoints] name"
        exit 1
      fi
      CLI_FORK_ALIAS="$2"
      shift 2
      ;;
    --fork-alias=*)
      CLI_FORK_ALIAS="${1#--fork-alias=}"
      if [[ -z "$CLI_FORK_ALIAS" ]]; then
        log_error "--fork-alias requires a foundry.toml [rpc_endpoints] name"
        exit 1
      fi
      shift
      ;;
    --public-rpc)
      CLI_FORK_ALIAS="robinhood_testnet"
      shift
      ;;
    --fork-latest)
      FORK_LATEST=1
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

if [[ "${ANVIL_FORK_BLOCK_NUMBER:-}" == "latest" ]]; then
  FORK_LATEST=1
fi
if [[ -n "$CLI_FORK_ALIAS" ]]; then
  FOUNDRY_FORK_RPC_ALIAS="$CLI_FORK_ALIAS"
  ANVIL_FORK_URL=""
fi
if [[ -z "$ANVIL_FORK_URL" ]]; then
  if ! ANVIL_FORK_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_FORK_RPC_ALIAS" 2>/dev/null)"; then
    if [[ -n "$CLI_FORK_ALIAS" ]]; then
      log_error "Could not resolve Foundry RPC alias: $FOUNDRY_FORK_RPC_ALIAS"
      exit 1
    fi
    FOUNDRY_FORK_RPC_ALIAS="robinhood_testnet"
    ANVIL_FORK_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_FORK_RPC_ALIAS")"
  fi
fi
_fork_host="${ANVIL_FORK_URL#*://}"
_fork_host="${_fork_host%%/*}"
log_info "Fork alias $FOUNDRY_FORK_RPC_ALIAS ($_fork_host)"
unset _fork_host

require_dev_address
require_localhost_broadcast

if [[ "$RESTART_ANVIL" -eq 1 ]]; then
  kill_anvil
  purge_stage_artifacts
fi

start_anvil

CID="$(perl -e 'alarm shift; exec @ARGV' 10 cast chain-id --rpc-url "$RPC_URL")"
if [[ "$CID" != "46630" ]]; then
  log_error "Expected chain id 46630, got $CID — start Anvil with --chain-id 46630"
  exit 1
fi
log_success "Anvil chain id $CID"

log_header "Anvil Robinhood Testnet deploy: $COMMAND"
log_info "SENDER=$SENDER OUT_DIR=$OUT_DIR_OVERRIDE"

case "$COMMAND" in
  all)
    run_stages 00 01 02 03 04 05 06a 06b 06c 06e 06 07 08 simulate 09
    ;;
  foundation)
    run_stages 00 01 02 03
    ;;
  assets)
    run_stages 04
    ;;
  pools)
    run_stages 05
    ;;
  leaves)
    run_stages 06a 06b 06c 06e 06
    ;;
  nests)
    run_stages 07
    ;;
  feesink)
    run_stages 08
    ;;
  simulate|stagesimulate)
    run_stages simulate
    ;;
  export)
    run_stages 09
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
exit 0
