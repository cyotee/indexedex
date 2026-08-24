#!/usr/bin/env bash
# =============================================================================
# Public Robinhood Chain mainnet (4663) architecture launch.
# No Phase 00. --sender $DEPLOYER_ADDRESS (cast wallet).
# Catalog: pins, Crane factories, FeeCollector, Manager, TWAP, Uni V4 SE pkg,
# CP single DETF pkg. No tokens. No Protocol DETF instances.
# Simulate each Foundry Stage then broadcast. Never --skip-simulation.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RH_FOUNDRY_DIR="$REPO_ROOT/scripts/foundry/anvil_robinhood_main"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/shell/lib/rh_4663_stages.sh"

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

if [[ -z "${RPC_URL:-}" ]]; then
  RPC_URL="$(resolve_foundry_rpc_alias robinhood_mainnet)"
fi
export RPC_URL

DEPLOYMENTS_DIR="${DEPLOYMENTS_DIR:-deployments/anvil_robinhood_main}"
export OUT_DIR_OVERRIDE="${OUT_DIR_OVERRIDE:-$DEPLOYMENTS_DIR}"
export NETWORK_PROFILE="${NETWORK_PROFILE:-anvil_robinhood_main}"
export CHAIN_ID="${CHAIN_ID:-4663}"

BROADCAST_FLAG="--broadcast"
FORCE=0
FROM_PHASE=""
FROM_STAGE=""
FORGE_VERBOSITY=""
COMMAND="all"

usage() {
  cat <<EOF
Usage:
  scripts/shell/robinhood_main.sh [command] [options]

Public 4663 architecture path. Does not run Phase 00. Requires DEPLOYER_ADDRESS.
Deploys Crane factories, FeeCollector, Manager, TWAP oracle, Uni V4 SE package,
and CP single SE DETF package. No tokens. No Protocol DETF instances.

Commands:
  all     Phases 01–06 architecture catalog

Options:
  --dry-run         Simulate each Stage, do not broadcast
  --rpc-url URL     Broadcast RPC (default Foundry alias robinhood_mainnet)
  --force           FORCE=1 re-run Stages
  --from-phase PP   Resume at Phase PP
  --from-stage SS   Resume at Stage SS of --from-phase
  -v…-vvvvv         Forge verbosity
  --help, -h
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

if [[ -z "${DEPLOYER_ADDRESS:-}" ]]; then
  log_error "robinhood_main.sh requires DEPLOYER_ADDRESS"
  echo "Example: export DEPLOYER_ADDRESS=0x..."
  echo "Forge uses --sender \$DEPLOYER_ADDRESS; cast wallet signs."
  exit 1
fi

SENDER="$DEPLOYER_ADDRESS"
DEV_ADDRESS="${DEV_ADDRESS:-$DEPLOYER_ADDRESS}"
OWNER="${OWNER:-$DEPLOYER_ADDRESS}"
UI_WALLET="${UI_WALLET:-$DEPLOYER_ADDRESS}"
export DEPLOYER_ADDRESS SENDER DEV_ADDRESS OWNER UI_WALLET

run_forge_cmd() {
  (
    cd "$REPO_ROOT"
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

is_transient_rpc_error_log() {
  local file="$1"
  grep -qiE 'dns error|nodename nor servname|failed to lookup|error sending request|client error \(Connect\)|timed out|timeout|connection reset|429' "$file"
}

run_forge_with_retries() {
  local attempt=1
  local max="${FORGE_RPC_RETRIES:-6}"
  local sleep_s="${FORGE_RPC_RETRY_SLEEP:-8}"
  local tmp st
  tmp="$(mktemp)"
  while true; do
    set +e
    run_forge_cmd "$@" 2>&1 | tee "$tmp"
    st=${PIPESTATUS[0]}
    set -e
    if [[ "$st" -eq 0 ]]; then
      rm -f "$tmp"
      return 0
    fi
    if [[ "$attempt" -ge "$max" ]] || ! is_transient_rpc_error_log "$tmp"; then
      rm -f "$tmp"
      return "$st"
    fi
    log_info "Transient RPC/DNS error (attempt $attempt/$max). Retry in ${sleep_s}s"
    sleep "$sleep_s"
    attempt=$((attempt + 1))
  done
}

forge_script_base() {
  local script_path="$1"
  local cmd=(forge script "$script_path" --rpc-url "$RPC_URL")
  if [[ -n "$FORGE_VERBOSITY" ]]; then
    cmd+=("$FORGE_VERBOSITY")
  fi
  cmd+=(--sender "$DEPLOYER_ADDRESS" --non-interactive)
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
  if ! run_forge_with_retries "${sim_cmd[@]}"; then
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

  log_info "Broadcasting $label"
  run_forge_with_retries "${bcast_cmd[@]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    all)
      COMMAND="$1"
      shift
      ;;
    --dry-run)
      BROADCAST_FLAG=""
      shift
      ;;
    --rpc-url)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        log_error "--rpc-url requires a URL"
        exit 1
      fi
      RPC_URL="$2"
      export RPC_URL
      shift 2
      ;;
    --rpc-url=*)
      RPC_URL="${1#--rpc-url=}"
      export RPC_URL
      shift
      ;;
    --force)
      FORCE=1
      export FORCE=1
      shift
      ;;
    --from-phase)
      FROM_PHASE="$(printf '%02d' "$((10#$2))")"
      FROM_STAGE="${FROM_STAGE:-01}"
      shift 2
      ;;
    --from-stage)
      FROM_STAGE="$(printf '%02d' "$((10#$2))")"
      shift 2
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

log_header "Public Robinhood mainnet (4663) architecture: $COMMAND"
log_info "SENDER=$DEPLOYER_ADDRESS OUT_DIR=$OUT_DIR_OVERRIDE (no Phase 00)"

CID="$(cast chain-id --rpc-url "$RPC_URL" | tr -d '[:space:]')"
if [[ "$CID" != "4663" ]]; then
  log_error "Expected chain id 4663, got ${CID:-<empty>}"
  exit 1
fi

case "$COMMAND" in
  all)
    rh_run_catalog 0 "$FROM_PHASE" "$FROM_STAGE"
    ;;
  *)
    log_error "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac

log_success "Command '$COMMAND' completed"
exit 0
