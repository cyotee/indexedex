#!/usr/bin/env bash
# =============================================================================
# IndexedEx Public Sepolia Deployment Script
# =============================================================================
#
# Deploys the Sepolia-safe subset of the IndexedEx stack to public Ethereum
# Sepolia using the Foundry RPC alias `ethereum_sepolia_alchemy`.
#
# This flow intentionally skips WETH-linked stages to conserve Sepolia ETH.
# Included stages in the single Foundry run:
#   01-15, then tokenlist export
# Skipped stages:
#   16-23 (Protocol DETF + WETH/TTC pools/vaults/liquidity)
#
# Required signer env:
#   Either PRIVATE_KEY or ACCOUNT must be set
#
# Optional env:
#   ACCOUNT      Foundry keystore account name used for broadcasting
#   SENDER       Explicit sender address; useful with --account/keystore flows
#   OWNER        Owner address for newly deployed contracts; defaults to signer
#   RPC_URL      Defaults to `ethereum_sepolia_alchemy`
#   FORGE_SLOW   Defaults to 1 to serialize public broadcasts
#
# =============================================================================

set -e

RPC_URL="${RPC_URL:-ethereum_sepolia_alchemy}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PRIVATE_KEY="${PRIVATE_KEY:-}"
ACCOUNT="${ACCOUNT:-}"
SENDER="${SENDER:-}"
FORGE_SLOW="${FORGE_SLOW:-1}"

RESUME_FLAG=""
BROADCAST_FLAG="--broadcast"
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
        --force)
            FORCE=1
            ;;
    esac
done

usage() {
    cat <<EOF
Usage:
    scripts/foundry/sepolia/deploy_sepolia.sh [options]

Options:
    --resume   Resume from prior broadcast artifacts when available
    --dry-run  Simulate the full Sepolia demo deployment in one forge script session
    --force    Re-run stages even if their output JSON already exists
    --help,-h  Show this help

Required signer env:
    Either PRIVATE_KEY or ACCOUNT must be set

Optional env:
    ACCOUNT, SENDER, OWNER, RPC_URL, FORGE_SLOW
EOF
}

if [[ "$SHOW_HELP" -eq 1 ]]; then
    usage
    exit 0
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() {
    echo ""
    echo -e "${YELLOW}=============================================================================${NC}"
    echo -e "${YELLOW} $1${NC}"
    echo -e "${YELLOW}=============================================================================${NC}"
}

require_signer() {
    if [[ -z "$PRIVATE_KEY" && -z "$ACCOUNT" ]]; then
        log_error "No signer configured"
        echo ""
        echo "Set either PRIVATE_KEY or ACCOUNT for Sepolia runs."
        echo ""
        exit 1
    fi

    if [[ -n "$ACCOUNT" && -z "$SENDER" ]]; then
        log_error "SENDER is required when using ACCOUNT"
        echo ""
        echo "This deployment flow needs the actual broadcaster address inside the scripts."
        echo "Set SENDER to the keystore account address when using ACCOUNT."
        echo ""
        exit 1
    fi

    if [[ -z "${OWNER:-}" ]]; then
        if [[ -n "$SENDER" ]]; then
            export OWNER="$SENDER"
        elif [[ -n "$PRIVATE_KEY" ]]; then
            export OWNER="$(cast wallet address --private-key "$PRIVATE_KEY")"
        else
            log_error "OWNER is not set"
            echo ""
            echo "When using ACCOUNT, set SENDER or OWNER explicitly."
            echo "Example:"
            echo "  export ACCOUNT=my-sepolia"
            echo "  export SENDER=0xYourKeystoreAddress"
            echo ""
            exit 1
        fi
    fi

    if [[ -n "$SENDER" ]]; then
        export DEPLOYER="$SENDER"
    elif [[ -n "$PRIVATE_KEY" ]]; then
        export DEPLOYER="$(cast wallet address --private-key "$PRIVATE_KEY")"
    fi
}

clean_deployments_artifacts() {
    local deployments_dir="deployments/sepolia"
    mkdir -p "$deployments_dir"
    log_info "Cleaning deployment artifacts in $deployments_dir"
    rm -f "$deployments_dir"/*.json 2>/dev/null || true
    rm -f "$deployments_dir"/*.tokenlist.json 2>/dev/null || true
}

run_deployment() {
    local script_name="Script_00_DeploySepoliaDemo.s.sol"
    local stage_name="Sepolia Demo Deployment"
    local resume_arg=""
    local slow_arg=""
    local signer=()

    if [[ -z "$BROADCAST_FLAG" ]]; then
        resume_arg=""
    elif [[ -n "$RESUME_FLAG" ]]; then
        local chain_id="11155111"
        local broadcast_dir="broadcast/$script_name/$chain_id"
        if [[ -f "$broadcast_dir/run-latest.json" || -f "$broadcast_dir/dry-run/run-latest.json" ]]; then
            resume_arg="$RESUME_FLAG"
        else
            log_info "No prior broadcast artifact for $script_name; skipping --resume"
        fi
    fi

    if [[ -n "$BROADCAST_FLAG" && "$FORGE_SLOW" != "0" ]]; then
        slow_arg="--slow"
    fi

    if [[ -n "$PRIVATE_KEY" ]]; then
        signer+=(--private-key "$PRIVATE_KEY")
    elif [[ -n "$ACCOUNT" ]]; then
        signer+=(--account "$ACCOUNT")
        if [[ -n "$SENDER" ]]; then
            signer+=(--sender "$SENDER")
        fi
    fi

    log_header "$stage_name"
    forge script "$SCRIPT_DIR/$script_name" \
        --rpc-url "$RPC_URL" \
        $BROADCAST_FLAG \
        $resume_arg \
        $slow_arg \
        "${signer[@]}"
}

sync_frontend_artifacts() {
    local deployments_dir="deployments/sepolia"
    local frontend_dir="frontend/app/addresses/sepolia"

    mkdir -p "$frontend_dir"

    local copied_any=0
    local f

    for f in "$deployments_dir"/sepolia-*.tokenlist.json; do
        if [[ ! -e "$f" ]]; then
            continue
        fi

            cp "$f" "$frontend_dir/$(basename "$f")"
            copied_any=1
    done

    if [[ "$copied_any" -eq 1 ]]; then
        log_success "Synced tokenlists to frontend: $frontend_dir"
    fi

    if [[ "$copied_any" -ne 1 ]]; then
        log_error "No tokenlists found to sync."
        log_info "Expected exported outputs at: $deployments_dir/sepolia-*.tokenlist.json"
    fi

    python3 - "$deployments_dir" "$frontend_dir" <<'PY'
import glob
import json
import os
import sys
import time

deployments_dir = sys.argv[1]
frontend_dir = sys.argv[2]
out_path = os.path.join(frontend_dir, "base_deployments.json")

base = {}
if os.path.exists(out_path):
    try:
        with open(out_path, "r") as f:
            loaded = json.load(f)
            if isinstance(loaded, dict):
                base = loaded
    except Exception:
        base = {}

paths = [
    p
    for p in glob.glob(os.path.join(deployments_dir, "*.json"))
    if not p.endswith(".tokenlist.json")
]

def sort_key(p: str) -> tuple:
    name = os.path.basename(p)
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

base["chainId"] = 11155111
base["exportedAt"] = str(int(time.time()))

if "create3Factory" in base and "craneFactory" not in base:
    base["craneFactory"] = base["create3Factory"]
if "diamondPackageFactory" in base and "craneDiamondFactory" not in base:
    base["craneDiamondFactory"] = base["diamondPackageFactory"]
if "uniswapV2Pkg" in base and "uniswapV2StandardStrategyVaultPkg" not in base:
    base["uniswapV2StandardStrategyVaultPkg"] = base["uniswapV2Pkg"]

os.makedirs(frontend_dir, exist_ok=True)
with open(out_path, "w") as f:
    json.dump(base, f, indent=2, sort_keys=False)
    f.write("\n")

factories_path = os.path.join(frontend_dir, "sepolia-factories.contractlist.json")
if not os.path.exists(factories_path):
    with open(factories_path, "w") as f:
        f.write("[]\n")
PY

    log_success "Synced platform addresses to frontend: $frontend_dir/base_deployments.json"
}

main() {
    cd "$REPO_ROOT"
    require_signer

    if [[ "$FORCE" -eq 1 ]]; then
        clean_deployments_artifacts
    fi

    run_deployment

    sync_frontend_artifacts
    log_success "Public Sepolia deployment flow complete"
}

main "$@"