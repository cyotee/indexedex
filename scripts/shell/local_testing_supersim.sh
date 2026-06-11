#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=lib/sanitize_dev_accounts.sh
source "$SCRIPT_DIR/lib/sanitize_dev_accounts.sh"

ETHEREUM_SEPOLIA_CONSTANTS_FILE="$REPO_ROOT/lib/daosys/lib/crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol"
BASE_SEPOLIA_CONSTANTS_FILE="$REPO_ROOT/lib/daosys/lib/crane/contracts/constants/networks/BASE_SEPOLIA.sol"

extract_default_fork_block() {
  local constants_file="$1"
  local value

  value="$(sed -n 's/.*DEFAULT_FORK_BLOCK = \([0-9_][0-9_]*\);/\1/p' "$constants_file" | head -n 1 | tr -d '_')"
  if [[ -z "$value" ]]; then
    echo "Could not read DEFAULT_FORK_BLOCK from $constants_file" >&2
    exit 1
  fi

  echo "$value"
}

resolve_foundry_rpc_alias() {
  local alias_name="$1"
  local template
  local resolved

  template="$(forge config --json | jq -r --arg alias_name "$alias_name" '.rpc_endpoints[$alias_name] // empty')"
  if [[ -z "$template" || "$template" == "null" ]]; then
    echo "Foundry RPC alias not found: $alias_name" >&2
    exit 1
  fi

  resolved="$(eval "printf '%s' \"$template\"")"
  if [[ "$resolved" == *'${'* ]]; then
    echo "Foundry RPC alias could not be fully resolved: $alias_name" >&2
    exit 1
  fi

  echo "$resolved"
}

ETHEREUM_SEPOLIA_DEFAULT_FORK_BLOCK="$(extract_default_fork_block "$ETHEREUM_SEPOLIA_CONSTANTS_FILE")"
BASE_SEPOLIA_DEFAULT_FORK_BLOCK="$(extract_default_fork_block "$BASE_SEPOLIA_CONSTANTS_FILE")"

if [[ "$ETHEREUM_SEPOLIA_DEFAULT_FORK_BLOCK" != "$BASE_SEPOLIA_DEFAULT_FORK_BLOCK" ]]; then
  echo "Ethereum Sepolia and Base Sepolia DEFAULT_FORK_BLOCK values diverged." >&2
  exit 1
fi

SUPERSIM_HOST="${SUPERSIM_HOST:-127.0.0.1}"
SUPERSIM_L1_PORT="${SUPERSIM_L1_PORT:-8545}"
SUPERSIM_BASE_PORT="${SUPERSIM_BASE_PORT:-9545}"
SUPERSIM_ADMIN_PORT="${SUPERSIM_ADMIN_PORT:-8420}"
SUPERSIM_NETWORK="${SUPERSIM_NETWORK:-sepolia}"
SUPERSIM_BASE_CHAIN="${SUPERSIM_BASE_CHAIN:-base}"
SUPERSIM_AUTORELAY="${SUPERSIM_AUTORELAY:-1}"
SUPERSIM_GAS_ESTIMATE_MULTIPLIER="${SUPERSIM_GAS_ESTIMATE_MULTIPLIER:-110}"
SUPERSIM_ETHEREUM_GAS_ESTIMATE_MULTIPLIER="${SUPERSIM_ETHEREUM_GAS_ESTIMATE_MULTIPLIER:-$SUPERSIM_GAS_ESTIMATE_MULTIPLIER}"
SUPERSIM_BASE_GAS_ESTIMATE_MULTIPLIER="${SUPERSIM_BASE_GAS_ESTIMATE_MULTIPLIER:-150}"
SUPERSIM_L1_FORK_HEIGHT="${SUPERSIM_L1_FORK_HEIGHT:-$ETHEREUM_SEPOLIA_DEFAULT_FORK_BLOCK}"
FOUNDRY_ETHEREUM_SEPOLIA_RPC_ALIAS="${FOUNDRY_ETHEREUM_SEPOLIA_RPC_ALIAS:-ethereum_sepolia_alchemy}"
FOUNDRY_BASE_SEPOLIA_RPC_ALIAS="${FOUNDRY_BASE_SEPOLIA_RPC_ALIAS:-base_sepolia_alchemy}"
SUPERSIM_LOGS_DIR="${SUPERSIM_LOGS_DIR:-$REPO_ROOT/deployments/local_testing/runtime/supersim}"

SUPERSIM_ETHEREUM_OUT_DIR="${SUPERSIM_ETHEREUM_OUT_DIR:-deployments/local_testing/supersim/ethereum}"
SUPERSIM_BASE_OUT_DIR="${SUPERSIM_BASE_OUT_DIR:-deployments/local_testing/supersim/base}"
SUPERSIM_SHARED_OUT_DIR="${SUPERSIM_SHARED_OUT_DIR:-deployments/local_testing/supersim/shared}"
SUPERSIM_FRONTEND_ARTIFACTS_DIR="${SUPERSIM_FRONTEND_ARTIFACTS_DIR:-frontend/app/addresses/local_testing_supersim}"

SUPERSIM_ETHEREUM_RPC_URL="${SUPERSIM_ETHEREUM_RPC_URL:-http://${SUPERSIM_HOST}:${SUPERSIM_L1_PORT}}"
SUPERSIM_BASE_RPC_URL="${SUPERSIM_BASE_RPC_URL:-http://${SUPERSIM_HOST}:${SUPERSIM_BASE_PORT}}"
SUPERSIM_ETHEREUM_CHAIN_ID="${SUPERSIM_ETHEREUM_CHAIN_ID:-11155111}"
SUPERSIM_BASE_CHAIN_ID="${SUPERSIM_BASE_CHAIN_ID:-84532}"
SUPERSIM_DEFAULT_PRIVATE_KEY_0="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
DEFAULT_ETHEREUM_SEPOLIA_RPC_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_ETHEREUM_SEPOLIA_RPC_ALIAS")"
DEFAULT_BASE_SEPOLIA_RPC_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_BASE_SEPOLIA_RPC_ALIAS")"
SUPERSIM_SOURCE_SEPOLIA_RPC_URL="${SUPERSIM_RPC_URL_SEPOLIA:-${ETHEREUM_SEPOLIA_RPC_URL:-$DEFAULT_ETHEREUM_SEPOLIA_RPC_URL}}"
SUPERSIM_SOURCE_BASE_RPC_URL="${SUPERSIM_RPC_URL_BASE:-${BASE_SEPOLIA_RPC_URL:-$DEFAULT_BASE_SEPOLIA_RPC_URL}}"

DEV_ADDRESS="${DEV_ADDRESS:-}"
SENDER="${SENDER:-$DEV_ADDRESS}"
DEPLOYER_ADDRESS="${DEPLOYER_ADDRESS:-$SENDER}"
OWNER="${OWNER:-$DEPLOYER_ADDRESS}"

RESTART_SUPERSIM=0
KILL_SUPERSIM=0
FORGE_VERBOSITY=""
BROADCAST_FLAG="--broadcast"
FORGE_RESUME=0
FORCE_RERUN=0
COMMAND="scenario4"

usage() {
  cat <<EOF
Usage:
  scripts/shell/local_testing_supersim.sh [command] [options]

Commands:
  scenario4      Run the full dual-chain local-testing flow (stages 20-23)
  foundation     Run Stage 20 on both Ethereum and Base local SuperSim forks
  bridge         Run Stage 21 bridge infra on both forks
  configure      Run Stage 22 bridge config on both forks
  validate       Run Stage 23 bridge validation on both forks
  stage20        Same as foundation
  stage21        Same as bridge
  stage22        Same as configure
  stage23        Same as validate

Options:
  --dry-run           Simulate without broadcasting
  --resume            Pass --resume through to forge script
  --force             Remove stage output manifests before rerunning the selected stage(s)
  --restart-supersim  Restart the local SuperSim process before running stages
  --kill-supersim     Kill the local SuperSim process and exit
  -v|-vv|-vvv|-vvvv|-vvvvv
                      Pass Foundry verbosity through to forge script
  --help, -h          Show this help

Environment:
  DEV_ADDRESS or SENDER or DEPLOYER_ADDRESS
                      Broadcast sender used by the SuperSim scripts
  OWNER               Optional owner override; defaults to DEPLOYER_ADDRESS
  SUPERSIM_ETHEREUM_OUT_DIR
                      Defaults to deployments/local_testing/supersim/ethereum
  SUPERSIM_BASE_OUT_DIR
                      Defaults to deployments/local_testing/supersim/base
  SUPERSIM_SHARED_OUT_DIR
                      Defaults to deployments/local_testing/supersim/shared
EOF
}

log_info() {
  printf '[INFO] %s\n' "$1"
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Expected file not found: $path" >&2
    exit 1
  fi
}

require_env() {
  local key="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "Missing required env: $key" >&2
    exit 1
  fi
}

require_supersim_fork_sources() {
  require_env SUPERSIM_RPC_URL_SEPOLIA/ETHEREUM_SEPOLIA_RPC_URL/FOUNDRY_ETHEREUM_SEPOLIA_RPC_ALIAS "$SUPERSIM_SOURCE_SEPOLIA_RPC_URL"
  require_env SUPERSIM_RPC_URL_BASE/BASE_SEPOLIA_RPC_URL/FOUNDRY_BASE_SEPOLIA_RPC_ALIAS "$SUPERSIM_SOURCE_BASE_RPC_URL"
}

supersim_pid_file() {
  echo "$SUPERSIM_LOGS_DIR/supersim.pid"
}

stop_supersim_if_running() {
  local pid_file
  pid_file="$(supersim_pid_file)"

  if [[ ! -f "$pid_file" ]]; then
    return 0
  fi

  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ -z "$pid" ]]; then
    return 0
  fi

  if kill -0 "$pid" >/dev/null 2>&1; then
    log_info "Stopping existing SuperSim process: $pid"
    kill "$pid"
    for _ in $(seq 1 30); do
      if ! kill -0 "$pid" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    if kill -0 "$pid" >/dev/null 2>&1; then
      echo "SuperSim process did not exit after restart request: $pid" >&2
      exit 1
    fi
  fi

  printf '' > "$pid_file"
}

wait_for_rpc() {
  local rpc_url="$1"
  local label="$2"
  for _ in $(seq 1 60); do
    if curl -s -X POST -H "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
      "$rpc_url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "Timed out waiting for ${label} RPC at ${rpc_url}" >&2
  exit 1
}

rpc_available() {
  local rpc_url="$1"

  curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    "$rpc_url" >/dev/null 2>&1
}

rpc_call() {
  local rpc_url="$1"
  local method="$2"
  local params_json="$3"

  curl -s -X POST \
    -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params_json},\"id\":1}" \
    "$rpc_url"
}

rpc_chain_id() {
  local rpc_url="$1"
  local response

  response="$(rpc_call "$rpc_url" "eth_chainId" "[]")"
  printf '%s' "$response" | jq -r '.result // empty'
}

rpc_matches_chain_id() {
  local rpc_url="$1"
  local expected_decimal_chain_id="$2"
  local actual_chain_id
  local expected_hex

  actual_chain_id="$(rpc_chain_id "$rpc_url")"
  expected_hex="$(printf '0x%x' "$expected_decimal_chain_id")"

  [[ -n "$actual_chain_id" && "$actual_chain_id" == "$expected_hex" ]]
}

is_default_supersim_sender() {
  local candidate="$1"
  local normalized="$(echo "$candidate" | tr '[:upper:]' '[:lower:]')"
  local known_senders=(
    "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
    "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
    "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc"
    "0x90f79bf6eb2c4f870365e785982e1f101e93b906"
    "0x15d34aaf54267db7d7c367839aaf71a00a2c6a65"
    "0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc"
    "0x976ea74026e726554db657fa54763abdc3a0aa9"
    "0x14dc79964da2c08b23698b3d3cc7ca32193d9955"
    "0x23618e81e3f5cdf7f54c3d65f7fbc0abf5b21e8f"
    "0xa0ee7a142d267c1f36714e4a8f75612f20a79720"
  )
  local sender

  for sender in "${known_senders[@]}"; do
    if [[ "$normalized" == "$sender" ]]; then
      return 0
    fi
  done

  return 1
}

impersonate_account_if_needed() {
  local rpc_url="$1"

  if [[ -n "${PRIVATE_KEY:-}" ]]; then
    return 0
  fi

  if is_default_supersim_sender "$DEPLOYER_ADDRESS"; then
    return 0
  fi

  local response
  response="$(rpc_call "$rpc_url" "anvil_impersonateAccount" "[\"$DEPLOYER_ADDRESS\"]")"
  if [[ "$response" == *'"error"'* ]]; then
    echo "Failed to impersonate DEPLOYER_ADDRESS on $rpc_url" >&2
    echo "$response" >&2
    exit 1
  fi
}

prepare_broadcast_identity() {
  impersonate_account_if_needed "$SUPERSIM_ETHEREUM_RPC_URL"
  impersonate_account_if_needed "$SUPERSIM_BASE_RPC_URL"
}

sweep_eth_to_deployer_address() {
  local rpc_url="$1"
  local script_path="$2"
  local forge_args=(forge script "$script_path")
  local senders=(
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
    "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
    "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
    "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
    "0x976EA74026E726554dB657fA54763abd0C3a0aa9"
    "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955"
    "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f"
    "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720"
  )
  local sender

  if is_default_supersim_sender "$DEPLOYER_ADDRESS"; then
    log_info "Skipping ETH sweep for pre-funded SuperSim account $DEPLOYER_ADDRESS"
    return 0
  fi

  if [[ -n "$FORGE_VERBOSITY" ]]; then
    forge_args+=("$FORGE_VERBOSITY")
  fi

  for sender in "${senders[@]}"; do
    DEV0_ADDRESS="$DEPLOYER_ADDRESS" "${forge_args[@]}" --rpc-url "$rpc_url" --broadcast --unlocked --sender "$sender"
  done
}

run_forge_script() {
  local script_target="$1"
  local rpc_url="$2"
  shift 2

  local forge_args=(forge script "$script_target")
  local gas_estimate_multiplier="$SUPERSIM_ETHEREUM_GAS_ESTIMATE_MULTIPLIER"

  if [[ "$rpc_url" == "$SUPERSIM_BASE_RPC_URL" ]]; then
    gas_estimate_multiplier="$SUPERSIM_BASE_GAS_ESTIMATE_MULTIPLIER"
  fi

  if [[ -n "$FORGE_VERBOSITY" ]]; then
    forge_args+=("$FORGE_VERBOSITY")
  fi

  forge_args+=(--rpc-url "$rpc_url" --sig "runLocal()")

  if [[ -n "$SENDER" ]]; then
    forge_args+=(--unlocked --sender "$SENDER")
  fi

  if [[ -n "$BROADCAST_FLAG" ]]; then
    forge_args+=("$BROADCAST_FLAG" --slow --gas-estimate-multiplier "$gas_estimate_multiplier")
    if [[ "$FORGE_RESUME" -eq 1 ]]; then
      forge_args+=(--resume)
    fi
  fi

  "${forge_args[@]}" "$@"
}

generate_deployment_summary() {
  local out_dir="$1"
  local out_path="$REPO_ROOT/$out_dir/deployment_summary.json"

  python3 - "$REPO_ROOT/$out_dir" "$out_path" <<'PY'
import glob
import json
import os
import sys

deployments_dir = sys.argv[1]
out_path = sys.argv[2]

paths = [
    p
    for p in glob.glob(os.path.join(deployments_dir, "*.json"))
    if not p.endswith(".tokenlist.json") and not p.endswith("deployment_summary.json")
]

def sort_key(path: str) -> tuple[int, str]:
    name = os.path.basename(path)
    if len(name) > 2 and name[:2].isdigit() and name[2] in {"_", "-"}:
        return (0, name)
    return (1, name)

merged = {}
for path in sorted(paths, key=sort_key):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict):
            merged.update(data)
    except Exception:
        continue

with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(merged, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

ensure_stage_dirs() {
  mkdir -p \
    "$SUPERSIM_LOGS_DIR" \
    "$REPO_ROOT/$SUPERSIM_ETHEREUM_OUT_DIR" \
    "$REPO_ROOT/$SUPERSIM_BASE_OUT_DIR" \
    "$REPO_ROOT/$SUPERSIM_SHARED_OUT_DIR" \
    "$REPO_ROOT/$SUPERSIM_FRONTEND_ARTIFACTS_DIR/ethereum" \
    "$REPO_ROOT/$SUPERSIM_FRONTEND_ARTIFACTS_DIR/base"
}

remove_stage_outputs() {
  local stage="$1"
  case "$stage" in
    stage20|foundation)
      rm -f \
        "$REPO_ROOT/$SUPERSIM_ETHEREUM_OUT_DIR/20_foundation.json" \
        "$REPO_ROOT/$SUPERSIM_BASE_OUT_DIR/20_foundation.json" \
        "$REPO_ROOT/$SUPERSIM_ETHEREUM_OUT_DIR/16_protocol_detf.json" \
        "$REPO_ROOT/$SUPERSIM_BASE_OUT_DIR/16_protocol_detf.json"
      ;;
    stage21|bridge)
      rm -f \
        "$REPO_ROOT/$SUPERSIM_ETHEREUM_OUT_DIR/24_superchain_bridge.json" \
        "$REPO_ROOT/$SUPERSIM_BASE_OUT_DIR/24_superchain_bridge.json" \
        "$REPO_ROOT/$SUPERSIM_SHARED_OUT_DIR/21_bridge_infra_ethereum.json" \
        "$REPO_ROOT/$SUPERSIM_SHARED_OUT_DIR/21_bridge_infra_base.json"
      ;;
    stage22|configure)
      rm -f \
        "$REPO_ROOT/$SUPERSIM_ETHEREUM_OUT_DIR/25_superchain_bridge_config.json" \
        "$REPO_ROOT/$SUPERSIM_BASE_OUT_DIR/25_superchain_bridge_config.json" \
        "$REPO_ROOT/$SUPERSIM_SHARED_OUT_DIR/22_bridge_config_ethereum.json" \
        "$REPO_ROOT/$SUPERSIM_SHARED_OUT_DIR/22_bridge_config_base.json"
      ;;
    stage23|validate)
      rm -f \
        "$REPO_ROOT/$SUPERSIM_ETHEREUM_OUT_DIR/26_bridge_test.json" \
        "$REPO_ROOT/$SUPERSIM_BASE_OUT_DIR/26_bridge_test.json" \
        "$REPO_ROOT/$SUPERSIM_SHARED_OUT_DIR/23_bridge_validation_ethereum.json" \
        "$REPO_ROOT/$SUPERSIM_SHARED_OUT_DIR/23_bridge_validation_base.json"
      ;;
    scenario4)
      remove_stage_outputs foundation
      remove_stage_outputs bridge
      remove_stage_outputs configure
      remove_stage_outputs validate
      ;;
  esac
}

run_local_script() {
  local rpc_url="$1"
  local script_target="$2"
  local network_profile="$3"
  local out_dir="$4"
  local remote_out_dir="${5:-}"

  SENDER="$SENDER" \
  OWNER="$OWNER" \
  DEPLOYER_ADDRESS="$DEPLOYER_ADDRESS" \
  NETWORK_PROFILE="$network_profile" \
  OUT_DIR_OVERRIDE="$out_dir" \
  REMOTE_OUT_DIR="$remote_out_dir" \
  SUPERSIM_ETHEREUM_RPC_URL="$SUPERSIM_ETHEREUM_RPC_URL" \
  SUPERSIM_BASE_RPC_URL="$SUPERSIM_BASE_RPC_URL" \
  SUPERSIM_ETHEREUM_OUT_DIR="$SUPERSIM_ETHEREUM_OUT_DIR" \
  SUPERSIM_BASE_OUT_DIR="$SUPERSIM_BASE_OUT_DIR" \
  SUPERSIM_SHARED_OUT_DIR="$SUPERSIM_SHARED_OUT_DIR" \
  SUPERSIM_FRONTEND_ARTIFACTS_DIR="$SUPERSIM_FRONTEND_ARTIFACTS_DIR" \
    run_forge_script "$script_target" "$rpc_url"
}

run_stage20() {
  log_info "Running Stage 20 foundation on Ethereum"
  run_local_script \
    "$SUPERSIM_ETHEREUM_RPC_URL" \
    "scripts/foundry/local_testing/supersim/ethereum/Script_20_DeployFoundation.s.sol:Script_20_DeployFoundation" \
    "ethereum_sepolia" \
    "$SUPERSIM_ETHEREUM_OUT_DIR"
  generate_deployment_summary "$SUPERSIM_ETHEREUM_OUT_DIR"

  log_info "Running Stage 20 foundation on Base"
  run_local_script \
    "$SUPERSIM_BASE_RPC_URL" \
    "scripts/foundry/local_testing/supersim/base/Script_20_DeployFoundation.s.sol:Script_20_DeployFoundation" \
    "base_sepolia" \
    "$SUPERSIM_BASE_OUT_DIR"
  generate_deployment_summary "$SUPERSIM_BASE_OUT_DIR"
}

run_stage21() {
  log_info "Running Stage 21 bridge infra on Ethereum"
  run_local_script \
    "$SUPERSIM_ETHEREUM_RPC_URL" \
    "scripts/foundry/local_testing/supersim/Script_21_DeployBridgeInfra.s.sol:Script_21_DeployBridgeInfra" \
    "ethereum_sepolia" \
    "$SUPERSIM_ETHEREUM_OUT_DIR"

  log_info "Running Stage 21 bridge infra on Base"
  run_local_script \
    "$SUPERSIM_BASE_RPC_URL" \
    "scripts/foundry/local_testing/supersim/Script_21_DeployBridgeInfra.s.sol:Script_21_DeployBridgeInfra" \
    "base_sepolia" \
    "$SUPERSIM_BASE_OUT_DIR"
}

run_stage22() {
  log_info "Running Stage 22 bridge config on Ethereum"
  run_local_script \
    "$SUPERSIM_ETHEREUM_RPC_URL" \
    "scripts/foundry/local_testing/supersim/Script_22_ConfigureSingleVaultDetfBridge.s.sol:Script_22_ConfigureSingleVaultDetfBridge" \
    "ethereum_sepolia" \
    "$SUPERSIM_ETHEREUM_OUT_DIR" \
    "$SUPERSIM_BASE_OUT_DIR"

  log_info "Running Stage 22 bridge config on Base"
  run_local_script \
    "$SUPERSIM_BASE_RPC_URL" \
    "scripts/foundry/local_testing/supersim/Script_22_ConfigureSingleVaultDetfBridge.s.sol:Script_22_ConfigureSingleVaultDetfBridge" \
    "base_sepolia" \
    "$SUPERSIM_BASE_OUT_DIR" \
    "$SUPERSIM_ETHEREUM_OUT_DIR"
}

run_stage23() {
  local ethereum_shared_manifest="$REPO_ROOT/$SUPERSIM_SHARED_OUT_DIR/23_bridge_validation_ethereum.json"
  local base_shared_manifest="$REPO_ROOT/$SUPERSIM_SHARED_OUT_DIR/23_bridge_validation_base.json"

  log_info "Running Stage 23 bridge validation on Ethereum"
  run_local_script \
    "$SUPERSIM_ETHEREUM_RPC_URL" \
    "scripts/foundry/local_testing/supersim/Script_23_ValidateSingleVaultDetfBridge.s.sol:Script_23_ValidateSingleVaultDetfBridge" \
    "ethereum_sepolia" \
    "$SUPERSIM_ETHEREUM_OUT_DIR" \
    "$SUPERSIM_BASE_OUT_DIR"
  require_file "$ethereum_shared_manifest"
  log_info "Stage 23 Ethereum manifest ready: $ethereum_shared_manifest"

  log_info "Running Stage 23 bridge validation on Base"
  run_local_script \
    "$SUPERSIM_BASE_RPC_URL" \
    "scripts/foundry/local_testing/supersim/Script_23_ValidateSingleVaultDetfBridge.s.sol:Script_23_ValidateSingleVaultDetfBridge" \
    "base_sepolia" \
    "$SUPERSIM_BASE_OUT_DIR" \
    "$SUPERSIM_ETHEREUM_OUT_DIR"
  require_file "$base_shared_manifest"
  log_info "Stage 23 Base manifest ready: $base_shared_manifest"
}

export_frontend_artifacts() {
  python3 scripts/foundry/supersim/export_frontend_artifacts.py \
    "$SUPERSIM_ETHEREUM_OUT_DIR" \
    "$SUPERSIM_FRONTEND_ARTIFACTS_DIR/ethereum" \
    11155111

  python3 scripts/foundry/supersim/export_frontend_artifacts.py \
    "$SUPERSIM_BASE_OUT_DIR" \
    "$SUPERSIM_FRONTEND_ARTIFACTS_DIR/base" \
    84532
}

command_requires_fresh_supersim() {
  case "$1" in
    foundation|stage20|scenario4)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

start_supersim_if_needed() {
  local ethereum_up=0
  local base_up=0

  if rpc_available "$SUPERSIM_ETHEREUM_RPC_URL"; then
    ethereum_up=1
  fi

  if rpc_available "$SUPERSIM_BASE_RPC_URL"; then
    base_up=1
  fi

  if [[ "$ethereum_up" -eq 1 && "$base_up" -eq 1 ]] && \
    rpc_matches_chain_id "$SUPERSIM_ETHEREUM_RPC_URL" "$SUPERSIM_ETHEREUM_CHAIN_ID" && \
    rpc_matches_chain_id "$SUPERSIM_BASE_RPC_URL" "$SUPERSIM_BASE_CHAIN_ID"; then
    log_info "Reusing SuperSim at $SUPERSIM_ETHEREUM_RPC_URL / $SUPERSIM_BASE_RPC_URL"
    return 0
  fi

  if [[ "$ethereum_up" -eq 1 || "$base_up" -eq 1 ]]; then
    local ethereum_chain_id=""
    local base_chain_id=""

    if [[ "$ethereum_up" -eq 1 ]]; then
      ethereum_chain_id="$(rpc_chain_id "$SUPERSIM_ETHEREUM_RPC_URL")"
    fi

    if [[ "$base_up" -eq 1 ]]; then
      base_chain_id="$(rpc_chain_id "$SUPERSIM_BASE_RPC_URL")"
    fi

    echo "SuperSim ports are occupied by another process or wrong chains. Refusing to reuse a partial or mismatched session." >&2
    echo "  Ethereum RPC: $SUPERSIM_ETHEREUM_RPC_URL chainId=${ethereum_chain_id:-unavailable} expected=$(printf '0x%x' "$SUPERSIM_ETHEREUM_CHAIN_ID")" >&2
    echo "  Base RPC:     $SUPERSIM_BASE_RPC_URL chainId=${base_chain_id:-unavailable} expected=$(printf '0x%x' "$SUPERSIM_BASE_CHAIN_ID")" >&2
    echo "Free those ports, override SUPERSIM_*_PORT/SUPERSIM_*_RPC_URL, or stop the conflicting local node and retry." >&2
    exit 1
  fi

  require_supersim_fork_sources

  local supersim_cmd=(
    supersim fork
    --network="$SUPERSIM_NETWORK"
    --chains="$SUPERSIM_BASE_CHAIN"
    --l1.fork.height="$SUPERSIM_L1_FORK_HEIGHT"
    --l1.port="$SUPERSIM_L1_PORT"
    --l2.starting.port="$SUPERSIM_BASE_PORT"
    --admin.port="$SUPERSIM_ADMIN_PORT"
    --l1.host="$SUPERSIM_HOST"
    --l2.host="$SUPERSIM_HOST"
    --logs.directory="$SUPERSIM_LOGS_DIR"
  )

  if [[ "$SUPERSIM_AUTORELAY" == "1" ]]; then
    supersim_cmd+=(--interop.autorelay)
  fi

  log_info "Starting SuperSim"
  SUPERSIM_RPC_URL_SEPOLIA="$SUPERSIM_SOURCE_SEPOLIA_RPC_URL" \
  SUPERSIM_RPC_URL_BASE="$SUPERSIM_SOURCE_BASE_RPC_URL" \
  SUPERSIM_L1_FORK_HEIGHT="$SUPERSIM_L1_FORK_HEIGHT" \
    nohup "${supersim_cmd[@]}" >"$SUPERSIM_LOGS_DIR/supersim.log" 2>&1 &
  echo $! >"$(supersim_pid_file)"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    scenario4|foundation|bridge|configure|validate|stage20|stage21|stage22|stage23)
      COMMAND="$1"
      shift
      ;;
    --dry-run)
      BROADCAST_FLAG=""
      shift
      ;;
    --resume)
      FORGE_RESUME=1
      shift
      ;;
    --force)
      FORCE_RERUN=1
      shift
      ;;
    --restart-supersim)
      RESTART_SUPERSIM=1
      shift
      ;;
    --kill-supersim)
      KILL_SUPERSIM=1
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
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$KILL_SUPERSIM" -eq 1 ]]; then
  stop_supersim_if_running
  exit 0
fi

require_env DEPLOYER_ADDRESS "$DEPLOYER_ADDRESS"

ensure_stage_dirs

if command_requires_fresh_supersim "$COMMAND" && [[ "$RESTART_SUPERSIM" -eq 0 ]]; then
  log_info "Auto-enabling --restart-supersim for $COMMAND because Stage 20 cannot reuse an existing SuperSim deployment state"
  RESTART_SUPERSIM=1
fi

if [[ "$RESTART_SUPERSIM" -eq 1 ]]; then
  stop_supersim_if_running
fi

start_supersim_if_needed
wait_for_rpc "$SUPERSIM_ETHEREUM_RPC_URL" "SuperSim Ethereum"
wait_for_rpc "$SUPERSIM_BASE_RPC_URL" "SuperSim Base"
sanitize_dev_accounts "$SUPERSIM_ETHEREUM_RPC_URL"
sanitize_dev_accounts "$SUPERSIM_BASE_RPC_URL"
prepare_broadcast_identity

cd "$REPO_ROOT"

if [[ "$FORCE_RERUN" -eq 1 ]]; then
  remove_stage_outputs "$COMMAND"
fi

if [[ "${PRIVATE_KEY:-}" == "$SUPERSIM_DEFAULT_PRIVATE_KEY_0" ]] || is_default_supersim_sender "$DEPLOYER_ADDRESS"; then
  log_info "Skipping ETH sweep for pre-funded SuperSim identity $DEPLOYER_ADDRESS"
else
  log_info "Sweeping ETH to deployer on SuperSim Ethereum"
  sweep_eth_to_deployer_address "$SUPERSIM_ETHEREUM_RPC_URL" "scripts/foundry/anvil_sepolia/Script_00_SweepEthToDev0.s.sol"
  log_info "Sweeping ETH to deployer on SuperSim Base"
  sweep_eth_to_deployer_address "$SUPERSIM_BASE_RPC_URL" "scripts/foundry/anvil_base_main/Script_00_SweepEthToDev0.s.sol"
fi

case "$COMMAND" in
  foundation|stage20)
    run_stage20
    ;;
  bridge|stage21)
    run_stage21
    ;;
  configure|stage22)
    run_stage22
    ;;
  validate|stage23)
    run_stage23
    ;;
  scenario4)
    run_stage20
    run_stage21
    run_stage22
    run_stage23
    export_frontend_artifacts
    ;;
esac

log_info "Local SuperSim testing command complete"