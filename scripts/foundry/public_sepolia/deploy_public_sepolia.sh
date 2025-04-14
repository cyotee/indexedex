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
#
# What this script does:
#   1. Runs Ethereum Sepolia deployment via Script_DeployAll on Ethereum Sepolia.
#   2. Runs Base Sepolia deployment via Script_DeployAll on Base Sepolia.
#   3. Deploys Superchain bridge infrastructure on both chains.
#   4. Configures the Superchain bridge on both chains.
#   5. Exports frontend address artifacts for both chains.
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

  echo "Running deployment script: $script_path" >&2
  echo "  RPC: $rpc_url" >&2
  echo "  Network profile: $network_profile" >&2
  echo "  Out dir: $out_dir" >&2

  SENDER="$DEPLOYER_ADDRESS" \
  NETWORK_PROFILE="$network_profile" \
  OUT_DIR_OVERRIDE="$out_dir" \
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
  SUPERSIM_ETHEREUM_RPC_URL="$ETHEREUM_SEPOLIA_RPC_URL" \
  SUPERSIM_BASE_RPC_URL="$BASE_SEPOLIA_RPC_URL" \
  SUPERSIM_ETHEREUM_OUT_DIR="$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  SUPERSIM_BASE_OUT_DIR="$PUBLIC_SEPOLIA_BASE_OUT_DIR" \
  SUPERSIM_SHARED_OUT_DIR="$PUBLIC_SEPOLIA_SHARED_OUT_DIR" \
  SUPERSIM_FRONTEND_ARTIFACTS_DIR="$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR" \
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
  SUPERSIM_ETHEREUM_RPC_URL="$ETHEREUM_SEPOLIA_RPC_URL" \
  SUPERSIM_BASE_RPC_URL="$BASE_SEPOLIA_RPC_URL" \
  SUPERSIM_ETHEREUM_OUT_DIR="$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  SUPERSIM_BASE_OUT_DIR="$PUBLIC_SEPOLIA_BASE_OUT_DIR" \
  SUPERSIM_SHARED_OUT_DIR="$PUBLIC_SEPOLIA_SHARED_OUT_DIR" \
  SUPERSIM_FRONTEND_ARTIFACTS_DIR="$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR" \
    run_forge_script "scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol:Script_25_ConfigureProtocolDetfBridge" "$rpc_url"
}

# === MAIN EXECUTION ===

require_env DEPLOYER_ADDRESS "$DEPLOYER_ADDRESS"

echo "Using deployer sender: $DEPLOYER_ADDRESS" >&2
echo "Ethereum RPC: $ETHEREUM_SEPOLIA_RPC_URL" >&2
echo "Base RPC:     $BASE_SEPOLIA_RPC_URL" >&2

if [[ "$BROADCAST" != "1" ]]; then
  echo "SIMULATE MODE - no transactions will be sent (use --broadcast to send)" >&2
fi

cd "$REPO_ROOT"

echo "Starting Ethereum Sepolia deployment..." >&2
echo "This step can run silently for several minutes while forge simulates and broadcasts." >&2

run_deploy_script \
  "$ETHEREUM_SEPOLIA_RPC_URL" \
  "scripts/foundry/public_sepolia/ethereum/Script_DeployAll.s.sol:Script_DeployAll" \
  "ethereum_sepolia" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"

generate_deployment_summary "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"

echo "Starting Base Sepolia deployment..." >&2
echo "This step can run silently for several minutes while forge simulates and broadcasts." >&2

run_deploy_script \
  "$BASE_SEPOLIA_RPC_URL" \
  "scripts/foundry/public_sepolia/base/Script_DeployAll.s.sol:Script_DeployAll" \
  "base_sepolia" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR"

generate_deployment_summary "$PUBLIC_SEPOLIA_BASE_OUT_DIR"

if [[ "$BROADCAST" != "1" ]]; then
  echo "Simulation completed for Ethereum and Base deployment stages." >&2
  echo "Skipping bridge deployment, bridge config, and frontend export in simulate mode." >&2
  echo "Run again with --broadcast for a real end-to-end deployment and UI artifact export." >&2
  exit 0
fi

echo "Deploying Superchain bridge infrastructure on Ethereum..." >&2

run_bridge_infra_script \
  "$ETHEREUM_SEPOLIA_RPC_URL" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"

echo "Deploying Superchain bridge infrastructure on Base..." >&2

run_bridge_infra_script \
  "$BASE_SEPOLIA_RPC_URL" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR"

echo "Configuring Superchain bridge on Ethereum..." >&2

run_bridge_config_script \
  "$ETHEREUM_SEPOLIA_RPC_URL" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR"

echo "Configuring Superchain bridge on Base..." >&2

run_bridge_config_script \
  "$BASE_SEPOLIA_RPC_URL" \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR" \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"

python3 scripts/foundry/supersim/export_frontend_artifacts.py \
  "$PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR" \
  "$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR/ethereum" \
  11155111

python3 scripts/foundry/supersim/export_frontend_artifacts.py \
  "$PUBLIC_SEPOLIA_BASE_OUT_DIR" \
  "$PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR/base" \
  84532

echo "Public Sepolia deployment complete"
echo "Ethereum out: $PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR"
echo "Base out:     $PUBLIC_SEPOLIA_BASE_OUT_DIR"
