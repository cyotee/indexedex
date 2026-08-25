#!/usr/bin/env bash
# =============================================================================
# Anvil Robinhood mainnet fork — IndexedEx architecture (chain 4663)
# Phase/Stage catalog: Crane factories, IndexedEx manager, TWAP, Uni V4 SE pkg,
# Morpho Blue SE pkg, CP/Weighted/Curve Quad hook + DETF pkgs.
# No test tokens. No SE vault instances. No DETF instances.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RH_FOUNDRY_DIR="$SCRIPT_DIR"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/shell/lib/rh_4663_stages.sh"

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
FOUNDRY_FORK_RPC_ALIAS="${FOUNDRY_FORK_RPC_ALIAS:-robinhood_mainnet}"
ANVIL_FORK_URL="${ANVIL_FORK_URL:-}"
CLI_FORK_ALIAS=""
# Public RH RPC has no archive. Default is remote tip (same as a live 4663 deploy).
# Set ANVIL_FORK_BLOCK_NUMBER to pin; "latest" or --fork-latest omit the pin.
FORK_LATEST=1
if [[ -n "${ANVIL_FORK_BLOCK_NUMBER:-}" && "${ANVIL_FORK_BLOCK_NUMBER}" != "latest" ]]; then
  FORK_LATEST=0
fi
ANVIL_COMPUTE_UNITS_PER_SECOND="${ANVIL_COMPUTE_UNITS_PER_SECOND:-330}"
ANVIL_FORK_RETRY_BACKOFF="${ANVIL_FORK_RETRY_BACKOFF:-1000}"
ANVIL_LOG_DIR="${ANVIL_LOG_DIR:-$REPO_ROOT/deployments/anvil_robinhood_main/runtime}"
# Extra headroom on the upstream EIP-1559 funding quote (basis points). 2500 = 25%.
FUND_ETH_BUFFER_BPS="${FUND_ETH_BUFFER_BPS:-2500}"
FEE_RPC=""
FEE_BASE_WEI=""
FEE_PRIORITY_WEI=""
FEE_GAS_PRICE_WEI=""

DEPLOYMENTS_DIR="${DEPLOYMENTS_DIR:-deployments/anvil_robinhood_main}"
export OUT_DIR_OVERRIDE="${OUT_DIR_OVERRIDE:-$DEPLOYMENTS_DIR}"
export NETWORK_PROFILE="${NETWORK_PROFILE:-anvil_robinhood_main}"
export CHAIN_ID="${CHAIN_ID:-4663}"
export RPC_URL

DEV_ADDRESS="${DEV_ADDRESS:-}"
DEPLOYER_ADDRESS="${DEPLOYER_ADDRESS:-}"
SENDER="${SENDER:-}"
export OWNER="${OWNER:-}"
export UI_WALLET="${UI_WALLET:-0x70997970C51812dc3A010C7d01b50e0d17dc79C8}"

BROADCAST_FLAG="--broadcast"
RESTART_ANVIL=0
KILL_ANVIL=0
FORCE=0
RPC_URL_EXPLICIT=0
FORGE_VERBOSITY=""
COMMAND="all"
FROM_PHASE=""
FROM_STAGE=""

usage() {
  cat <<EOF
Usage:
  scripts/shell/anvil_robinhood_main.sh [command] [options]
  scripts/foundry/anvil_robinhood_main/deploy_all.sh [command] [options]

Deploys Crane factories + IndexedEx architecture (FeeCollector, Manager,
TWAP oracle) + Uni V4 SE package + Morpho Blue SE package + CP / Weighted /
Curve Quad hook and DETF packages.
No tokens. No SE vaults. No Protocol DETF instances.

Commands:
  all           Phase 00 then catalog Phases 01–06 (architecture packages)
  foundation    Same as all
  simulate      Script_SimulateArchitecture (library execute 02–06 in one
                Foundry script). Default is no broadcast. EIP-1559 from the
                fork source (no --legacy / --gas-price). Prints a deployer
                funding quote. Do not run after a completed staged \`all\`.

Public 4663 (no Phase 00): scripts/shell/robinhood_main.sh

Options:
  --dry-run         Simulate without broadcasting (default for simulate)
  --broadcast       Force broadcast (overrides simulate's dry-run default)
  --rpc-url URL     RPC (default http://127.0.0.1:8545)
  --restart-anvil   Kill port + start a RH mainnet fork at chain id 4663
                    (EIP-170 stays on; public RPC at remote tip)
  --kill-anvil      Kill Anvil and exit
  --force           Re-run Stages (purge stage JSON first when restarting)
  --from-phase PP   Resume catalog at Phase PP (with --from-stage, default 01)
  --from-stage SS   Resume catalog at Stage SS of --from-phase
  --fork-alias NAME Foundry [rpc_endpoints] alias (default robinhood_mainnet)
  --public-rpc      Same as --fork-alias robinhood_mainnet
  --fork-latest     Fork remote tip (default). Omit --fork-block-number.
  -v…-vvvvv         Forge verbosity
  --help, -h

Signer:
  SENDER / DEV_ADDRESS / DEPLOYER_ADDRESS
                    Passed as forge --sender. Defaults to Anvil account(0).
  OWNER             Defaults to the deployer

Optional:
  ANVIL_FORK_URL / FOUNDRY_FORK_RPC_ALIAS (default robinhood_mainnet)
  ANVIL_FORK_BLOCK_NUMBER (omit for remote tip; public RPC is not archive)
  RPC_URL (default http://127.0.0.1:8545)
  PRIVATE_KEY       Only when key-backed broadcast is required
  FUND_ETH_BUFFER_BPS  Headroom on the simulate funding quote (default 2500 = 25%)

Gas estimate (EIP-1559, no forced gas price, no broadcast):

  bash scripts/shell/anvil_robinhood_main.sh simulate --restart-anvil
  # or:
  forge script scripts/foundry/anvil_robinhood_main/Script_SimulateArchitecture.s.sol \\
    --rpc-url http://127.0.0.1:8545 --sender \$SENDER --unlocked
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

is_simulate_command() {
  [[ "${COMMAND:-}" == "simulate" || "${COMMAND:-}" == "stagesimulate" ]]
}

# Bound `cast` so a dead RPC cannot hang the caller (macOS has no GNU timeout).
cast_bounded_n() {
  local seconds="$1"
  shift
  perl -e 'alarm shift; exec @ARGV' "$seconds" cast "$@"
}

cast_bounded() {
  cast_bounded_n 5 "$@"
}

strip_json_scalar() {
  local x="${1:-}"
  x="${x//\"/}"
  x="${x//[[:space:]]/}"
  printf '%s' "$x"
}

wei_to_gwei() {
  python3 -c "print('{:.6f}'.format(int('${1:-0}') / 1e9))" 2>/dev/null || echo "?"
}

wei_to_eth() {
  python3 -c "print('{:.8f}'.format(int('${1:-0}') / 1e18))" 2>/dev/null || echo "?"
}

fetch_eip1559_fees() {
  local rpc="$1"
  local timeout_s="${2:-20}"
  local base gas_price prio_raw prio
  FEE_RPC="$rpc"
  FEE_BASE_WEI=""
  FEE_PRIORITY_WEI=""
  FEE_GAS_PRICE_WEI=""
  base="$(cast_bounded_n "$timeout_s" base-fee --rpc-url "$rpc" 2>/dev/null || true)"
  gas_price="$(cast_bounded_n "$timeout_s" gas-price --rpc-url "$rpc" 2>/dev/null || true)"
  prio_raw="$(cast_bounded_n "$timeout_s" rpc eth_maxPriorityFeePerGas --rpc-url "$rpc" 2>/dev/null || true)"
  base="$(strip_json_scalar "$base")"
  gas_price="$(strip_json_scalar "$gas_price")"
  prio_raw="$(strip_json_scalar "$prio_raw")"
  if [[ -z "$base" || ! "$base" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  if [[ -z "$gas_price" || ! "$gas_price" =~ ^[0-9]+$ ]]; then
    gas_price="$base"
  fi
  if [[ -n "$prio_raw" ]]; then
    prio="$(cast --to-dec "$prio_raw" 2>/dev/null || true)"
  fi
  prio="$(strip_json_scalar "${prio:-0}")"
  if [[ -z "$prio" || ! "$prio" =~ ^[0-9]+$ ]]; then
    prio=0
  fi
  FEE_BASE_WEI="$base"
  FEE_GAS_PRICE_WEI="$gas_price"
  FEE_PRIORITY_WEI="$prio"
}

log_eip1559_fees() {
  local label="$1"
  log_info "$label EIP-1559 baseFee=${FEE_BASE_WEI} wei ($(wei_to_gwei "$FEE_BASE_WEI") gwei) priority=${FEE_PRIORITY_WEI} wei ($(wei_to_gwei "$FEE_PRIORITY_WEI") gwei) eth_gasPrice=${FEE_GAS_PRICE_WEI} wei ($(wei_to_gwei "$FEE_GAS_PRICE_WEI") gwei)"
}

sync_anvil_base_fee() {
  local hex
  if [[ -z "${FEE_BASE_WEI:-}" ]]; then
    return 0
  fi
  hex="$(cast --to-hex "$FEE_BASE_WEI" 2>/dev/null || true)"
  if [[ -z "$hex" ]]; then
    return 1
  fi
  if ! cast_bounded rpc anvil_setNextBlockBaseFeePerGas "$hex" --rpc-url "$RPC_URL" >/dev/null 2>&1; then
    return 1
  fi
  # Make `latest.baseFeePerGas` match the next-block value Foundry reads.
  cast_bounded rpc evm_mine --rpc-url "$RPC_URL" >/dev/null 2>&1 || true
}

prepare_simulate_fees() {
  local src="${ANVIL_FORK_URL:-$RPC_URL}"
  if ! fetch_eip1559_fees "$src"; then
    log_error "simulate needs EIP-1559 fees from the fork source (no baseFee from $FOUNDRY_FORK_RPC_ALIAS)"
    exit 1
  fi
  log_eip1559_fees "Fork source"
  if is_localhost_rpc; then
    if sync_anvil_base_fee; then
      log_info "Pinned Anvil next baseFee to fork source (EIP-1559, no forced gas price)"
    else
      log_info "Could not pin Anvil baseFee; funding quote still uses fork-source fees"
    fi
  fi
}

sum_dry_run_gas_limits() {
  local json_path="$1"
  python3 - "$json_path" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
total = 0
n = 0
for tx in data.get("transactions") or []:
    inner = tx.get("transaction") or {}
    gas = inner.get("gas")
    if gas is None:
        continue
    if isinstance(gas, str):
        gas_i = int(gas, 16) if gas.startswith("0x") else int(gas)
    else:
        gas_i = int(gas)
    total += gas_i
    n += 1
print(f"{n} {total}")
PY
}

quote_simulate_funding() {
  local json_path="$REPO_ROOT/broadcast/Script_SimulateArchitecture.s.sol/${CHAIN_ID}/dry-run/run-latest.json"
  local src="${ANVIL_FORK_URL:-$RPC_URL}"
  local counts n_tx gas_sum pay_per_gas cost_wei buffer_bps fund_wei
  buffer_bps="${FUND_ETH_BUFFER_BPS:-2500}"
  if [[ ! "$buffer_bps" =~ ^[0-9]+$ ]]; then
    buffer_bps=2500
  fi

  log_header "Deployer funding estimate (upstream EIP-1559)"

  if [[ ! -f "$json_path" ]]; then
    log_error "No dry-run artifact at $json_path; cannot quote funding"
    return 1
  fi
  if ! fetch_eip1559_fees "$src"; then
    log_error "Could not refresh fork-source EIP-1559 fees for the funding quote"
    return 1
  fi
  log_eip1559_fees "Quote"
  counts="$(sum_dry_run_gas_limits "$json_path" | tr -d '\r')"
  n_tx="$(strip_json_scalar "${counts%% *}")"
  gas_sum="$(strip_json_scalar "${counts#* }")"
  if [[ -z "$n_tx" || -z "$gas_sum" || ! "$n_tx" =~ ^[0-9]+$ || ! "$gas_sum" =~ ^[0-9]+$ ]]; then
    log_error "Could not sum gas limits from $json_path"
    return 1
  fi
  pay_per_gas="$FEE_GAS_PRICE_WEI"
  if [[ -z "$pay_per_gas" || "$pay_per_gas" == "0" ]]; then
    pay_per_gas=$((FEE_BASE_WEI + FEE_PRIORITY_WEI))
  fi
  cost_wei="$(python3 -c "print(int('${gas_sum}') * int('${pay_per_gas}'))")"
  fund_wei="$(python3 -c "print(int('${cost_wei}') * (10000 + int('${buffer_bps}')) // 10000)")"

  log_info "Fee source alias=${FOUNDRY_FORK_RPC_ALIAS} (Anvil local fees are not used for this quote)"
  log_info "Simulated txs=${n_tx} gas_limit_sum=${gas_sum} (Foundry dry-run limits; used gas will be lower)"
  log_info "Expected spend at current eth_gasPrice: $(wei_to_eth "$cost_wei") ETH (${cost_wei} wei)"
  log_info "Recommended fund amount (+$((buffer_bps / 100))% buffer): $(wei_to_eth "$fund_wei") ETH (${fund_wei} wei)"
  log_info "Forge's on-screen ETH total may differ; fund from this quote."
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

# stdout is the child pid only — do not log here (callers capture stdout).
launch_anvil() {
  local fork_url="$1"
  local anvil_cmd=(
    anvil
    --host "$ANVIL_HOST"
    --port "$ANVIL_PORT"
    --chain-id "$ANVIL_CHAIN_ID"
    --fork-url "$fork_url"
    --compute-units-per-second "$ANVIL_COMPUTE_UNITS_PER_SECOND"
    --fork-retry-backoff "$ANVIL_FORK_RETRY_BACKOFF"
    --disable-min-priority-fee
  )
  if [[ "$FORK_LATEST" -eq 0 && -n "${ANVIL_FORK_BLOCK_NUMBER:-}" && "$ANVIL_FORK_BLOCK_NUMBER" != "latest" ]]; then
    anvil_cmd+=(--fork-block-number "$ANVIL_FORK_BLOCK_NUMBER")
  fi
  if [[ -n "${ANVIL_BLOCK_BASE_FEE:-}" ]]; then
    anvil_cmd+=(--block-base-fee-per-gas "$ANVIL_BLOCK_BASE_FEE")
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
  ANVIL_BLOCK_BASE_FEE=""
  if fetch_eip1559_fees "$ANVIL_FORK_URL"; then
    ANVIL_BLOCK_BASE_FEE="$FEE_BASE_WEI"
    log_eip1559_fees "Anvil start"
  else
    log_info "Starting Anvil without a pinned baseFee (fork source fee fetch failed)"
  fi
  if [[ "$FORK_LATEST" -eq 1 ]]; then
    log_info "Starting Anvil chain $ANVIL_CHAIN_ID forking $FOUNDRY_FORK_RPC_ALIAS at remote latest"
  else
    log_info "Starting Anvil chain $ANVIL_CHAIN_ID forking $FOUNDRY_FORK_RPC_ALIAS @ block $ANVIL_FORK_BLOCK_NUMBER"
  fi
  local pid
  pid="$(launch_anvil "$ANVIL_FORK_URL")"
  if ! wait_for_rpc "$pid"; then
    log_error "Anvil failed to start with $FOUNDRY_FORK_RPC_ALIAS"
    exit 1
  fi

  if declare -F sanitize_dev_accounts >/dev/null 2>&1; then
    sanitize_dev_accounts "$RPC_URL" || true
  fi
}

is_localhost_rpc() {
  case "$RPC_URL" in
    http://127.0.0.1:*|http://localhost:*|https://127.0.0.1:*|https://localhost:*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

require_localhost_broadcast() {
  if [[ -z "$BROADCAST_FLAG" ]]; then
    return 0
  fi
  if is_localhost_rpc; then
    return 0
  fi
  log_error "Refusing broadcast to non-localhost RPC_URL=$RPC_URL"
  exit 1
}

require_deployer() {
  if [[ -z "$SENDER" ]]; then
    SENDER="${DEPLOYER_ADDRESS:-${DEV_ADDRESS:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}}"
  fi
  DEV_ADDRESS="${DEV_ADDRESS:-$SENDER}"
  DEPLOYER_ADDRESS="${DEPLOYER_ADDRESS:-$SENDER}"
  export SENDER DEV_ADDRESS DEPLOYER_ADDRESS
  export OWNER="${OWNER:-$SENDER}"
}

run_forge_cmd() {
  (
    cd "$REPO_ROOT"
    if is_simulate_command; then
      # Do not inherit a pinned max-fee; simulate must use RPC EIP-1559.
      unset ETH_GAS_PRICE ETH_PRIORITY_GAS_PRICE
    fi
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

forge_script_base() {
  local script_path="$1"
  local cmd=(forge script "$script_path" --rpc-url "$RPC_URL")
  if [[ -n "$FORGE_VERBOSITY" ]]; then
    cmd+=("$FORGE_VERBOSITY")
  fi
  cmd+=(--sender "$SENDER")
  if is_localhost_rpc; then
    cmd+=(--unlocked)
  fi
  # Simulate: EIP-1559 with the fork source tip. Never --legacy / --gas-price.
  if is_simulate_command && [[ -n "${FEE_PRIORITY_WEI:-}" && "$FEE_PRIORITY_WEI" =~ ^[0-9]+$ ]]; then
    cmd+=(--priority-gas-price "$FEE_PRIORITY_WEI")
  fi
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
  if ! run_forge_cmd "${sim_cmd[@]}"; then
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
  # `simulate` is the funding-quote path: EIP-1559, never a forced gas price.
  # Staged `all` still uses legacy 2 gwei on Anvil (feeHistory work-around).
  if ! is_simulate_command; then
    if is_localhost_rpc || [[ "${FORGE_LEGACY:-0}" == "1" ]]; then
      bcast_cmd+=(--legacy --gas-price "${FORGE_GAS_PRICE:-2000000000}")
    fi
  fi

  log_info "Broadcasting $label"
  run_forge_cmd "${bcast_cmd[@]}"
}

stage_script() {
  local n="$1"
  case "$n" in
    simulate) echo "$SCRIPT_DIR/Script_SimulateArchitecture.s.sol" ;;
    *)
      log_error "Unknown simulate target $n"
      exit 1
      ;;
  esac
}

ARGS=()
SIMULATE_BROADCAST_OVERRIDE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    all|foundation|simulate|stagesimulate)
      COMMAND="$1"
      shift
      ;;
    --from-phase)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        log_error "--from-phase requires PP"
        exit 1
      fi
      FROM_PHASE="$2"
      shift 2
      ;;
    --from-phase=*)
      FROM_PHASE="${1#--from-phase=}"
      shift
      ;;
    --from-stage)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        log_error "--from-stage requires SS"
        exit 1
      fi
      FROM_STAGE="$2"
      shift 2
      ;;
    --from-stage=*)
      FROM_STAGE="${1#--from-stage=}"
      shift
      ;;
    --dry-run)
      BROADCAST_FLAG=""
      shift
      ;;
    --broadcast)
      BROADCAST_FLAG="--broadcast"
      SIMULATE_BROADCAST_OVERRIDE=1
      shift
      ;;
    --rpc-url)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        log_error "--rpc-url requires a URL"
        exit 1
      fi
      RPC_URL="$2"
      RPC_URL_EXPLICIT=1
      export RPC_URL
      shift 2
      ;;
    --rpc-url=*)
      RPC_URL="${1#--rpc-url=}"
      if [[ -z "$RPC_URL" ]]; then
        log_error "--rpc-url requires a URL"
        exit 1
      fi
      RPC_URL_EXPLICIT=1
      export RPC_URL
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
      CLI_FORK_ALIAS="robinhood_mainnet"
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

# simulate is the gas-estimate path: no broadcast unless --broadcast is explicit.
if [[ "$COMMAND" == "simulate" || "$COMMAND" == "stagesimulate" ]] && [[ "$SIMULATE_BROADCAST_OVERRIDE" -eq 0 ]]; then
  BROADCAST_FLAG=""
fi

require_deployer
require_localhost_broadcast

if [[ "$RESTART_ANVIL" -eq 1 ]] && ! is_localhost_rpc; then
  log_error "--restart-anvil requires a localhost RPC_URL (got $RPC_URL)"
  exit 1
fi

if [[ "${ANVIL_FORK_BLOCK_NUMBER:-}" == "latest" ]]; then
  FORK_LATEST=1
fi

if is_localhost_rpc; then
  if [[ "$RESTART_ANVIL" -eq 1 ]]; then
    kill_anvil
    purge_stage_artifacts
  fi
  if [[ -n "$CLI_FORK_ALIAS" ]]; then
    FOUNDRY_FORK_RPC_ALIAS="$CLI_FORK_ALIAS"
    ANVIL_FORK_URL=""
  fi
  if [[ -z "$ANVIL_FORK_URL" ]]; then
    if ! ANVIL_FORK_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_FORK_RPC_ALIAS")"; then
      log_error "Could not resolve Foundry RPC alias: $FOUNDRY_FORK_RPC_ALIAS"
      exit 1
    fi
  fi
  _fork_host="${ANVIL_FORK_URL#*://}"
  _fork_host="${_fork_host%%/*}"
  log_info "Anvil fork alias $FOUNDRY_FORK_RPC_ALIAS ($_fork_host)"
  unset _fork_host
  start_anvil
else
  log_info "Skipping Anvil start (RPC is not localhost)"
fi

log_info "Checking chain id at $RPC_URL"
CID="$(cast chain-id --rpc-url "$RPC_URL" | tr -d '[:space:]')"
if [[ "$CID" != "4663" ]]; then
  log_error "Expected chain id 4663, got ${CID:-<empty>}"
  if is_localhost_rpc; then
    log_error "Start Anvil with --chain-id 4663 forking Robinhood mainnet"
  fi
  exit 1
fi
log_success "Chain id $CID RPC=$RPC_URL"

log_header "Anvil Robinhood architecture: $COMMAND"
log_info "SENDER=$SENDER OUT_DIR=$OUT_DIR_OVERRIDE"

if is_simulate_command; then
  prepare_simulate_fees
fi

case "$COMMAND" in
  all|foundation)
    rh_run_catalog 1 "$FROM_PHASE" "${FROM_STAGE:-00}"
    ;;
  simulate|stagesimulate)
    run_stage "Simulate architecture" "$(stage_script simulate)"
    if [[ -z "$BROADCAST_FLAG" ]]; then
      quote_simulate_funding
    fi
    ;;
  *)
    log_error "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac

log_success "Command '$COMMAND' completed"
exit 0
