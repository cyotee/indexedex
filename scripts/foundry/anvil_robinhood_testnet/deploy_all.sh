#!/usr/bin/env bash
# =============================================================================
# Robinhood testnet (46630) launch groups 00-06 + 09.
# Local Anvil: Anvil Dev 0 + --unlocked. --live: DEPLOYER_ADDRESS (cast wallet).
# Every group simulates first. Never --skip-simulation. --dry-run stops after sim.
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
DEPLOYER_ADDRESS="${DEPLOYER_ADDRESS:-}"
SENDER="${SENDER:-}"
OWNER="${OWNER:-}"
UI_WALLET="${UI_WALLET:-}"
ANVIL_DEV0="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ANVIL_DEV1="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

BROADCAST_FLAG="--broadcast"
RESTART_ANVIL=0
KILL_ANVIL=0
FORCE=0
FORK_LATEST=0
LIVE_BROADCAST=0
RPC_URL_EXPLICIT=0
FORGE_VERBOSITY=""
COMMAND="all"

usage() {
  cat <<EOF
Usage:
  scripts/shell/anvil_robinhood_testnet.sh [command] [options]
  scripts/foundry/anvil_robinhood_testnet/deploy_all.sh [command] [options]

These groups are the 46630 launch scripts. Local Anvil defaults to Anvil Dev 0
with --unlocked. --live broadcasts to public 46630 as DEPLOYER_ADDRESS (cast
wallet). Point RPC_URL at a local Anvil fork to rehearse.

Commands:
  all           Staged deploy: 00-05, 04b (Mag7 tokens), 06t (TTCHIR), 06e (TTDOL-Q), 09
                Packages: Uni V4 SE + CP (Protocol DETF) + Curve Quad (Double Dollar). Not 03b.
  foundation    Groups 00-03 (CP + Curve Quad packages only)
  assets        Groups 04 + 04b
  pools         Group 05
  leaves        06t (TTCHIR) + 06e (TTDOL-Q)
  export        Group 09 (frontend JSON)
  simulate      Alternate: Script_SimulateLaunch (01-06 in one script, for gas estimate). Do not run after \`all\`.
  stageNN       Single group (00-06, 04b, 06t, 06e, 09). stage03b is optional later (Orbital + Weighted).
  stagesimulate Same as simulate
  detach-fork   Anvil-only: dump overlay, restart without a fork, reload state. Use when the
                public RH RPC returns "metadata is not found" for new CREATE addresses.

Options:
  --dry-run         Simulate each group and stop (no broadcast). Default path still
                    simulates every group before it broadcasts. Never skips simulation.
  --live            Broadcast to public 46630 (official RPC unless RPC_URL is already set).
                    Does not start Anvil. Requires DEPLOYER_ADDRESS (cast wallet).
                    Does not use Anvil Dev 0.
  --rpc-url URL     Broadcast RPC (default http://127.0.0.1:8545)
  --restart-anvil   Local only: kill port + start a RH testnet fork at chain id 46630
                    with --disable-code-size-limit (Anvil node flag, not a script cheat)
  --kill-anvil      Kill Anvil and exit
  --force           Re-run stages (purge stage JSON first when restarting)
  --fork-alias NAME Anvil fork source: Foundry [rpc_endpoints] alias (default robinhood_testnet_alchemy)
  --public-rpc      Anvil fork source = robinhood_testnet (official public RPC). Not --live.
  --fork-latest     Do not pass --fork-block-number; Anvil uses the remote tip
  -v…-vvvvv         Forge verbosity
  --help, -h

Signer:
  SENDER / DEV_ADDRESS / DEPLOYER_ADDRESS
                    Passed as forge --sender. Local default is Anvil Dev 0
                    (0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) with --unlocked.
  OWNER             Defaults to the deployer
  UI_WALLET         Local default is Anvil Dev 1. --live defaults to the deployer.
  --live            Requires DEPLOYER_ADDRESS (cast wallet). No --unlocked.

Optional:
  ALCHEMY_KEY   Anvil fork source only (`robinhood_testnet_alchemy`). `--live` always uses the public 46630 RPC.
  FORGE_RPC_RETRIES / FORGE_RPC_RETRY_SLEEP  DNS/connect retry (default 6 x 8s)
  ANVIL_FORK_URL / FOUNDRY_FORK_RPC_ALIAS (default robinhood_testnet_alchemy)
  ANVIL_FORK_BLOCK_NUMBER (default Crane pin; set to latest to omit the pin)
  FORGE_LEGACY=1  Force --legacy gas on live (Anvil local already uses legacy)
  --public-rpc without --fork-latest retargets the Anvil pin to head-64.
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

# Keep overlay, drop the remote fork. Public 46630 nodes prune the fork-block trie
# mid-session; Anvil then fatal-errors on any never-seen account (CREATE3 / CREATE2).
# `--load-state` wants SerializableState JSON. `anvil_dumpState` is gzip(JSON) as hex;
# HTTP anvil_loadState rejects the ~8MB POST, so we decompress to JSON and load on boot.
launch_anvil_offline() {
  local state_json="${1:-}"
  local anvil_cmd=(
    anvil
    --host "$ANVIL_HOST"
    --port "$ANVIL_PORT"
    --chain-id "$ANVIL_CHAIN_ID"
    --hardfork prague
    --disable-code-size-limit
    --disable-block-gas-limit
  )
  if [[ -n "$state_json" ]]; then
    anvil_cmd+=(--load-state "$state_json")
  fi
  nohup "${anvil_cmd[@]}" >"$ANVIL_LOG_DIR/anvil.log" 2>&1 &
  echo $!
}

ANVIL_STATE_HEX="${ANVIL_STATE_HEX:-$ANVIL_LOG_DIR/anvil_state.hex}"
ANVIL_STATE_JSON="${ANVIL_STATE_JSON:-$ANVIL_LOG_DIR/anvil_state.json}"
DETACHED_FORK=0

dump_anvil_state() {
  mkdir -p "$ANVIL_LOG_DIR"
  log_info "Dumping Anvil overlay to $ANVIL_STATE_HEX"
  perl -e 'alarm shift; exec @ARGV' 180 cast rpc anvil_dumpState --rpc-url "$RPC_URL" >"$ANVIL_STATE_HEX"
  local bytes
  bytes="$(wc -c <"$ANVIL_STATE_HEX" | tr -d ' ')"
  if [[ ! -s "$ANVIL_STATE_HEX" || "$bytes" -lt 32 ]]; then
    log_error "anvil_dumpState produced an empty dump"
    return 1
  fi
  log_info "Dump size ${bytes} bytes; decoding gzip JSON for --load-state"
  python3 - "$ANVIL_STATE_HEX" "$ANVIL_STATE_JSON" <<'PY'
import gzip, json, pathlib, sys
src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
raw = src.read_text().strip()
if raw.startswith('"') and raw.endswith('"'):
    raw = json.loads(raw)
if not raw.startswith("0x"):
    raise SystemExit("anvil_dumpState: expected 0x-prefixed hex")
data = gzip.decompress(bytes.fromhex(raw[2:]))
if data[:1] not in (b"{", b"["):
    raise SystemExit("anvil_dumpState: decompressed payload is not JSON")
dst.write_bytes(data)
print(f"wrote {dst} ({len(data)} bytes)")
PY
}

verify_offline_overlay() {
  local factory
  factory="$(python3 -c 'import json,pathlib,sys; p=pathlib.Path(sys.argv[1]);
print(json.loads(p.read_text()).get("create3Factory",""))' "$REPO_ROOT/$DEPLOYMENTS_DIR/01_factories.json" 2>/dev/null || true)"
  if [[ -z "$factory" ]]; then
    log_error "Cannot verify overlay: $DEPLOYMENTS_DIR/01_factories.json missing create3Factory"
    return 1
  fi
  local size
  size="$(cast codesize "$factory" --rpc-url "$RPC_URL" 2>/dev/null || echo 0)"
  if [[ "$size" == "0" || -z "$size" ]]; then
    log_error "Overlay reload failed: create3Factory $factory has no code"
    return 1
  fi
  log_success "Offline Anvil overlay live (create3Factory code size $size)"
}

# Public RH RPC: "metadata is not found, <fork-block>" for accounts never seen on
# the fork. After the node prunes that trie, Anvil cannot CREATE new addresses.
# Dump overlay, restart without --fork-url, reload. Groups 00-N stay; new CREATE works.
detach_fork() {
  dump_anvil_state
  log_info "Restarting Anvil chain $ANVIL_CHAIN_ID without a remote fork"
  kill_anvil
  mkdir -p "$ANVIL_LOG_DIR"
  local pid
  pid="$(launch_anvil_offline "$ANVIL_STATE_JSON")"
  if ! wait_for_rpc "$pid"; then
    log_error "Offline Anvil failed to start"
    dump_anvil_log
    return 1
  fi
  verify_offline_overlay
  DETACHED_FORK=1
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

# Local: Anvil Dev 0 + --unlocked. --live: DEPLOYER_ADDRESS via the cast wallet.
require_deployer() {
  if [[ "$LIVE_BROADCAST" -eq 1 ]]; then
    if [[ -z "${DEPLOYER_ADDRESS:-}" && -z "${SENDER:-}" && -z "${DEV_ADDRESS:-}" ]]; then
      log_error "--live requires DEPLOYER_ADDRESS (cast wallet account)"
      echo "Example: export DEPLOYER_ADDRESS=0x..."
      echo "Forge uses --sender \$DEPLOYER_ADDRESS; cast wallet signs."
      exit 1
    fi
  fi
  if [[ -z "$SENDER" ]]; then
    SENDER="${DEPLOYER_ADDRESS:-${DEV_ADDRESS:-$ANVIL_DEV0}}"
  fi
  DEV_ADDRESS="${DEV_ADDRESS:-$SENDER}"
  DEPLOYER_ADDRESS="${DEPLOYER_ADDRESS:-$SENDER}"
  OWNER="${OWNER:-$SENDER}"
  if [[ "$LIVE_BROADCAST" -eq 1 ]]; then
    UI_WALLET="${UI_WALLET:-$SENDER}"
  else
    UI_WALLET="${UI_WALLET:-$ANVIL_DEV1}"
  fi
  export DEPLOYER_ADDRESS SENDER DEV_ADDRESS OWNER UI_WALLET
}

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

# Retry forge on public-RPC DNS / connect flakes. Never skips simulation.
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

# Base forge script argv. Never append --skip-simulation.
forge_script_base() {
  local script_path="$1"
  local cmd=(forge script "$script_path" --rpc-url "$RPC_URL")
  if [[ -n "$FORGE_VERBOSITY" ]]; then
    cmd+=("$FORGE_VERBOSITY")
  fi
  cmd+=(--sender "$SENDER")
  if is_localhost_rpc && [[ "$LIVE_BROADCAST" -eq 0 ]]; then
    cmd+=(--unlocked)
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
  # Anvil forks often fail eth_feeHistory. Live 46630 uses EIP-1559 unless FORGE_LEGACY=1.
  if is_localhost_rpc || [[ "${FORGE_LEGACY:-0}" == "1" ]]; then
    bcast_cmd+=(--legacy --gas-price "${FORGE_GAS_PRICE:-2000000000}")
  fi

  log_info "Broadcasting $label"
  if run_forge_with_retries "${bcast_cmd[@]}"; then
    return 0
  fi
  if is_localhost_rpc && [[ "$DETACHED_FORK" -eq 0 && -f "$ANVIL_LOG_DIR/anvil.log" ]] \
    && grep -q "metadata is not found" "$ANVIL_LOG_DIR/anvil.log"; then
    log_error "$label failed: public RH RPC pruned the fork trie (metadata is not found)"
    log_info "Dumping overlay, restarting Anvil without a fork, retrying $label"
    detach_fork
    run_forge_with_retries "${bcast_cmd[@]}"
  else
    return 1
  fi
}

stage_script() {
  local n="$1"
  case "$n" in
    00) echo "$SCRIPT_DIR/Script_00_Preflight.s.sol" ;;
    01) echo "$SCRIPT_DIR/Script_01_Factories.s.sol" ;;
    02) echo "$SCRIPT_DIR/Script_02_Platform.s.sol" ;;
    03) echo "$SCRIPT_DIR/Script_03_UniV4Packages.s.sol" ;;
    03b) echo "$SCRIPT_DIR/Script_03b_OrbitalWeightedPackages.s.sol" ;;
    04) echo "$SCRIPT_DIR/Script_04_Tokens.s.sol" ;;
    04b) echo "$SCRIPT_DIR/Script_04b_SevenTestTokens.s.sol" ;;
    05) echo "$SCRIPT_DIR/Script_05_LeafPoolsAndSEs.s.sol" ;;
    06) echo "$SCRIPT_DIR/Script_06_LeafDETFs.s.sol" ;;
    06e) echo "$SCRIPT_DIR/Script_06e_DolQ.s.sol" ;;
    06t) echo "$SCRIPT_DIR/Script_06_Ttchir.s.sol" ;;
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
    all|foundation|assets|pools|leaves|export|simulate|detach-fork)
      COMMAND="$1"
      shift
      ;;
    stage[0-9][0-9]|stage[0-9]|stage03b|stage04b|stage06[et]|stagesimulate)
      COMMAND="$1"
      shift
      ;;
    --dry-run)
      BROADCAST_FLAG=""
      shift
      ;;
    --live)
      LIVE_BROADCAST=1
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

if [[ "$LIVE_BROADCAST" -eq 1 ]]; then
  if is_localhost_rpc; then
    if [[ "$RPC_URL_EXPLICIT" -eq 1 ]]; then
      log_error "--live cannot target a localhost --rpc-url (got $RPC_URL)"
      exit 1
    fi
    RPC_URL="$(resolve_foundry_rpc_alias robinhood_testnet)"
    export RPC_URL
  fi
  if [[ "$RESTART_ANVIL" -eq 1 ]]; then
    log_error "--live cannot be combined with --restart-anvil"
    exit 1
  fi
  if [[ "$COMMAND" == "detach-fork" ]]; then
    log_error "detach-fork is Anvil-only"
    exit 1
  fi
  log_info "Live 46630 broadcast RPC=$RPC_URL"
fi

if [[ "$RESTART_ANVIL" -eq 1 ]] && ! is_localhost_rpc; then
  log_error "--restart-anvil requires a localhost RPC_URL (got $RPC_URL)"
  exit 1
fi

if [[ "${ANVIL_FORK_BLOCK_NUMBER:-}" == "latest" ]]; then
  FORK_LATEST=1
fi

if is_localhost_rpc; then
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
  log_info "Anvil fork alias $FOUNDRY_FORK_RPC_ALIAS ($_fork_host)"
  unset _fork_host
fi

require_deployer

if is_localhost_rpc; then
  if [[ "$RESTART_ANVIL" -eq 1 ]]; then
    kill_anvil
    purge_stage_artifacts
  fi
  start_anvil
else
  log_info "Skipping Anvil start (RPC is not localhost)"
fi

# Group 09 only writes JSON. Skip the extra `cast chain-id` so a DNS flake
# cannot block export before forge (which already requires chain 46630).
if [[ "$COMMAND" != "export" && "$COMMAND" != "stage09" ]]; then
  log_info "Checking chain id at $RPC_URL"
  CID=""
  cid_attempt=1
  cid_max="${FORGE_RPC_RETRIES:-6}"
  cid_sleep="${FORGE_RPC_RETRY_SLEEP:-8}"
  while [[ "$cid_attempt" -le "$cid_max" ]]; do
    set +e
    CID="$(cast chain-id --rpc-url "$RPC_URL" 2>/tmp/cast-chain-id.err)"
    cid_st=$?
    set -e
    if [[ "$cid_st" -eq 0 && -n "$CID" ]]; then
      break
    fi
    log_info "cast chain-id failed (attempt $cid_attempt/$cid_max)"
    if [[ -s /tmp/cast-chain-id.err ]]; then
      cat /tmp/cast-chain-id.err >&2 || true
    fi
    if [[ "$cid_attempt" -eq "$cid_max" ]]; then
      log_error "cast chain-id failed against $RPC_URL"
      log_error "Need a working 46630 RPC and foundry cast on PATH."
      exit 1
    fi
    sleep "$cid_sleep"
    cid_attempt=$((cid_attempt + 1))
  done
  CID="$(printf '%s' "$CID" | tr -d '[:space:]')"
  if [[ "$CID" != "46630" ]]; then
    log_error "Expected chain id 46630, got ${CID:-<empty>}"
    if is_localhost_rpc; then
      log_error "Start Anvil with --chain-id 46630 --disable-code-size-limit"
    fi
    exit 1
  fi
  log_success "Chain id $CID RPC=$RPC_URL"
else
  log_info "Skipping wrapper chain-id check for $COMMAND (group 09 is JSON export)"
fi

log_header "Robinhood testnet (46630) deploy: $COMMAND"
log_info "SENDER=$SENDER UI_WALLET=$UI_WALLET OUT_DIR=$OUT_DIR_OVERRIDE"

case "$COMMAND" in
  all)
    run_stages 00 01 02 03 04 04b 05 06t 06e 09
    ;;
  foundation)
    run_stages 00 01 02 03
    ;;
  assets)
    run_stages 04 04b
    ;;
  pools)
    run_stages 05
    ;;
  leaves)
    run_stages 06t 06e
    ;;
  simulate|stagesimulate)
    run_stages simulate
    ;;
  export)
    run_stages 09
    ;;
  detach-fork)
    if ! is_localhost_rpc; then
      log_error "detach-fork is Anvil-only"
      exit 1
    fi
    detach_fork
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
