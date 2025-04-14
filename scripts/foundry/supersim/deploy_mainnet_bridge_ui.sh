#!/usr/bin/env bash

if [ -z "${ZSH_VERSION:-}${BASH_VERSION:-}" ]; then
  echo "Unsupported shell: ${SHELL:-unknown}. Run this script from zsh or bash." >&2
  exit 1
fi

# Usage:
#   DEPLOYER_ADDRESS=<unlocked SuperSim account> scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh
#   scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh --kill-supersim
#   DEPLOYER_ADDRESS=<unlocked SuperSim account> scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh --restart-supersim
#
# Required environment variables:
#   DEPLOYER_ADDRESS   Unlocked account used as the Foundry sender for deployment.
#                      This address is also pre-funded from the default Anvil accounts
#                      on both forks before deployment starts unless `--kill-supersim`
#                      is used.
#
# Optional environment variables:
#   FINAL_RECIPIENT_ADDRESS
#                      Optional future recipient for a separate post-deploy sweep phase.
#                      This script does not currently perform that final sweep.
#   FOUNDRY_ETHEREUM_SEPOLIA_RPC_ALIAS
#                      Foundry RPC alias used to resolve the Ethereum Sepolia upstream fork URL.
#                      Defaults to `ethereum_sepolia_alchemy`.
#   FOUNDRY_BASE_SEPOLIA_RPC_ALIAS
#                      Foundry RPC alias used to resolve the Base Sepolia upstream fork URL.
#                      Defaults to `base_sepolia_alchemy`.
#   ETHEREUM_SEPOLIA_RPC_URL
#                      Upstream Ethereum Sepolia RPC URL used when launching SuperSim fork mode.
#                      If unset, the wrapper falls back to the Foundry RPC alias.
#                      If `SUPERSIM_RPC_URL_SEPOLIA` is set, that value takes precedence.
#   BASE_SEPOLIA_RPC_URL
#                      Upstream Base Sepolia RPC URL used when launching SuperSim fork mode.
#                      If unset, the wrapper falls back to the Foundry RPC alias.
#                      If `SUPERSIM_RPC_URL_BASE` is set, that value takes precedence.
#   SUPERSIM_L1_FORK_HEIGHT
#                      Canonical Sepolia fork height for SuperSim. Defaults to the
#                      `DEFAULT_FORK_BLOCK` value declared in Crane's Sepolia network constants.
#   SUPERSIM_HOST      SuperSim host. Defaults to 127.0.0.1.
#   SUPERSIM_L1_PORT   Ethereum Sepolia fork RPC port. Defaults to 8545.
#   SUPERSIM_BASE_PORT Base Sepolia fork RPC port. Defaults to 9545.
#   SUPERSIM_BASE_CHAIN
#                      SuperSim L2 chain selector for the Sepolia superchain.
#                      Defaults to `base`.
#   SUPERSIM_GAS_ESTIMATE_MULTIPLIER
#                      Foundry gas estimate multiplier used for local SuperSim broadcasts.
#                      Defaults to `110` to avoid overshooting the local block gas limit on
#                      large Stage 16 vault deployments while still leaving margin above the
#                      raw estimate.
#   SUPERSIM_ETHEREUM_GAS_ESTIMATE_MULTIPLIER
#                      Gas estimate multiplier override for Ethereum-side broadcasts.
#                      Defaults to `SUPERSIM_GAS_ESTIMATE_MULTIPLIER`.
#   SUPERSIM_BASE_GAS_ESTIMATE_MULTIPLIER
#                      Gas estimate multiplier override for Base-side broadcasts.
#                      Defaults to `150` because local Aerodrome LP mint flows materially
#                      underestimate gas on the Base fork during later liquidity seeding stages.
#
# What this script does:
#   1. Starts SuperSim if it is not already running.
#   2. Waits for both Ethereum and Base RPC endpoints.
#   3. Sweeps ETH to DEPLOYER_ADDRESS on both forks so the broadcast sender has gas.
#   4. Runs the minimal Ethereum Protocol DETF deployment on the Ethereum fork,
#      including the custom BalancerV3StandardExchangeRouter package + proxy.
#   5. Runs the minimal Base Protocol DETF deployment on the Base fork,
#      including the custom BalancerV3StandardExchangeRouter package + proxy.
#   6. Deploys Superchain bridge infrastructure on both forks.
#   7. Configures the Superchain bridge on both forks.
#   8. Exports frontend address artifacts for both chains.
#   9. Verifies the custom router artifacts exist and have bytecode on both forks.
#   10. Does not perform a final sweep to FINAL_RECIPIENT_ADDRESS; that should be a distinct
#      post-deploy step if you want the final balances consolidated elsewhere.
#
# Example:
#   DEPLOYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
#   scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh
#
# Restart example:
#   DEPLOYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
#   scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh --restart-supersim
#
# Verbosity example:
#   DEPLOYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
#   scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh --restart-supersim -vvvv
#
# Kill example:
#   scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh --kill-supersim

set -euo pipefail

SCRIPT_PATH="$0"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

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
    echo "Resolved template still contains unsubstituted variables: $resolved" >&2
    exit 1
  fi

  echo "$resolved"
}

ETHEREUM_SEPOLIA_DEFAULT_FORK_BLOCK="$(extract_default_fork_block "$ETHEREUM_SEPOLIA_CONSTANTS_FILE")"
BASE_SEPOLIA_DEFAULT_FORK_BLOCK="$(extract_default_fork_block "$BASE_SEPOLIA_CONSTANTS_FILE")"

if [[ "$ETHEREUM_SEPOLIA_DEFAULT_FORK_BLOCK" != "$BASE_SEPOLIA_DEFAULT_FORK_BLOCK" ]]; then
  echo "Ethereum Sepolia and Base Sepolia DEFAULT_FORK_BLOCK values diverged." >&2
  echo "This wrapper only supports a single explicit SuperSim fork height." >&2
  echo "Ethereum Sepolia: $ETHEREUM_SEPOLIA_DEFAULT_FORK_BLOCK" >&2
  echo "Base Sepolia:     $BASE_SEPOLIA_DEFAULT_FORK_BLOCK" >&2
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
SUPERSIM_LOGS_DIR="${SUPERSIM_LOGS_DIR:-$REPO_ROOT/deployments/supersim_sepolia/runtime}"

SUPERSIM_ETHEREUM_OUT_DIR="${SUPERSIM_ETHEREUM_OUT_DIR:-deployments/supersim_sepolia/ethereum}"
SUPERSIM_BASE_OUT_DIR="${SUPERSIM_BASE_OUT_DIR:-deployments/supersim_sepolia/base}"
SUPERSIM_SHARED_OUT_DIR="${SUPERSIM_SHARED_OUT_DIR:-deployments/supersim_sepolia/shared}"
SUPERSIM_FRONTEND_ARTIFACTS_DIR="${SUPERSIM_FRONTEND_ARTIFACTS_DIR:-frontend/app/addresses/supersim_sepolia}"

SUPERSIM_ETHEREUM_RPC_URL="${SUPERSIM_ETHEREUM_RPC_URL:-http://${SUPERSIM_HOST}:${SUPERSIM_L1_PORT}}"
SUPERSIM_BASE_RPC_URL="${SUPERSIM_BASE_RPC_URL:-http://${SUPERSIM_HOST}:${SUPERSIM_BASE_PORT}}"
DEFAULT_ETHEREUM_SEPOLIA_RPC_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_ETHEREUM_SEPOLIA_RPC_ALIAS")"
DEFAULT_BASE_SEPOLIA_RPC_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_BASE_SEPOLIA_RPC_ALIAS")"
SUPERSIM_SOURCE_SEPOLIA_RPC_URL="${SUPERSIM_RPC_URL_SEPOLIA:-${ETHEREUM_SEPOLIA_RPC_URL:-$DEFAULT_ETHEREUM_SEPOLIA_RPC_URL}}"
SUPERSIM_SOURCE_BASE_RPC_URL="${SUPERSIM_RPC_URL_BASE:-${BASE_SEPOLIA_RPC_URL:-$DEFAULT_BASE_SEPOLIA_RPC_URL}}"

DEPLOYER_ADDRESS="${DEPLOYER_ADDRESS:-}"
FINAL_RECIPIENT_ADDRESS="${FINAL_RECIPIENT_ADDRESS:-$DEPLOYER_ADDRESS}"

RESTART_SUPERSIM=0
KILL_SUPERSIM=0
FORGE_VERBOSITY=""

print_help() {
  awk '
    /^# Usage:/ { printing = 1 }
    printing {
      if ($0 ~ /^set -euo pipefail$/) {
        exit
      }
      sub(/^# ?/, "")
      print
    }
  ' "$SCRIPT_PATH"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restart-supersim)
      RESTART_SUPERSIM=1
      shift
      ;;
    --kill-supersim)
      KILL_SUPERSIM=1
      shift
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    -v|-vv|-vvv|-vvvv|-vvvvv)
      if [[ -n "$FORGE_VERBOSITY" ]]; then
        echo "Only one verbosity flag may be provided." >&2
        exit 1
      fi
      FORGE_VERBOSITY="$1"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Use --help to see supported commands." >&2
      exit 1
      ;;
  esac
done

if [[ "$RESTART_SUPERSIM" == "1" && "$KILL_SUPERSIM" == "1" ]]; then
  echo "Use either --restart-supersim or --kill-supersim, not both." >&2
  exit 1
fi

mkdir -p "$SUPERSIM_LOGS_DIR" \
  "$REPO_ROOT/$SUPERSIM_ETHEREUM_OUT_DIR" \
  "$REPO_ROOT/$SUPERSIM_BASE_OUT_DIR" \
  "$REPO_ROOT/$SUPERSIM_SHARED_OUT_DIR" \
  "$REPO_ROOT/$SUPERSIM_FRONTEND_ARTIFACTS_DIR/ethereum" \
  "$REPO_ROOT/$SUPERSIM_FRONTEND_ARTIFACTS_DIR/base"

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
    echo "Stopping existing SuperSim process: $pid" >&2
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

redact_url() {
  local url="$1"
  local sanitized

  if [[ -z "$url" ]]; then
    printf '<unset>'
    return 0
  fi

  if [[ "$url" == *"/v2/"* ]]; then
    sanitized="${url%%/v2/*}/v2/<redacted>"
    if [[ "$url" == *"?"* ]]; then
      sanitized+="?${url#*\?}"
    fi
    printf '%s' "$sanitized" | sed -E 's/(apiKey=)[^&#]*/\1<redacted>/g'
    return 0
  fi

  if [[ "$url" == *"apiKey="* ]]; then
    printf '%s' "$url" | sed -E 's/(apiKey=)[^&#]*/\1<redacted>/g'
    return 0
  fi

  printf '%s' "$url"
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

  if [[ -n "$FORGE_VERBOSITY" ]]; then
    forge_args+=("$FORGE_VERBOSITY")
  fi

  for sender in "${senders[@]}"; do
    DEV0_ADDRESS="$DEPLOYER_ADDRESS" "${forge_args[@]}" \
      --rpc-url "$rpc_url" \
      --broadcast \
      --unlocked \
      --sender "$sender"
  done
}

is_default_supersim_sender() {
  local candidate="$1"
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
  local normalized="$(echo "$candidate" | tr '[:upper:]' '[:lower:]')"
  local sender

  for sender in "${known_senders[@]}"; do
    if [[ "$normalized" == "$sender" ]]; then
      return 0
    fi
  done

  return 1
}

require_supported_broadcast_identity() {
  if [[ -n "${PRIVATE_KEY:-}" ]]; then
    return 0
  fi

  if ! is_default_supersim_sender "$DEPLOYER_ADDRESS"; then
    echo "DEPLOYER_ADDRESS is not a default unlocked dev account: $DEPLOYER_ADDRESS" >&2
    echo "The wrapper will impersonate this account on both SuperSim forks before broadcasting." >&2
  fi
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

run_forge_script() {
  local script_path="$1"
  local rpc_url="$2"
  shift 2

  local forge_args=(forge script "$script_path")
  local gas_estimate_multiplier

  if [[ "$rpc_url" == "$SUPERSIM_BASE_RPC_URL" ]]; then
    gas_estimate_multiplier="$SUPERSIM_BASE_GAS_ESTIMATE_MULTIPLIER"
  else
    gas_estimate_multiplier="$SUPERSIM_ETHEREUM_GAS_ESTIMATE_MULTIPLIER"
  fi

  if [[ -n "$FORGE_VERBOSITY" ]]; then
    forge_args+=("$FORGE_VERBOSITY")
  fi

  forge_args+=(--rpc-url "$rpc_url" --broadcast --slow --gas-estimate-multiplier "$gas_estimate_multiplier")

  if [[ -n "${PRIVATE_KEY:-}" ]]; then
    forge_args+=(--private-key "$PRIVATE_KEY")
  else
    forge_args+=(--unlocked --sender "$DEPLOYER_ADDRESS")
  fi

  "${forge_args[@]}" "$@"
}

run_deploy_script() {
  local rpc_url="$1"
  local script_path="$2"
  local network_profile="$3"
  local out_dir="$4"

  echo "Running deployment script: $script_path" >&2
  echo "  RPC: $rpc_url" >&2
  echo "  Network profile: $network_profile" >&2
  echo "  Out dir: $out_dir" >&2

  SENDER="$DEPLOYER_ADDRESS" \
  NETWORK_PROFILE="$network_profile" \
  OUT_DIR_OVERRIDE="$out_dir" \
  SUPERSIM_ETHEREUM_RPC_URL="$SUPERSIM_ETHEREUM_RPC_URL" \
  SUPERSIM_BASE_RPC_URL="$SUPERSIM_BASE_RPC_URL" \
    run_forge_script "$script_path" "$rpc_url"
}

generate_deployment_summary() {
  local out_dir="$1"
  local out_path="$REPO_ROOT/$out_dir/deployment_summary.json"

  echo "Generating deployment summary: $out_path" >&2

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

def sort_key(p: str) -> tuple:
    name = os.path.basename(p)
    if len(name) > 2 and name[:2].isdigit() and name[2] in {"_", "-"}:
        return (0, name)
    return (1, name)

merged = {}
for path in sorted(paths, key=sort_key):
    try:
        with open(path, "r") as handle:
            data = json.load(handle)
        if isinstance(data, dict):
            merged.update(data)
    except Exception:
        continue

with open(out_path, "w") as handle:
    json.dump(merged, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

run_bridge_infra_script() {
  local rpc_url="$1"
  local out_dir="$2"

  echo "Running bridge infra script on $rpc_url" >&2
  echo "  Out dir: $out_dir" >&2

  SENDER="$DEPLOYER_ADDRESS" \
  OUT_DIR_OVERRIDE="$out_dir" \
  SUPERSIM_ETHEREUM_RPC_URL="$SUPERSIM_ETHEREUM_RPC_URL" \
  SUPERSIM_BASE_RPC_URL="$SUPERSIM_BASE_RPC_URL" \
  SUPERSIM_ETHEREUM_OUT_DIR="$SUPERSIM_ETHEREUM_OUT_DIR" \
  SUPERSIM_BASE_OUT_DIR="$SUPERSIM_BASE_OUT_DIR" \
  SUPERSIM_SHARED_OUT_DIR="$SUPERSIM_SHARED_OUT_DIR" \
  SUPERSIM_FRONTEND_ARTIFACTS_DIR="$SUPERSIM_FRONTEND_ARTIFACTS_DIR" \
    run_forge_script "scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol:Script_24_DeploySuperchainBridgeInfra" "$rpc_url"
}

run_bridge_config_script() {
  local rpc_url="$1"
  local out_dir="$2"
  local remote_out_dir="$3"

  echo "Running bridge config script on $rpc_url" >&2
  echo "  Out dir: $out_dir" >&2
  echo "  Remote out dir: $remote_out_dir" >&2

  SENDER="$DEPLOYER_ADDRESS" \
  OUT_DIR_OVERRIDE="$out_dir" \
  REMOTE_OUT_DIR="$remote_out_dir" \
  SUPERSIM_ETHEREUM_RPC_URL="$SUPERSIM_ETHEREUM_RPC_URL" \
  SUPERSIM_BASE_RPC_URL="$SUPERSIM_BASE_RPC_URL" \
  SUPERSIM_ETHEREUM_OUT_DIR="$SUPERSIM_ETHEREUM_OUT_DIR" \
  SUPERSIM_BASE_OUT_DIR="$SUPERSIM_BASE_OUT_DIR" \
  SUPERSIM_SHARED_OUT_DIR="$SUPERSIM_SHARED_OUT_DIR" \
  SUPERSIM_FRONTEND_ARTIFACTS_DIR="$SUPERSIM_FRONTEND_ARTIFACTS_DIR" \
    run_forge_script "scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol:Script_25_ConfigureProtocolDetfBridge" "$rpc_url"
}

if [[ "$KILL_SUPERSIM" == "1" ]]; then
  stop_supersim_if_running
  echo "SuperSim stopped." >&2
  exit 0
fi

require_env DEPLOYER_ADDRESS "$DEPLOYER_ADDRESS"
require_supported_broadcast_identity

echo "Using deployer sender: $DEPLOYER_ADDRESS" >&2

if [[ "$FINAL_RECIPIENT_ADDRESS" != "$DEPLOYER_ADDRESS" ]]; then
  echo "Note: FINAL_RECIPIENT_ADDRESS differs from DEPLOYER_ADDRESS." >&2
  echo "Note: This script deploys from DEPLOYER_ADDRESS and does not perform a final post-deploy sweep." >&2
fi

if [[ "$RESTART_SUPERSIM" == "1" ]]; then
  stop_supersim_if_running
fi

if ! curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  "$SUPERSIM_ETHEREUM_RPC_URL" >/dev/null 2>&1; then
  require_supersim_fork_sources

  SUPERSIM_CMD=(
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
    SUPERSIM_CMD+=(--interop.autorelay)
  fi

  echo "Launching SuperSim from explicit chain state:" >&2
  echo "  Ethereum Sepolia RPC: $(redact_url "$SUPERSIM_SOURCE_SEPOLIA_RPC_URL")" >&2
  echo "  Base Sepolia RPC:     $(redact_url "$SUPERSIM_SOURCE_BASE_RPC_URL")" >&2
  echo "  Fork height:          $SUPERSIM_L1_FORK_HEIGHT" >&2

  SUPERSIM_RPC_URL_SEPOLIA="$SUPERSIM_SOURCE_SEPOLIA_RPC_URL" \
  SUPERSIM_RPC_URL_BASE="$SUPERSIM_SOURCE_BASE_RPC_URL" \
  SUPERSIM_L1_FORK_HEIGHT="$SUPERSIM_L1_FORK_HEIGHT" \
  nohup "${SUPERSIM_CMD[@]}" >"$SUPERSIM_LOGS_DIR/supersim.log" 2>&1 &
  echo $! >"$(supersim_pid_file)"
else
  echo "Reusing existing SuperSim instance at $SUPERSIM_ETHEREUM_RPC_URL / $SUPERSIM_BASE_RPC_URL." >&2
  echo "This script cannot verify that an already-running instance was started from the canonical fork sources and height." >&2
  echo "Use --restart-supersim to enforce explicit Sepolia/Base Sepolia fork configuration." >&2
fi

wait_for_rpc "$SUPERSIM_ETHEREUM_RPC_URL" "SuperSim Ethereum"
wait_for_rpc "$SUPERSIM_BASE_RPC_URL" "SuperSim Base"

prepare_broadcast_identity

cd "$REPO_ROOT"

echo "Sweeping ETH to deployer on SuperSim Ethereum..." >&2
sweep_eth_to_deployer_address "$SUPERSIM_ETHEREUM_RPC_URL" "scripts/foundry/anvil_sepolia/Script_00_SweepEthToDev0.s.sol"
echo "Sweeping ETH to deployer on SuperSim Base..." >&2
sweep_eth_to_deployer_address "$SUPERSIM_BASE_RPC_URL" "scripts/foundry/anvil_base_main/Script_00_SweepEthToDev0.s.sol"

echo "Starting minimal Ethereum Protocol DETF deployment on SuperSim Ethereum fork..." >&2
echo "This step can run silently for several minutes while forge simulates and broadcasts." >&2

SUPERSIM_ETHEREUM_RPC_URL="$SUPERSIM_ETHEREUM_RPC_URL" \
SUPERSIM_BASE_RPC_URL="$SUPERSIM_BASE_RPC_URL" \
SUPERSIM_ETHEREUM_OUT_DIR="$SUPERSIM_ETHEREUM_OUT_DIR" \
SUPERSIM_BASE_OUT_DIR="$SUPERSIM_BASE_OUT_DIR" \
SUPERSIM_SHARED_OUT_DIR="$SUPERSIM_SHARED_OUT_DIR" \
SUPERSIM_FRONTEND_ARTIFACTS_DIR="$SUPERSIM_FRONTEND_ARTIFACTS_DIR" \
run_deploy_script \
  "$SUPERSIM_ETHEREUM_RPC_URL" \
  "scripts/foundry/supersim/ethereum/Script_DeployProtocolDetfMinimal.s.sol:Script_DeployProtocolDetfMinimal" \
  "ethereum_sepolia" \
  "$SUPERSIM_ETHEREUM_OUT_DIR"

generate_deployment_summary "$SUPERSIM_ETHEREUM_OUT_DIR"

echo "Starting minimal Base Protocol DETF deployment on SuperSim Base fork..." >&2
echo "This step can run silently for several minutes while forge simulates and broadcasts." >&2

SUPERSIM_ETHEREUM_RPC_URL="$SUPERSIM_ETHEREUM_RPC_URL" \
SUPERSIM_BASE_RPC_URL="$SUPERSIM_BASE_RPC_URL" \
SUPERSIM_ETHEREUM_OUT_DIR="$SUPERSIM_ETHEREUM_OUT_DIR" \
SUPERSIM_BASE_OUT_DIR="$SUPERSIM_BASE_OUT_DIR" \
SUPERSIM_SHARED_OUT_DIR="$SUPERSIM_SHARED_OUT_DIR" \
SUPERSIM_FRONTEND_ARTIFACTS_DIR="$SUPERSIM_FRONTEND_ARTIFACTS_DIR" \
run_deploy_script \
  "$SUPERSIM_BASE_RPC_URL" \
  "scripts/foundry/supersim/base/Script_DeployProtocolDetfMinimal.s.sol:Script_DeployProtocolDetfMinimal" \
  "base_sepolia" \
  "$SUPERSIM_BASE_OUT_DIR"

generate_deployment_summary "$SUPERSIM_BASE_OUT_DIR"

echo "Deploying Superchain bridge infrastructure on Ethereum..." >&2

SUPERSIM_ETHEREUM_RPC_URL="$SUPERSIM_ETHEREUM_RPC_URL" \
SUPERSIM_BASE_RPC_URL="$SUPERSIM_BASE_RPC_URL" \
SUPERSIM_ETHEREUM_OUT_DIR="$SUPERSIM_ETHEREUM_OUT_DIR" \
SUPERSIM_BASE_OUT_DIR="$SUPERSIM_BASE_OUT_DIR" \
SUPERSIM_SHARED_OUT_DIR="$SUPERSIM_SHARED_OUT_DIR" \
SUPERSIM_FRONTEND_ARTIFACTS_DIR="$SUPERSIM_FRONTEND_ARTIFACTS_DIR" \
run_bridge_infra_script \
  "$SUPERSIM_ETHEREUM_RPC_URL" \
  "$SUPERSIM_ETHEREUM_OUT_DIR"

echo "Deploying Superchain bridge infrastructure on Base..." >&2

SUPERSIM_ETHEREUM_RPC_URL="$SUPERSIM_ETHEREUM_RPC_URL" \
SUPERSIM_BASE_RPC_URL="$SUPERSIM_BASE_RPC_URL" \
SUPERSIM_ETHEREUM_OUT_DIR="$SUPERSIM_ETHEREUM_OUT_DIR" \
SUPERSIM_BASE_OUT_DIR="$SUPERSIM_BASE_OUT_DIR" \
SUPERSIM_SHARED_OUT_DIR="$SUPERSIM_SHARED_OUT_DIR" \
SUPERSIM_FRONTEND_ARTIFACTS_DIR="$SUPERSIM_FRONTEND_ARTIFACTS_DIR" \
run_bridge_infra_script \
  "$SUPERSIM_BASE_RPC_URL" \
  "$SUPERSIM_BASE_OUT_DIR"

echo "Configuring Superchain bridge on Ethereum..." >&2

SUPERSIM_ETHEREUM_RPC_URL="$SUPERSIM_ETHEREUM_RPC_URL" \
SUPERSIM_BASE_RPC_URL="$SUPERSIM_BASE_RPC_URL" \
SUPERSIM_ETHEREUM_OUT_DIR="$SUPERSIM_ETHEREUM_OUT_DIR" \
SUPERSIM_BASE_OUT_DIR="$SUPERSIM_BASE_OUT_DIR" \
SUPERSIM_SHARED_OUT_DIR="$SUPERSIM_SHARED_OUT_DIR" \
SUPERSIM_FRONTEND_ARTIFACTS_DIR="$SUPERSIM_FRONTEND_ARTIFACTS_DIR" \
run_bridge_config_script \
  "$SUPERSIM_ETHEREUM_RPC_URL" \
  "$SUPERSIM_ETHEREUM_OUT_DIR" \
  "$SUPERSIM_BASE_OUT_DIR"

echo "Configuring Superchain bridge on Base..." >&2

SUPERSIM_ETHEREUM_RPC_URL="$SUPERSIM_ETHEREUM_RPC_URL" \
SUPERSIM_BASE_RPC_URL="$SUPERSIM_BASE_RPC_URL" \
SUPERSIM_ETHEREUM_OUT_DIR="$SUPERSIM_ETHEREUM_OUT_DIR" \
SUPERSIM_BASE_OUT_DIR="$SUPERSIM_BASE_OUT_DIR" \
SUPERSIM_SHARED_OUT_DIR="$SUPERSIM_SHARED_OUT_DIR" \
SUPERSIM_FRONTEND_ARTIFACTS_DIR="$SUPERSIM_FRONTEND_ARTIFACTS_DIR" \
run_bridge_config_script \
  "$SUPERSIM_BASE_RPC_URL" \
  "$SUPERSIM_BASE_OUT_DIR" \
  "$SUPERSIM_ETHEREUM_OUT_DIR"

python3 scripts/foundry/supersim/export_frontend_artifacts.py \
  "$SUPERSIM_ETHEREUM_OUT_DIR" \
  "$SUPERSIM_FRONTEND_ARTIFACTS_DIR/ethereum" \
  11155111

python3 scripts/foundry/supersim/export_frontend_artifacts.py \
  "$SUPERSIM_BASE_OUT_DIR" \
  "$SUPERSIM_FRONTEND_ARTIFACTS_DIR/base" \
  84532

echo "SuperSim Sepolia environment deployment complete"
echo "Ethereum RPC: $SUPERSIM_ETHEREUM_RPC_URL"
echo "Base RPC:     $SUPERSIM_BASE_RPC_URL"
echo "Ethereum out: $SUPERSIM_ETHEREUM_OUT_DIR"
echo "Base out:     $SUPERSIM_BASE_OUT_DIR"
echo "Shared out:   $SUPERSIM_SHARED_OUT_DIR"
