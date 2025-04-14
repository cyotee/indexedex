#!/usr/bin/env bash
# =============================================================================
# IndexedEx Full Deployment Script for Anvil Base Mainnet Fork
# =============================================================================
#
# PREREQUISITES:
# 1. Start Anvil with Base mainnet fork in a separate terminal:
#
#    anvil --fork-url base_mainnet_alchemy --chain-id 31337 --fork-block-number 41165800
#
#    Or with explicit Alchemy URL:
#
#    anvil --fork-url https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY --chain-id 31337 --fork-block-number 41165800
#
# 1.a. Killing a running Anvil instance (macOS/Linux):
#
#    # Kill the process listening on the configured RPC port (default: 8545)
#    lsof -tiTCP:8545 -sTCP:LISTEN | xargs -r kill -9
#
#    # If you have multiple Anvil instances and want to kill all of them:
#    pkill -f "^anvil( |$)" || true
#
# 2. Ensure the RPC is accessible at http://127.0.0.1:8545
#
# USAGE:
#    ./scripts/foundry/anvil_base_main/deploy_all.sh
#
# OPTIONS:
#    --resume        Resume from failed transactions (useful after rate limiting)
#    --dry-run       Simulate without broadcasting
#    --restart-anvil Kill any running Anvil on the configured port and start a fresh fork.
#    --kill-anvil    Kill any running Anvil on the configured port (do not restart).
#    --force         Re-run stages even if their output JSON already exists.
#
# REQUIRED ENV:
#    DEV_ADDRESS       The address used for `forge script --sender` (typically Anvil account(0)).
#                     This script will also export OWNER=DEV_ADDRESS for deployment scripts.
#    DEPLOYER_ADDRESS  Destination address for the final sweep of ETH + token balances.
#
# NOTES:
# - This script always runs Foundry scripts with `--unlocked` and `--sender "$SENDER"`.
# - If Anvil is not running, this script will attempt to start it via `nohup`.
#
# =============================================================================

set -e  # Exit on first error

# Configuration
RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
DEV_ADDRESS="${DEV_ADDRESS:-}"
SENDER="${SENDER:-$DEV_ADDRESS}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEPLOYMENTS_DIR="${DEPLOYMENTS_DIR:-deployments/anvil_base_main}"
FRONTEND_ARTIFACTS_DIR="${FRONTEND_ARTIFACTS_DIR:-frontend/app/addresses/anvil_base_main}"
FRONTEND_CHAIN_ID="${FRONTEND_CHAIN_ID:-31337}"
export OUT_DIR_OVERRIDE="${OUT_DIR_OVERRIDE:-$DEPLOYMENTS_DIR}"

# Anvil defaults (used if we need to launch it)
ANVIL_FORK_URL="${ANVIL_FORK_URL:-base_mainnet_infura}"
ANVIL_FORK_BLOCK_NUMBER="${ANVIL_FORK_BLOCK_NUMBER:-41165800}"
ANVIL_CHAIN_ID="${ANVIL_CHAIN_ID:-31337}"
ANVIL_HOST="${ANVIL_HOST:-127.0.0.1}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
# Fork throttling (helps avoid upstream 429s on public RPCs)
ANVIL_COMPUTE_UNITS_PER_SECOND="${ANVIL_COMPUTE_UNITS_PER_SECOND:-50}"
ANVIL_FORK_RETRY_BACKOFF="${ANVIL_FORK_RETRY_BACKOFF:-1000}"

# Parse arguments
RESUME_FLAG=""
BROADCAST_FLAG="--broadcast"
RESTART_ANVIL=0
KILL_ANVIL=0
FORCE=0
SHOW_HELP=0
for arg in "$@"; do
    case $arg in
        --help|-h)
            SHOW_HELP=1
            ;;
        --resume)
            RESUME_FLAG="--resume"
            ;;
        --dry-run)
            BROADCAST_FLAG=""
            ;;
        --restart-anvil)
            RESTART_ANVIL=1
            ;;
        --kill-anvil)
            KILL_ANVIL=1
            ;;
        --force)
            FORCE=1
            ;;
    esac
done

usage() {
        cat <<EOF
Usage:
    scripts/foundry/anvil_base_main/deploy_all.sh [options]

Options:
    --resume         Resume from prior broadcast artifacts when available
    --dry-run        Simulate without broadcasting
    --restart-anvil  Stop any anvil on the configured port and start a fresh fork
    --kill-anvil     Stop any anvil on the configured port (do not restart)
    --force          Re-run stages even if their output JSON already exists
    --help, -h       Show this help

Required env:
    DEV_ADDRESS       Address used as --sender (typically Anvil account(0))
    DEPLOYER_ADDRESS  Destination address for the final sweep of ETH + token balances

Optional env:
    RPC_URL, ANVIL_FORK_URL, ANVIL_FORK_BLOCK_NUMBER, ANVIL_CHAIN_ID, ANVIL_HOST, ANVIL_PORT
EOF
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${YELLOW}=============================================================================${NC}"
    echo -e "${YELLOW} $1${NC}"
    echo -e "${YELLOW}=============================================================================${NC}"
}

sweep_anvil_wallets_to_dev0() {
    # This is specifically to consolidate ETH from Anvil's default wallets into DEV0
    # without any local keystore/private-key prompts.
    #
    # We call a Foundry script repeatedly using `--unlocked --sender <DEVx>`.
    # Each sender transfers (balance - 0.1 ETH) to DEV0.

    # Only meaningful when broadcasting.
    if [[ -z "$BROADCAST_FLAG" ]]; then
        log_info "Dry-run mode: skipping DEV wallet sweep"
        return 0
    fi

    local dev0_address="$DEV_ADDRESS"

    # Default Anvil mnemonic accounts 1..9
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

    log_header "Preflight: Sweep DEV1-DEV9 ETH to DEV0"
    log_info "Sweeping into DEV0: $dev0_address"

    for sender in "${senders[@]}"; do
        log_info "Sweeping from $sender -> $dev0_address (leaving 0.1 ETH)"
        DEV0_ADDRESS="$dev0_address" forge script "$SCRIPT_DIR/Script_00_SweepEthToDev0.s.sol" \
            --rpc-url "$RPC_URL" \
            $BROADCAST_FLAG \
            --unlocked \
            --sender "$sender" || return 1
    done

    log_success "DEV wallet sweep complete"
}

sweep_anvil_wallets_to_deployer() {
    # Final sweep: consolidate ETH + ERC20 balances into DEPLOYER_ADDRESS.
    # Runs last as a distinct phase so deployment stages are unchanged.

    # Only meaningful when broadcasting.
    if [[ -z "$BROADCAST_FLAG" ]]; then
        log_info "Dry-run mode: skipping deployer sweep"
        return 0
    fi

    if [[ -z "$DEPLOYER_ADDRESS" ]]; then
        log_error "DEPLOYER_ADDRESS is not set"
        echo ""
        echo "Set DEPLOYER_ADDRESS to the address that should receive all ETH + token balances."
        echo "Example:"
        echo "  export DEPLOYER_ADDRESS=0xYourDeployerAddress"
        echo ""
        exit 1
    fi

    local deployer_address="$DEPLOYER_ADDRESS"

    # Default Anvil mnemonic accounts 0..9
    local senders=(
        "$DEV_ADDRESS"
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

    log_header "Final Sweep: Transfer ETH + tokens to DEPLOYER_ADDRESS"
    log_info "Sweeping into DEPLOYER_ADDRESS: $deployer_address"

    for sender in "${senders[@]}"; do
        if [[ -z "$sender" ]]; then
            continue
        fi
        log_info "Sweeping from $sender -> $deployer_address"
        DEPLOYER_ADDRESS="$deployer_address" forge script "$SCRIPT_DIR/Script_99_SweepBalancesToDeployer.s.sol" \
            --rpc-url "$RPC_URL" \
            $BROADCAST_FLAG \
            --skip-simulation \
            --unlocked \
            --sender "$sender" || return 1
    done

    log_success "Deployer sweep complete"
}

require_dev_address() {
    if [[ -z "$DEV_ADDRESS" ]]; then
        log_error "DEV_ADDRESS is not set"
        echo ""
        echo "Set DEV_ADDRESS to the account you want to use as the transaction sender."
        echo "Example (Anvil account(0)):"
        echo "  export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
        echo ""
        echo "This script runs forge with: --unlocked --sender \"$DEV_ADDRESS\""
        echo ""
        exit 1
    fi

    if [[ -z "$SENDER" ]]; then
        log_error "SENDER could not be derived (SENDER and DEV_ADDRESS are empty)"
        exit 1
    fi

    # Keep deployment scripts consistent: default OWNER to the same dev address.
    export OWNER="${OWNER:-$DEV_ADDRESS}"
}

# Sync generated deployment artifacts into the frontend address JSONs/tokenlists
sync_frontend_artifacts() {
    local deployments_dir="$DEPLOYMENTS_DIR"
    local frontend_dir="$FRONTEND_ARTIFACTS_DIR"
    local frontend_chain_id="$FRONTEND_CHAIN_ID"

    mkdir -p "$frontend_dir"

    # Preferred: segmented tokenlists generated by Stage 14.
    # Copy all correlated tokenlists into the frontend addresses folder.
    local copied_any=0
    local tokenlists

    # Enable nullglob so the glob expands to nothing when there are no matches.
    shopt -s nullglob
    tokenlists=("$deployments_dir"/anvil_base_main-*.tokenlist.json)
    shopt -u nullglob

    if [[ ${#tokenlists[@]} -gt 0 ]]; then
        for f in "${tokenlists[@]}"; do
            cp "$f" "$frontend_dir/$(basename "$f")"
            copied_any=1
        done
        log_success "Synced ${#tokenlists[@]} tokenlists to frontend: $frontend_dir"
    fi

    # Fallback: older Stage 12 output used before segmented tokenlists existed.
    local src_balancer_tokenlist="$deployments_dir/12_balancer_all_pools.tokenlist.json"
    local dst_balancer_tokenlist="$frontend_dir/anvil_base_main-balancerv3-pools.tokenlist.json"
    # IMPORTANT: Do not overwrite the segmented/combined Stage 14 output if it exists.
    # The Stage 12 tokenlist can be missing newer pools (e.g., WETH/TTC const-prod pools).
    local segmented_balancer_tokenlist="$deployments_dir/anvil_base_main-balancerv3-pools.tokenlist.json"
    if [[ -f "$src_balancer_tokenlist" && ! -f "$segmented_balancer_tokenlist" ]]; then
        cp "$src_balancer_tokenlist" "$dst_balancer_tokenlist"
        log_success "Synced legacy Balancer pool tokenlist to frontend: $dst_balancer_tokenlist"
        copied_any=1
    fi

    if [[ "$copied_any" -ne 1 ]]; then
        log_error "No tokenlists found to sync."
        log_info "Expected Stage 14 outputs at: $deployments_dir/anvil_base_main-*.tokenlist.json"
        log_info "Or fallback Balancer tokenlist at: $src_balancer_tokenlist"
    fi

    # Sync platform address map into the frontend.
    # Minimal approach: merge all deployment stage JSONs (plus deployment_summary.json) into
    # frontend/app/addresses/anvil_base_main/base_deployments.json.
    python3 - "$deployments_dir" "$frontend_dir" "$frontend_chain_id" <<'PY'
import glob
import json
import os
import sys
import time

deployments_dir = sys.argv[1]
frontend_dir = sys.argv[2]
frontend_chain_id = int(sys.argv[3])
out_path = os.path.join(frontend_dir, "base_deployments.json")

base = {}
if os.path.exists(out_path):
    try:
        with open(out_path, "r") as f:
            loaded = json.load(f)
            if isinstance(loaded, dict):
                base = loaded
    except Exception:
        # If the existing file is malformed, just regenerate from deployments.
        base = {}

paths = [
    p
    for p in glob.glob(os.path.join(deployments_dir, "*.json"))
    if not p.endswith(".tokenlist.json")
]

def sort_key(p: str) -> tuple:
    name = os.path.basename(p)
    # Ensure numbered stages come first, then summary-ish files.
    if name[:2].isdigit() and name[2] in {"_", "-"}:
        return (0, name)
    if name == "deployment_summary.json":
        return (2, name)
    return (1, name)

for p in sorted(paths, key=sort_key):
    try:
        with open(p, "r") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            continue
        for k, v in data.items():
            base[k] = v
    except Exception:
        continue

base["chainId"] = frontend_chain_id
base["exportedAt"] = str(int(time.time()))

# Back-compat / UI-friendly aliases.
if "create3Factory" in base and "craneFactory" not in base:
    base["craneFactory"] = base["create3Factory"]
if "diamondPackageFactory" in base and "craneDiamondFactory" not in base:
    base["craneDiamondFactory"] = base["diamondPackageFactory"]

# Historical naming in stage outputs may differ from the UI contract.
# Provide conservative aliases so the frontend can resolve addresses without
# changing the deploy scripts.
if "uniswapV2Pkg" in base and "uniswapV2StandardStrategyVaultPkg" not in base:
    base["uniswapV2StandardStrategyVaultPkg"] = base["uniswapV2Pkg"]

# Canonical Balancer V3 Router on Base mainnet.
# On Anvil Base fork (chainId 31337), this key always points to the Base router.
base["balancerV3Router"] = "0x3f170631ed9821Ca51A59D996aB095162438DC10"

# `balancerV3StandardExchangeRouter` must be exported explicitly by deployment stages.
# Do NOT alias it from `balancerV3Router` (they intentionally represent different routers).

# If batch router isn't deployed in this environment, leave it unset.

os.makedirs(frontend_dir, exist_ok=True)
with open(out_path, "w") as f:
    json.dump(base, f, indent=2, sort_keys=False)
    f.write("\n")

print(out_path)
PY
    log_success "Synced platform addresses to frontend: $frontend_dir/base_deployments.json"
}

verify_frontend_router_keys() {
    local frontend_file="$FRONTEND_ARTIFACTS_DIR/base_deployments.json"
    local expected_balancer_v3_router="0x3f170631ed9821Ca51A59D996aB095162438DC10"

    if [[ ! -f "$frontend_file" ]]; then
        log_error "Missing frontend deployment file: $frontend_file"
        exit 1
    fi

    local standard_router
    local balancer_router
    local standard_router_lc
    local balancer_router_lc
    local expected_balancer_v3_router_lc

    standard_router="$(json_get_address "$frontend_file" "balancerV3StandardExchangeRouter" || true)"
    balancer_router="$(json_get_address "$frontend_file" "balancerV3Router" || true)"
    standard_router_lc="$(printf '%s' "$standard_router" | tr '[:upper:]' '[:lower:]')"
    balancer_router_lc="$(printf '%s' "$balancer_router" | tr '[:upper:]' '[:lower:]')"
    expected_balancer_v3_router_lc="$(printf '%s' "$expected_balancer_v3_router" | tr '[:upper:]' '[:lower:]')"

    if [[ -z "$standard_router" ]]; then
        log_error "Missing key 'balancerV3StandardExchangeRouter' in $frontend_file"
        exit 1
    fi

    if [[ -z "$balancer_router" ]]; then
        log_error "Missing key 'balancerV3Router' in $frontend_file"
        exit 1
    fi

    if [[ "$standard_router_lc" == "$balancer_router_lc" ]]; then
        log_error "Router key collision: balancerV3StandardExchangeRouter and balancerV3Router are identical ($standard_router)"
        exit 1
    fi

    if [[ "$balancer_router_lc" != "$expected_balancer_v3_router_lc" ]]; then
        log_error "balancerV3Router mismatch. Expected $expected_balancer_v3_router, got $balancer_router"
        exit 1
    fi

    if ! has_code "$standard_router"; then
        log_error "No bytecode at balancerV3StandardExchangeRouter: $standard_router"
        exit 1
    fi

    if ! has_code "$balancer_router"; then
        log_error "No bytecode at balancerV3Router: $balancer_router"
        exit 1
    fi

    log_success "Verified router keys: balancerV3StandardExchangeRouter=$standard_router, balancerV3Router=$balancer_router"
}

# Check if Anvil is running
check_anvil() {
    log_info "Checking if Anvil is running at $RPC_URL..."
    if ! curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "$RPC_URL" > /dev/null 2>&1; then
        log_error "Anvil is not running at $RPC_URL"
        echo ""
        echo "Please start Anvil first:"
        echo "  anvil --fork-url base_mainnet_infura --chain-id 31337"
        echo ""
        exit 1
    fi
    log_success "Anvil is running"
}

clean_deployments_artifacts() {
    local deployments_dir="$DEPLOYMENTS_DIR"
    mkdir -p "$deployments_dir"

    log_info "Cleaning deployment artifacts in $deployments_dir"
    rm -f "$deployments_dir"/*.json 2>/dev/null || true
    rm -f "$deployments_dir"/*.tokenlist.json 2>/dev/null || true
}

json_get_address() {
    local file="$1"
    local key="$2"

    python3 - "$file" "$key" <<'PY'
import json
import sys

path = sys.argv[1]
key = sys.argv[2]

with open(path, 'r') as f:
    data = json.load(f)

val = data.get(key, "")
if isinstance(val, str):
    print(val)
else:
    print("")
PY
}

has_code() {
    local addr="$1"
    if [[ -z "$addr" ]]; then
        return 1
    fi

    local code
    code="$(cast code --rpc-url "$RPC_URL" "$addr" 2>/dev/null | tr -d '\n' || true)"
    [[ -n "$code" && "$code" != "0x" ]]
}

clear_dev_account_bytecode() {
    # When forking L2s like Base mainnet, some default Anvil dev accounts may have
    # bytecode at their addresses (e.g. EIP-7702 delegation designators with the
    # 0xef01 prefix). This bytecode prevents wallets like MetaMask from sending
    # transactions from these accounts since they appear to be contracts.
    #
    # This step uses anvil_setCode to reset each dev account to an empty EOA.

    local accounts=(
        "$DEV_ADDRESS"
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

    local cleared=0
    for addr in "${accounts[@]}"; do
        if [[ -z "$addr" ]]; then
            continue
        fi
        if has_code "$addr"; then
            cast rpc anvil_setCode "$addr" "0x" --rpc-url "$RPC_URL" > /dev/null 2>&1
            cleared=$((cleared + 1))
        fi
    done

    if [[ $cleared -gt 0 ]]; then
        log_success "Cleared bytecode from $cleared dev account(s) (EIP-7702 delegation cleanup)"
    else
        log_info "Dev accounts are clean EOAs (no bytecode to clear)"
    fi
}

ensure_deployments_match_chain() {
    # If deployment artifacts exist but the chain was restarted (fresh anvil),
    # those addresses will point at EOAs (no code) and later stages will fail.
    local f="$DEPLOYMENTS_DIR/01_factories.json"
    if [[ ! -f "$f" ]]; then
        return 0
    fi

    local create3
    create3="$(json_get_address "$f" "create3Factory" || true)"
    if ! has_code "$create3"; then
        log_info "Detected stale deployment artifacts (no code at create3Factory: $create3); cleaning and re-running stages"
        clean_deployments_artifacts
    fi
}

start_anvil_nohup() {
    local deployments_dir="$DEPLOYMENTS_DIR"
    mkdir -p "$deployments_dir"

    local log_file="$deployments_dir/anvil.log"
    local pid_file="$deployments_dir/anvil.pid"

    log_info "Starting Anvil via nohup (log: $log_file)"
    nohup anvil \
        --fork-url "$ANVIL_FORK_URL" \
        --chain-id "$ANVIL_CHAIN_ID" \
        --fork-block-number "$ANVIL_FORK_BLOCK_NUMBER" \
        --compute-units-per-second "$ANVIL_COMPUTE_UNITS_PER_SECOND" \
        --fork-retry-backoff "$ANVIL_FORK_RETRY_BACKOFF" \
        --host "$ANVIL_HOST" \
        --port "$ANVIL_PORT" \
        > "$log_file" 2>&1 &
    echo $! > "$pid_file"

    # Wait up to ~10s for RPC to respond.
    for _ in {1..20}; do
        if curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            "$RPC_URL" > /dev/null 2>&1; then
            log_success "Anvil started (pid $(cat "$pid_file"))"
            return 0
        fi
        sleep 0.5
    done

    log_error "Anvil did not start in time"
    log_info "Check log: $log_file"
    return 1
}

ensure_anvil() {
    if curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "$RPC_URL" > /dev/null 2>&1; then
        log_success "Anvil is running"
        return 0
    fi

    log_info "Anvil not detected at $RPC_URL"

    # If we have to start Anvil, any existing deployment artifacts are guaranteed stale.
    clean_deployments_artifacts
    start_anvil_nohup
}

is_pid_anvil() {
    local pid="$1"
    if [[ -z "$pid" ]]; then
        return 1
    fi

    # macOS: `ps -p <pid> -o comm=` prints just the executable name.
    local comm
    comm="$(ps -p "$pid" -o comm= 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$comm" == *"anvil"* ]]; then
        return 0
    fi

    return 1
}

stop_anvil() {
    local deployments_dir="$DEPLOYMENTS_DIR"
    local pid_file="$deployments_dir/anvil.pid"

    mkdir -p "$deployments_dir"

    local pid_from_file=""
    if [[ -f "$pid_file" ]]; then
        pid_from_file="$(cat "$pid_file" 2>/dev/null || true)"
    fi

    # First preference: pidfile
    if [[ -n "$pid_from_file" ]] && kill -0 "$pid_from_file" 2>/dev/null; then
        if ! is_pid_anvil "$pid_from_file"; then
            log_error "Refusing to kill PID $pid_from_file from $pid_file (not anvil)"
            log_info "Delete $pid_file manually if it is stale, or free port $ANVIL_PORT."
            exit 1
        fi

        log_info "Stopping Anvil (pid $pid_from_file)"
        kill "$pid_from_file" 2>/dev/null || true

        for _ in {1..20}; do
            if ! kill -0 "$pid_from_file" 2>/dev/null; then
                rm -f "$pid_file"
                log_success "Anvil stopped"
                return 0
            fi
            sleep 0.25
        done

        log_info "Anvil still running; forcing kill -9 (pid $pid_from_file)"
        kill -9 "$pid_from_file" 2>/dev/null || true
        rm -f "$pid_file"
        return 0
    fi

    # Fallback: anything listening on the configured port (only if it's anvil)
    local pids
    pids="$(lsof -tiTCP:"$ANVIL_PORT" -sTCP:LISTEN 2>/dev/null || true)"
    if [[ -n "$pids" ]]; then
        for pid in $pids; do
            if ! is_pid_anvil "$pid"; then
                log_error "Port $ANVIL_PORT is in use by PID $pid (not anvil); refusing to kill."
                log_info "Stop that process or change ANVIL_PORT/RPC_URL."
                exit 1
            fi
        done

        log_info "Stopping Anvil on port $ANVIL_PORT (pids: $pids)"
        kill $pids 2>/dev/null || true
        sleep 0.5
        return 0
    fi

    log_info "No running Anvil detected to stop"
}

# Run a deployment script
run_script() {
    local script_name=$1
    local description=$2

    # `forge script --resume` errors on fresh runs when there is no prior run artifact.
    # Only pass --resume if we can find an existing broadcast artifact for this script.
    local resume_arg=""
    if [[ -n "$RESUME_FLAG" ]]; then
        local chain_id="31337"
        local broadcast_dir="broadcast/$script_name/$chain_id"
        if [[ -f "$broadcast_dir/run-latest.json" || -f "$broadcast_dir/dry-run/run-latest.json" ]]; then
            resume_arg="$RESUME_FLAG"
        else
            log_info "No prior broadcast artifact for $script_name; skipping --resume"
        fi
    fi

    log_header "$description"
    log_info "Running $script_name..."

    if forge script "$SCRIPT_DIR/$script_name" \
        --rpc-url "$RPC_URL" \
        $BROADCAST_FLAG \
        --unlocked \
        --sender "$SENDER" \
        $resume_arg; then
        log_success "$description completed"
        return 0
    else
        log_error "$description failed"
        echo ""
        echo "To resume, run:"
        echo "  $0 --resume"
        echo ""
        return 1
    fi
}

run_stage() {
    local script_name=$1
    local description=$2
    local out_file=$3

    if [[ -n "$out_file" && -f "$out_file" && "$FORCE" -ne 1 ]]; then
        log_header "$description"
        log_info "Skipping $script_name (found existing $out_file)"
        return 0
    fi

    run_script "$script_name" "$description"
}

# Main deployment sequence
main() {
    log_header "IndexedEx Deployment to Anvil Base Mainnet Fork"

    if [[ "$SHOW_HELP" -eq 1 ]]; then
        usage
        return 0
    fi

    # Ensure Foundry runs with the correct `foundry.toml`/remappings regardless of where this script is launched from.
    cd "$REPO_ROOT"

    require_dev_address

    if [[ "$RESTART_ANVIL" -eq 1 && "$KILL_ANVIL" -eq 1 ]]; then
        log_error "Cannot use both --restart-anvil and --kill-anvil at the same time"
        exit 1
    fi

    if [[ "$RESTART_ANVIL" -eq 1 ]]; then
        log_header "Restart Anvil"

        if [[ -n "$RESUME_FLAG" ]]; then
            log_info "Ignoring --resume because --restart-anvil requires a clean fork state"
            RESUME_FLAG=""
        fi

        stop_anvil
        clean_deployments_artifacts
    fi

    if [[ "$KILL_ANVIL" -eq 1 ]]; then
        log_header "Kill Anvil"
        stop_anvil
        log_info "Anvil has been killed. Exiting."
        exit 0
    fi

    ensure_anvil

    # If the user restarted Anvil manually, we can still have stale artifacts.
    # Detect that early and clean so we don't skip stages into non-contract addresses.
    ensure_deployments_match_chain

    # On L2 forks (e.g. Base), default Anvil dev accounts may have EIP-7702
    # delegation bytecode attached, making them appear as contracts. Clear it
    # so wallets (MetaMask, etc.) can transact from these accounts.
    clear_dev_account_bytecode

    # Consolidate ETH from default Anvil wallets into DEV0 to avoid any interactive
    # prompts related to keystore unlocking/signing.
    sweep_anvil_wallets_to_dev0

    # Create output directory
    mkdir -p "$DEPLOYMENTS_DIR"

    # Run all scripts in order
    run_stage "Script_01_DeployFactories.s.sol" \
        "Stage 1: Deploy Factories (Create3, DiamondPackage)" \
        "$DEPLOYMENTS_DIR/01_factories.json"

    run_stage "Script_02_DeploySharedFacets.s.sol" \
        "Stage 2: Deploy Shared Facets (ERC20, ERC4626, Ownership)" \
        "$DEPLOYMENTS_DIR/02_shared_facets.json"

    run_stage "Script_03_DeployCoreProxies.s.sol" \
        "Stage 3: Deploy Core Proxies (FeeCollector, IndexedexManager)" \
        "$DEPLOYMENTS_DIR/03_core_proxies.json"

    run_stage "Script_04_DeployDEXPackages.s.sol" \
        "Stage 4: Deploy DEX Packages (UniV2, Aerodrome, Balancer)" \
        "$DEPLOYMENTS_DIR/04_dex_packages.json"

    run_stage "Script_05_DeployTestTokens.s.sol" \
        "Stage 5: Deploy Test Tokens (TTA, TTB, TTC)" \
        "$DEPLOYMENTS_DIR/05_test_tokens.json"

    run_stage "Script_06_DeployPools.s.sol" \
        "Stage 6: Deploy UniV2 Pools" \
        "$DEPLOYMENTS_DIR/06_pools.json"

    run_stage "Script_07_DeployStrategyVaults.s.sol" \
        "Stage 7: Deploy Strategy Vaults" \
        "$DEPLOYMENTS_DIR/07_strategy_vaults.json"

    run_stage "Script_08_DeployAerodromeStrategyVaults.s.sol" \
        "Stage 8: Deploy Aerodrome Strategy Vaults" \
        "$DEPLOYMENTS_DIR/08_aerodrome_strategy_vaults.json"

    run_stage "Script_09_DeployBalancerConstProdPools.s.sol" \
        "Stage 9: Deploy Balancer V3 ConstProd Pools" \
        "$DEPLOYMENTS_DIR/09_balancer_const_prod_pools.json"

    run_stage "Script_10_DepositBaseLiquidity.s.sol" \
        "Stage 10: Deposit Base Liquidity" \
        "$DEPLOYMENTS_DIR/10_base_liquidity.json"

    run_stage "Script_11_DeployStandardExchangeRateProviders.s.sol" \
        "Stage 11: Deploy Standard Exchange Rate Providers" \
        "$DEPLOYMENTS_DIR/11_standard_exchange_rate_providers.json"

    run_stage "Script_12_DeployBalancerConstProdVaultTokenPools.s.sol" \
        "Stage 12: Deploy Balancer V3 ConstProd Vault-Token Pools" \
        "$DEPLOYMENTS_DIR/12_balancer_const_prod_vault_token_pools.json"

    run_stage "Script_13_SeedBalancerVaultTokenPoolLiquidity.s.sol" \
        "Stage 13: Seed Balancer Vault-Token Pool Liquidity" \
        "$DEPLOYMENTS_DIR/13_balancer_vault_token_pool_liquidity.json"

    run_stage "Script_14_DeployERC4626PermitVaults.s.sol" \
        "Stage 14: Deploy ERC4626 Permit Vaults (TTA, TTB, TTC)" \
        "$DEPLOYMENTS_DIR/14_erc4626_permit_vaults.json"

    run_stage "Script_15_DeploySeigniorageDETFS.s.sol" \
        "Stage 15: Deploy Seigniorage DETFs (1 per Standard Exchange vault)" \
        "$DEPLOYMENTS_DIR/15_seigniorage_detfs.json"

    run_stage "Script_16_DeployProtocolDETF.s.sol" \
        "Stage 16: Deploy Protocol DETF (CHIR)" \
        "$DEPLOYMENTS_DIR/16_protocol_detf.json"

    run_stage "Script_17_DeployWethTtcPools.s.sol" \
        "Stage 17: Deploy WETH/TTC Pools (UniV2, Aerodrome, Balancer)" \
        "$DEPLOYMENTS_DIR/17_weth_ttc_pools.json"

    run_stage "Script_18_DeployWethTtcVaults.s.sol" \
        "Stage 18: Deploy WETH/TTC Strategy Vaults (UniV2, Aerodrome)" \
        "$DEPLOYMENTS_DIR/18_weth_ttc_vaults.json"

    run_stage "Script_19_SeedWethTtcBaseLiquidity.s.sol" \
        "Stage 19: Seed WETH/TTC Base Liquidity" \
        "$DEPLOYMENTS_DIR/19_weth_ttc_base_liquidity.json"

    run_stage "Script_20_DeployWethTtcRateProvidersAndBalancerVaultTokenPools.s.sol" \
        "Stage 20: Deploy WETH/TTC Rate Providers + Balancer Vault-Token Pools" \
        "$DEPLOYMENTS_DIR/20_weth_ttc_balancer_vault_token_pools.json"

    run_stage "Script_21_SeedWethTtcBalancerVaultTokenPoolLiquidity.s.sol" \
        "Stage 21: Seed WETH/TTC Balancer Vault-Token Pool Liquidity" \
        "$DEPLOYMENTS_DIR/21_weth_ttc_balancer_vault_token_pool_liquidity.json"

    run_stage "Script_22_DeployWethTtcVaultVaultPool.s.sol" \
        "Stage 22: Deploy WETH/TTC Vault-Vault Pool" \
        "$DEPLOYMENTS_DIR/22_weth_ttc_vault_vault_pool.json"

    run_stage "Script_23_SeedWethTtcVaultVaultPoolLiquidity.s.sol" \
        "Stage 23: Seed WETH/TTC Vault-Vault Pool Liquidity" \
        "$DEPLOYMENTS_DIR/23_weth_ttc_vault_vault_pool_liquidity.json"

    run_stage "Script_ExportTokenlists.s.sol" \
        "Export Segmented Tokenlists" \
        ""

    log_header "Sync Frontend Artifacts"
    sync_frontend_artifacts
    verify_frontend_router_keys

    sweep_anvil_wallets_to_deployer

    log_header "Deployment Complete!"
    log_info "Deployment artifacts saved to: $DEPLOYMENTS_DIR/"
    echo ""
    log_info "Summary:"
    cat "$DEPLOYMENTS_DIR/deployment_summary.json" 2>/dev/null || \
        log_error "Could not read deployment summary"
    echo ""
}

main "$@"
