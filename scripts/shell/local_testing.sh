#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

resolve_foundry_rpc_alias() {
  local alias_name="$1"
  local template
  local resolved

  template="$(cd "$REPO_ROOT" && forge config --json | jq -r --arg alias_name "$alias_name" '.rpc_endpoints[$alias_name] // empty')"
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

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
ANVIL_HOST="${ANVIL_HOST:-127.0.0.1}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
ANVIL_CHAIN_ID="${ANVIL_CHAIN_ID:-11155111}"
FOUNDRY_FORK_RPC_ALIAS="${FOUNDRY_FORK_RPC_ALIAS-ethereum_sepolia_alchemy}"
ANVIL_FORK_URL="${ANVIL_FORK_URL:-}"
if [[ -z "$ANVIL_FORK_URL" && -n "$FOUNDRY_FORK_RPC_ALIAS" ]]; then
  ANVIL_FORK_URL="$(resolve_foundry_rpc_alias "$FOUNDRY_FORK_RPC_ALIAS")"
fi
ANVIL_FORK_BLOCK_NUMBER="${ANVIL_FORK_BLOCK_NUMBER:-}"
ANVIL_LOG_DIR="${ANVIL_LOG_DIR:-$REPO_ROOT/deployments/local_testing/runtime}"
OUT_DIR_OVERRIDE="${OUT_DIR_OVERRIDE:-deployments/local_testing/anvil_single}"
NETWORK_PROFILE="${NETWORK_PROFILE:-local_testing}"

DEV_ADDRESS="${DEV_ADDRESS:-}"
SENDER="${SENDER:-$DEV_ADDRESS}"
LOCAL_TESTING_DEPLOYER_ADDRESS="${LOCAL_TESTING_DEPLOYER_ADDRESS:-}"
DEPLOYER_ADDRESS="${LOCAL_TESTING_DEPLOYER_ADDRESS:-$SENDER}"
LOCAL_TESTING_OWNER="${LOCAL_TESTING_OWNER:-}"
OWNER="${LOCAL_TESTING_OWNER:-$DEPLOYER_ADDRESS}"

BROADCAST_FLAG="--broadcast"
RESTART_ANVIL=0
KILL_ANVIL=0
FORGE_VERBOSITY=""
COMMAND="foundation"

usage() {
  cat <<EOF
Usage:
  scripts/shell/local_testing.sh [command] [options]

Commands:
  foundation      Run stages 01 through 03 for the local-testing foundation
  packages        Run stage 05 foundation packages
  assets          Run stage 06 foundation assets
  scenario1       Run the Scenario 1 overlay on top of the current foundation
  scenario2       Run the Scenario 2 overlay on top of Scenario 1 outputs
  scenario3       Run the Scenario 3 overlay for Single Vault DETF bring-up
  stage01         Run only Script_01_DeployCraneFoundation
  stage02         Run only Script_02_DeployIndexedexCore
  stage03         Run only Script_03_DeployBaseProtocols
  stage05         Run only Script_05_DeployFoundationPackages
  stage06         Run only Script_06_DeployFoundationAssets
  stage10         Run only Script_10_DeployScenario1Overlay
  stage11         Run only Script_11_DeployScenario2Overlay
  stage12         Run only Script_12_DeployScenario3Overlay

Options:
  --dry-run         Simulate without broadcasting
  --restart-anvil   Restart the local Anvil instance before running stages
  --kill-anvil      Kill the local Anvil instance and exit
  -v|-vv|-vvv|-vvvv|-vvvvv
                    Pass Foundry verbosity through to forge script
  --help, -h        Show this help

Environment:
  DEV_ADDRESS or SENDER   Broadcast sender for forge script --unlocked --sender
  LOCAL_TESTING_DEPLOYER_ADDRESS
                        Optional local deployer override; defaults to SENDER
  LOCAL_TESTING_OWNER     Optional local owner override; defaults to DEPLOYER_ADDRESS
  RPC_URL                 Defaults to http://127.0.0.1:8545
  ANVIL_CHAIN_ID          Defaults to 11155111 (Sepolia). Set to 31337 for pure local.
  FOUNDRY_FORK_RPC_ALIAS  Foundry rpc_endpoints alias used to resolve the fork URL when
                          ANVIL_FORK_URL is unset. Defaults to ethereum_sepolia_alchemy.
                          Set to empty string to disable forking.
  ANVIL_FORK_URL          Explicit upstream RPC to fork from. Overrides the alias lookup.
  ANVIL_FORK_BLOCK_NUMBER Optional fork block number when forking is active
  OUT_DIR_OVERRIDE        Defaults to deployments/local_testing/anvil_single
  SKIP_TOKENLIST_BUILD    Set to 1 to skip the post-deploy Token List aggregator
EOF
}

log_info() {
  printf '[INFO] %s\n' "$1"
}

log_error() {
  printf '[ERROR] %s\n' "$1" >&2
}

port_pid() {
  lsof -tiTCP:"$ANVIL_PORT" -sTCP:LISTEN 2>/dev/null || true
}

kill_anvil() {
  local pid
  pid="$(port_pid)"
  if [[ -n "$pid" ]]; then
    log_info "Killing Anvil on port $ANVIL_PORT (pid $pid)"
    kill "$pid"
  else
    log_info "No Anvil process found on port $ANVIL_PORT"
  fi
}

wait_for_rpc() {
  local attempts=0
  until cast block-number --rpc-url "$RPC_URL" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ "$attempts" -ge 30 ]]; then
      log_error "Timed out waiting for Anvil RPC at $RPC_URL"
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

  local anvil_cmd=(anvil --host "$ANVIL_HOST" --port "$ANVIL_PORT" --chain-id "$ANVIL_CHAIN_ID")
  if [[ -n "$ANVIL_FORK_URL" ]]; then
    anvil_cmd+=(--fork-url "$ANVIL_FORK_URL")
    if [[ -n "$ANVIL_FORK_BLOCK_NUMBER" ]]; then
      anvil_cmd+=(--fork-block-number "$ANVIL_FORK_BLOCK_NUMBER")
    fi
  fi

  if [[ -n "$ANVIL_FORK_URL" ]]; then
    log_info "Starting Anvil at $RPC_URL (forking $FOUNDRY_FORK_RPC_ALIAS, chain id $ANVIL_CHAIN_ID)"
  else
    log_info "Starting Anvil at $RPC_URL (no fork, chain id $ANVIL_CHAIN_ID)"
  fi
  nohup "${anvil_cmd[@]}" >"$ANVIL_LOG_DIR/anvil.log" 2>&1 &
  wait_for_rpc
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
    cmd+=("$BROADCAST_FLAG" --slow)
  fi

  (
    cd "$REPO_ROOT"
    OUT_DIR_OVERRIDE="$OUT_DIR_OVERRIDE" \
    NETWORK_PROFILE="$NETWORK_PROFILE" \
    SENDER="$SENDER" \
    DEPLOYER_ADDRESS="$DEPLOYER_ADDRESS" \
    OWNER="$OWNER" \
    "${cmd[@]}"
  )
}

run_aggregator() {
  if [[ "${SKIP_TOKENLIST_BUILD:-0}" == "1" ]]; then
    log_info "Skipping tokenlist build (SKIP_TOKENLIST_BUILD=1)"
    return 0
  fi
  if [[ ! -d "$REPO_ROOT/scripts/node/node_modules" ]]; then
    log_info "scripts/node/node_modules missing — run 'cd scripts/node && npm install' once before deploys"
    return 0
  fi
  if [[ ! -d "$REPO_ROOT/deployments/local_testing/anvil_single/fragments" ]]; then
    log_info "No fragments directory yet — skipping tokenlist build"
    return 0
  fi
  log_info "Building token lists from fragments"
  (
    cd "$REPO_ROOT/scripts/node" \
      && INDEXEDEX_REPO_ROOT="$REPO_ROOT" \
         npm run --silent build-tokenlists -- --config "$REPO_ROOT/tokenlists.config.ts"
  )
}

# Merge every per-stage JSON the Solidity scripts wrote into a single chain-keyed
# platform.json the UI can read for facade / router / weth / permit2 / vault
# addresses. Latest values win on key collisions.
synthesize_platform() {
  if ! command -v jq >/dev/null 2>&1; then
    log_info "jq missing — skipping chain platform synthesis"
    return 0
  fi
  local in_dir="$REPO_ROOT/deployments/local_testing/anvil_single"
  local stage_files=("$in_dir"/[0-9]*.json)
  if [[ ! -e "${stage_files[0]}" ]]; then
    log_info "No stage JSONs yet — skipping platform synthesis"
    return 0
  fi
  local out="$REPO_ROOT/frontend/app/addresses/chain/$ANVIL_CHAIN_ID/platform.json"
  mkdir -p "$(dirname "$out")"
  log_info "Synthesizing chain platform -> $(realpath --relative-to="$REPO_ROOT" "$out" 2>/dev/null || echo "$out")"
  jq -s --argjson cid "$ANVIL_CHAIN_ID" \
    'reduce .[] as $f ({}; . + $f) | . + { chainId: $cid }' \
    "${stage_files[@]}" > "$out"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    foundation|packages|assets|scenario1|scenario2|scenario3|stage01|stage02|stage03|stage05|stage06|stage10|stage11|stage12)
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

if [[ -z "$SENDER" ]]; then
  log_error "Set DEV_ADDRESS or SENDER before running local testing scripts"
  exit 1
fi

if [[ "$RESTART_ANVIL" -eq 1 ]]; then
  kill_anvil
fi

start_anvil

case "$COMMAND" in
  foundation)
    run_stage \
      "Stage 01: Deploy Crane Foundation" \
      "scripts/foundry/local_testing/anvil_single/Script_01_DeployCraneFoundation.s.sol"
    run_stage \
      "Stage 02: Deploy Indexedex Core" \
      "scripts/foundry/local_testing/anvil_single/Script_02_DeployIndexedexCore.s.sol"
    run_stage \
      "Stage 03: Deploy Base Protocols" \
      "scripts/foundry/local_testing/anvil_single/Script_03_DeployBaseProtocols.s.sol"
    ;;
  stage01)
    run_stage \
      "Stage 01: Deploy Crane Foundation" \
      "scripts/foundry/local_testing/anvil_single/Script_01_DeployCraneFoundation.s.sol"
    ;;
  stage02)
    run_stage \
      "Stage 02: Deploy Indexedex Core" \
      "scripts/foundry/local_testing/anvil_single/Script_02_DeployIndexedexCore.s.sol"
    ;;
  stage03)
    run_stage \
      "Stage 03: Deploy Base Protocols" \
      "scripts/foundry/local_testing/anvil_single/Script_03_DeployBaseProtocols.s.sol"
    ;;
  packages|stage05)
    run_stage \
      "Stage 05: Deploy Foundation Packages" \
      "scripts/foundry/local_testing/anvil_single/Script_05_DeployFoundationPackages.s.sol"
    ;;
  assets|stage06)
    run_stage \
      "Stage 06: Deploy Foundation Assets" \
      "scripts/foundry/local_testing/anvil_single/Script_06_DeployFoundationAssets.s.sol"
    ;;
  scenario1)
    run_stage \
      "Stage 05: Deploy Foundation Packages" \
      "scripts/foundry/local_testing/anvil_single/Script_05_DeployFoundationPackages.s.sol"
    run_stage \
      "Stage 06: Deploy Foundation Assets" \
      "scripts/foundry/local_testing/anvil_single/Script_06_DeployFoundationAssets.s.sol"
    run_stage \
      "Stage 10: Deploy Scenario 1 Overlay" \
      "scripts/foundry/local_testing/anvil_single/Script_10_DeployScenario1Overlay.s.sol"
    ;;
  scenario2)
    run_stage \
      "Stage 05: Deploy Foundation Packages" \
      "scripts/foundry/local_testing/anvil_single/Script_05_DeployFoundationPackages.s.sol"
    run_stage \
      "Stage 06: Deploy Foundation Assets" \
      "scripts/foundry/local_testing/anvil_single/Script_06_DeployFoundationAssets.s.sol"
    run_stage \
      "Stage 10: Deploy Scenario 1 Overlay" \
      "scripts/foundry/local_testing/anvil_single/Script_10_DeployScenario1Overlay.s.sol"
    run_stage \
      "Stage 11: Deploy Scenario 2 Overlay" \
      "scripts/foundry/local_testing/anvil_single/Script_11_DeployScenario2Overlay.s.sol"
    ;;
  scenario3)
    run_stage \
      "Stage 05: Deploy Foundation Packages" \
      "scripts/foundry/local_testing/anvil_single/Script_05_DeployFoundationPackages.s.sol"
    run_stage \
      "Stage 06: Deploy Foundation Assets" \
      "scripts/foundry/local_testing/anvil_single/Script_06_DeployFoundationAssets.s.sol"
    run_stage \
      "Stage 12: Deploy Scenario 3 Overlay" \
      "scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3Overlay.s.sol"
    ;;
  stage10)
    run_stage \
      "Stage 10: Deploy Scenario 1 Overlay" \
      "scripts/foundry/local_testing/anvil_single/Script_10_DeployScenario1Overlay.s.sol"
    ;;
  stage11)
    run_stage \
      "Stage 11: Deploy Scenario 2 Overlay" \
      "scripts/foundry/local_testing/anvil_single/Script_11_DeployScenario2Overlay.s.sol"
    ;;
  stage12)
    run_stage \
      "Stage 12: Deploy Scenario 3 Overlay" \
      "scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3Overlay.s.sol"
    ;;
esac

run_aggregator
synthesize_platform

log_info "Local testing command complete"