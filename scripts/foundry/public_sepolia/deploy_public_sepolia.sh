#!/usr/bin/env bash

if [ -z "${ZSH_VERSION:-}${BASH_VERSION:-}" ]; then
  echo "Unsupported shell: ${SHELL:-unknown}. Run this script from zsh or bash." >&2
  exit 1
fi

# Usage:
#   DEPLOYER_ADDRESS=<unlocked account> scripts/foundry/public_sepolia/deploy_public_sepolia.sh
#   DEPLOYER_ADDRESS=<unlocked account> scripts/foundry/public_sepolia/deploy_public_sepolia.sh --broadcast
#   DEPLOYER_ADDRESS=<unlocked account> scripts/foundry/public_sepolia/deploy_public_sepolia.sh -vvvv --broadcast
#
# Required environment variables:
#   DEPLOYER_ADDRESS   Unlocked account used as the Foundry sender for deployment.
#                      This account must have sufficient ETH on both Ethereum Sepolia
#                      and Base Sepolia.
#
# Optional environment variables:
#   ETHEREUM_SEPOLIA_RPC_URL   Ethereum Sepolia RPC. Defaults to sepolia_alchemy alias.
#   BASE_SEPOLIA_RPC_URL       Base Sepolia RPC. Defaults to base_sepolia_alchemy alias.
#   PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR  Ethereum deployment output. Defaults to deployments/public_sepolia/ethereum
#   PUBLIC_SEPOLIA_BASE_OUT_DIR      Base deployment output. Defaults to deployments/public_sepolia/base
#   PUBLIC_SEPOLIA_SHARED_OUT_DIR    Shared output. Defaults to deployments/public_sepolia/shared
#   PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR  Frontend artifacts. Defaults to frontend/app/addresses/public_sepolia
#   PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_TOKENLIST_PREFIX  Optional Ethereum tokenlist prefix for frontend export.
#   PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_CONTRACTLIST_PREFIX  Optional Ethereum contractlist prefix for frontend export.
#   PUBLIC_SEPOLIA_FRONTEND_BASE_TOKENLIST_PREFIX  Optional Base tokenlist prefix for frontend export.
#   PUBLIC_SEPOLIA_FRONTEND_BASE_CONTRACTLIST_PREFIX  Optional Base contractlist prefix for frontend export.
#
# DEPLOYMENT INVENTORY:
# - Ethereum Sepolia core deployment: full IndexedEx deployment through Stage 15 with Protocol DETF deferred.
# - Base Sepolia bridge wrappers: Optimism mintable wrapper tokens for bridged assets.
# - Cross-chain token bridging: bridges required balances from Ethereum Sepolia to Base Sepolia.
# - Base Sepolia core deployment: full IndexedEx deployment through Stage 15 with Protocol DETF deferred.
# - Superchain bridge infrastructure: deploys bridge contracts and support infrastructure on both chains.
# - Protocol DETF completion: runs Stage 16 on Ethereum Sepolia and Base Sepolia after bridge infra exists.
# - Protocol DETF bridge configuration: wires the DETF bridge relationships on both chains.
# - Deployment summaries: merges per-stage outputs into deployment summary JSON for each chain.
# - Frontend artifacts: exports chain-specific tokenlists, contractlists, and merged platform deployment addresses.
#
# What this script does:
#   1. Runs the Ethereum Sepolia core deployment via Script_DeployAll with Stage 16 deferred.
#   2. Creates Base Sepolia bridge-token wrappers through the Optimism mintable factory.
#   3. Pauses for manual wrapper verification.
#   4. Bridges required balances from Ethereum Sepolia to Base Sepolia.
#   5. Pauses for manual bridged-balance verification.
#   6. Runs the Base Sepolia core deployment via Script_DeployAll with Stage 16 deferred.
#   7. Deploys Superchain bridge infrastructure on both chains.
#   8. Deploys Protocol DETF Stage 16 on both chains after bridge infra exists.
#   9. Configures the Protocol DETF bridge on both chains.
#   10. Exports frontend address artifacts for both chains.
#
# Example (simulate):
#   DEPLOYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
#   scripts/foundry/public_sepolia/deploy_public_sepolia.sh
#
# Example (broadcast):
#   DEPLOYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
#   scripts/foundry/public_sepolia/deploy_public_sepolia.sh --broadcast
#
# Verbosity example (simulate):
#   DEPLOYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
#   scripts/foundry/public_sepolia/deploy_public_sepolia.sh -vvvv

set -euo pipefail

SCRIPT_PATH="$0"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Output directories
PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR="${PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR:-deployments/public_sepolia/ethereum}"
PUBLIC_SEPOLIA_BASE_OUT_DIR="${PUBLIC_SEPOLIA_BASE_OUT_DIR:-deployments/public_sepolia/base}"
PUBLIC_SEPOLIA_SHARED_OUT_DIR="${PUBLIC_SEPOLIA_SHARED_OUT_DIR:-deployments/public_sepolia/shared}"
PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR="${PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR:-frontend/app/addresses/public_sepolia}"
PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_BASENAME="$(basename "$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR")"

if [[ "$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_BASENAME" == "supersim_sepolia" ]]; then
  PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_TOKENLIST_PREFIX="${PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_TOKENLIST_PREFIX:-supersim_sepolia}"
  PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_CONTRACTLIST_PREFIX="${PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_CONTRACTLIST_PREFIX:-sepolia}"
  PUBLIC_SEPOLIA_FRONTEND_BASE_TOKENLIST_PREFIX="${PUBLIC_SEPOLIA_FRONTEND_BASE_TOKENLIST_PREFIX:-anvil_base_main}"
  PUBLIC_SEPOLIA_FRONTEND_BASE_CONTRACTLIST_PREFIX="${PUBLIC_SEPOLIA_FRONTEND_BASE_CONTRACTLIST_PREFIX:-}"
else
  PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_TOKENLIST_PREFIX="${PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_TOKENLIST_PREFIX:-$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_BASENAME}"
  PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_CONTRACTLIST_PREFIX="${PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_CONTRACTLIST_PREFIX:-$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_BASENAME}"
  PUBLIC_SEPOLIA_FRONTEND_BASE_TOKENLIST_PREFIX="${PUBLIC_SEPOLIA_FRONTEND_BASE_TOKENLIST_PREFIX:-$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_BASENAME}"
  PUBLIC_SEPOLIA_FRONTEND_BASE_CONTRACTLIST_PREFIX="${PUBLIC_SEPOLIA_FRONTEND_BASE_CONTRACTLIST_PREFIX:-$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_BASENAME}"
fi

# Foundry RPC aliases (defined in foundry.toml)
ETHEREUM_SEPOLIA_RPC_URL="${ETHEREUM_SEPOLIA_RPC_URL:-sepolia_alchemy}"
BASE_SEPOLIA_RPC_URL="${BASE_SEPOLIA_RPC_URL:-base_sepolia_alchemy}"

DEPLOYER_ADDRESS="${DEPLOYER_ADDRESS:-}"

FORGE_VERBOSITY=""
BROADCAST=0

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
    --help|-h)
      print_help
      exit 0
      ;;
    --broadcast)
      BROADCAST=1
      shift
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

mkdir -p "$REPO_ROOT/$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  "$REPO_ROOT/$PUBLIC_SEPOLIA_BASE_OUT_DIR" \
  "$REPO_ROOT/$PUBLIC_SEPOLIA_SHARED_OUT_DIR" \
  "$REPO_ROOT/$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR/ethereum" \
  "$REPO_ROOT/$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR/base"

require_env() {
  local key="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "Missing required env: $key" >&2
    exit 1
  fi
}

run_forge_script() {
  local script_path="$1"
  local rpc_url="$2"
  shift 2

  local forge_args=(forge script "$script_path")

  if [[ -n "$FORGE_VERBOSITY" ]]; then
    forge_args+=("$FORGE_VERBOSITY")
  fi

  forge_args+=(--rpc-url "$rpc_url")

  if [[ "$BROADCAST" == "1" ]]; then
    forge_args+=(--broadcast --slow)
  fi

  if [[ -n "${DEPLOYER_ADDRESS:-}" ]]; then
    forge_args+=(--sender "$DEPLOYER_ADDRESS" --unlocked)
  fi

  "${forge_args[@]}" "$@"
}

run_deploy_script() {
  local rpc_url="$1"
  local script_path="$2"
  local network_profile="$3"
  local out_dir="$4"
  local remote_out_dir="$5"

  echo "Running deployment script: $script_path" >&2
  echo "  RPC: $rpc_url" >&2
  echo "  Network profile: $network_profile" >&2
  echo "  Out dir: $out_dir" >&2
  echo "  Remote out dir: $remote_out_dir" >&2

  SENDER="$DEPLOYER_ADDRESS" \
  NETWORK_PROFILE="$network_profile" \
  OUT_DIR_OVERRIDE="$out_dir" \
  REMOTE_OUT_DIR="$remote_out_dir" \
  PUBLIC_SEPOLIA_SKIP_STAGE16="true" \
    run_forge_script "$script_path" "$rpc_url"
}

run_protocol_detf_script() {
  local rpc_url="$1"
  local script_path="$2"
  local network_profile="$3"
  local out_dir="$4"
  local remote_out_dir="$5"

  echo "Running Protocol DETF script: $script_path" >&2
  echo "  RPC: $rpc_url" >&2
  echo "  Network profile: $network_profile" >&2
  echo "  Out dir: $out_dir" >&2
  echo "  Remote out dir: $remote_out_dir" >&2

  SENDER="$DEPLOYER_ADDRESS" \
  NETWORK_PROFILE="$network_profile" \
  OUT_DIR_OVERRIDE="$out_dir" \
  REMOTE_OUT_DIR="$remote_out_dir" \
    run_forge_script "$script_path" "$rpc_url"
}

run_bridge_infra_script() {
  local rpc_url="$1"
  local out_dir="$2"

  echo "Running Superchain bridge infra script on $rpc_url" >&2
  echo "  Out dir: $out_dir" >&2

  SENDER="$DEPLOYER_ADDRESS" \
  OUT_DIR_OVERRIDE="$out_dir" \
    run_forge_script "scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol:Script_24_DeploySuperchainBridgeInfra" "$rpc_url"
}

run_bridge_config_script() {
  local rpc_url="$1"
  local out_dir="$2"
  local remote_out_dir="$3"

  echo "Running Protocol DETF bridge config on $rpc_url" >&2
  echo "  Out dir: $out_dir" >&2
  echo "  Remote out dir: $remote_out_dir" >&2

  SENDER="$DEPLOYER_ADDRESS" \
  OUT_DIR_OVERRIDE="$out_dir" \
  REMOTE_OUT_DIR="$remote_out_dir" \
    run_forge_script "scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol:Script_25_ConfigureProtocolDetfBridge" "$rpc_url"
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

run_base_wrapper_creation() {
  SENDER="$DEPLOYER_ADDRESS" \
  PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR="$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  PUBLIC_SEPOLIA_BASE_OUT_DIR="$PUBLIC_SEPOLIA_BASE_OUT_DIR" \
  PUBLIC_SEPOLIA_SHARED_OUT_DIR="$PUBLIC_SEPOLIA_SHARED_OUT_DIR" \
    run_forge_script "scripts/foundry/public_sepolia/base/Script_05_CreateBridgeTokens.s.sol:Script_05_CreateBridgeTokens" "$BASE_SEPOLIA_RPC_URL"
}

run_bridge_execution() {
  SENDER="$DEPLOYER_ADDRESS" \
  PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR="$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  PUBLIC_SEPOLIA_SHARED_OUT_DIR="$PUBLIC_SEPOLIA_SHARED_OUT_DIR" \
    run_forge_script "scripts/foundry/public_sepolia/ethereum/Script_17_BridgeTokensToBase.s.sol:Script_17_BridgeTokensToBase" "$ETHEREUM_SEPOLIA_RPC_URL"
}

checkpoint() {
  local message="$1"

  if [[ "${PUBLIC_SEPOLIA_SKIP_CHECKPOINTS:-0}" == "1" ]]; then
    return
  fi

  if [[ ! -t 0 ]]; then
    echo "$message" >&2
    echo "Non-interactive shell detected. Re-run with PUBLIC_SEPOLIA_SKIP_CHECKPOINTS=1 after manual verification." >&2
    exit 0
  fi

  echo "$message" >&2
  read -r -p "Press Enter after verification to continue..."
}

# === MAIN EXECUTION ===

require_env DEPLOYER_ADDRESS "$DEPLOYER_ADDRESS"

echo "Using deployer sender: $DEPLOYER_ADDRESS" >&2
echo "Ethereum RPC: $ETHEREUM_SEPOLIA_RPC_URL" >&2
echo "Base RPC:     $BASE_SEPOLIA_RPC_URL" >&2

if [[ "$BROADCAST" != "1" ]]; then
  echo "SIMULATE MODE - no transactions will be sent (use --broadcast to send)" >&2
  echo "Full multi-phase simulation is not supported because wrapper and bridge state do not persist across separate script invocations." >&2
  exit 0
fi

cd "$REPO_ROOT"

echo "Starting Ethereum Sepolia deployment..." >&2
echo "This step can run silently for several minutes while forge simulates and broadcasts." >&2

run_deploy_script \
  "$ETHEREUM_SEPOLIA_RPC_URL" \
  "scripts/foundry/public_sepolia/ethereum/Script_DeployAll.s.sol:Script_DeployAll" \
  "ethereum_sepolia" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR"

generate_deployment_summary "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"

echo "Creating Base Sepolia bridge-token wrappers..." >&2
run_base_wrapper_creation

checkpoint "Verify the Base Sepolia wrapper contracts before proceeding to bridge execution."

echo "Bridging required balances to Base Sepolia..." >&2
run_bridge_execution

checkpoint "Verify the Base Sepolia bridged balances before proceeding to Base deployment."

echo "Starting Base Sepolia deployment..." >&2
echo "This step can run silently for several minutes while forge broadcasts." >&2

run_deploy_script \
  "$BASE_SEPOLIA_RPC_URL" \
  "scripts/foundry/public_sepolia/base/Script_DeployAll.s.sol:Script_DeployAll" \
  "base_sepolia" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"

echo "Deploying Superchain bridge infrastructure on Ethereum..." >&2
run_bridge_infra_script \
  "$ETHEREUM_SEPOLIA_RPC_URL" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"

echo "Deploying Superchain bridge infrastructure on Base..." >&2
run_bridge_infra_script \
  "$BASE_SEPOLIA_RPC_URL" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR"

echo "Deploying Protocol DETF on Ethereum..." >&2
run_protocol_detf_script \
  "$ETHEREUM_SEPOLIA_RPC_URL" \
  "scripts/foundry/public_sepolia/ethereum/Script_16_DeployProtocolDETF.s.sol:Script_16_DeployProtocolDETF" \
  "ethereum_sepolia" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR"

echo "Deploying Protocol DETF on Base..." >&2
run_protocol_detf_script \
  "$BASE_SEPOLIA_RPC_URL" \
  "scripts/foundry/public_sepolia/base/Script_16_DeployProtocolDETF.s.sol:Script_16_DeployProtocolDETF" \
  "base_sepolia" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"

echo "Configuring Protocol DETF bridge on Ethereum..." >&2
run_bridge_config_script \
  "$ETHEREUM_SEPOLIA_RPC_URL" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR"

echo "Configuring Protocol DETF bridge on Base..." >&2
run_bridge_config_script \
  "$BASE_SEPOLIA_RPC_URL" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"

generate_deployment_summary "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"
generate_deployment_summary "$PUBLIC_SEPOLIA_BASE_OUT_DIR"

FRONTEND_EXPORT_TOKENLIST_PREFIX="$PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_TOKENLIST_PREFIX" \
FRONTEND_EXPORT_CONTRACTLIST_PREFIX="$PUBLIC_SEPOLIA_FRONTEND_ETHEREUM_CONTRACTLIST_PREFIX" \
python3 scripts/foundry/supersim/export_frontend_artifacts.py \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  "$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR/ethereum" \
  11155111

FRONTEND_EXPORT_TOKENLIST_PREFIX="$PUBLIC_SEPOLIA_FRONTEND_BASE_TOKENLIST_PREFIX" \
FRONTEND_EXPORT_CONTRACTLIST_PREFIX="$PUBLIC_SEPOLIA_FRONTEND_BASE_CONTRACTLIST_PREFIX" \
python3 scripts/foundry/supersim/export_frontend_artifacts.py \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR" \
  "$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR/base" \
  84532

echo "Public Sepolia deployment complete"
echo "Ethereum out: $PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"
echo "Base out:     $PUBLIC_SEPOLIA_BASE_OUT_DIR"
