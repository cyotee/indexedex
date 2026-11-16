#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$0"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

DEFAULT_SHARED_DIR="$REPO_ROOT/deployments/public_sepolia_supersim/shared"
BRIDGE_PLAN_FILE="${BRIDGE_PLAN_FILE:-$DEFAULT_SHARED_DIR/bridge_execution_plan.json}"
BRIDGE_MANIFEST_FILE="${BRIDGE_MANIFEST_FILE:-$DEFAULT_SHARED_DIR/bridge_token_manifest.json}"

ETHEREUM_RPC_URL="${ETHEREUM_RPC_URL:-http://127.0.0.1:8545}"
BASE_RPC_URL="${BASE_RPC_URL:-http://127.0.0.1:9545}"

L1_CROSS_DOMAIN_MESSENGER="${L1_CROSS_DOMAIN_MESSENGER:-0xC34855F4De64F1840e5686e64278da901e261f20}"
L2_CROSS_DOMAIN_MESSENGER="${L2_CROSS_DOMAIN_MESSENGER:-0x4200000000000000000000000000000000000007}"
L1_TO_L2_ALIAS_OFFSET="0x1111000000000000000000000000000000001111"
MIN_GAS_LIMIT="${MIN_GAS_LIMIT:-200000}"
IMPERSONATED_BALANCE_WEI="${IMPERSONATED_BALANCE_WEI:-0x3635C9ADC5DEA00000}"

DRY_RUN=0

print_help() {
  cat <<EOF
Usage:
  scripts/foundry/public_sepolia/finalize_bridge_tokens_on_base.sh [--dry-run]

This helper is for local SuperSim testing only. It replays the Base-side
relayMessage(finalizeBridgeERC20(...)) path for the five Stage 2B bridge tokens
using the artifacts written by the manual public_sepolia flow.

Expected placement in the flow:
  Stage 1 -> Stage 2A -> Stage 2B -> this script -> Stage 3

Required files:
  BRIDGE_PLAN_FILE      Defaults to deployments/public_sepolia_supersim/shared/bridge_execution_plan.json
  BRIDGE_MANIFEST_FILE  Defaults to deployments/public_sepolia_supersim/shared/bridge_token_manifest.json

Optional environment variables:
  ETHEREUM_RPC_URL              Defaults to http://127.0.0.1:8545
  BASE_RPC_URL                  Defaults to http://127.0.0.1:9545
  BRIDGE_START_NONCE            Override the first L1 messenger nonce to replay.
  MIN_GAS_LIMIT                 Defaults to 200000.
  IMPERSONATED_BALANCE_WEI      Defaults to 1000 ETH in hex.
  L1_CROSS_DOMAIN_MESSENGER     Defaults to the Base Sepolia L1 messenger.
  L2_CROSS_DOMAIN_MESSENGER     Defaults to the Base Sepolia L2 messenger.

Notes:
  - This does not fix the underlying local Anvil deposit crash.
  - It simulates the L2 finalization path so later Base-side deployment stages can proceed.
  - By default the script derives the first replay nonce as:
      current L1 messenger nonce - 5
    because Stage 2B bridges five tokens in a fixed order.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      print_help >&2
      exit 1
      ;;
  esac
done

require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

require_file() {
  local path="$1"

  if [[ ! -f "$path" ]]; then
    echo "Required file not found: $path" >&2
    exit 1
  fi
}

json_value() {
  local file="$1"
  local key="$2"

  jq -r --arg key "$key" '.[$key]' "$file"
}

normalize_uint() {
  printf '%s\n' "$1" | awk '{print $1}'
}

cast_uint_call() {
  local rpc_url="$1"
  local to="$2"
  local sig="$3"
  shift 3

  normalize_uint "$(cast call "$to" "$sig" "$@" --rpc-url "$rpc_url")"
}

contract_has_code() {
  local rpc_url="$1"
  local address="$2"
  local code

  code="$(cast code "$address" --rpc-url "$rpc_url" 2>/dev/null || true)"
  [[ -n "$code" && "$code" != "0x" ]]
}

python_eval() {
  python3 - "$@" <<'PY'
import sys

expr = sys.argv[1]
args = sys.argv[2:]
ns = {f"arg{i}": args[i] for i in range(len(args))}
ns["int"] = int
ns["hex"] = hex
ns["format"] = format
print(eval(expr, {"__builtins__": {}}, ns))
PY
}

compute_aliased_address() {
  python3 - "$1" "$L1_TO_L2_ALIAS_OFFSET" <<'PY'
import sys

l1_addr = int(sys.argv[1], 16)
offset = int(sys.argv[2], 16)
mask = (1 << 160) - 1
print(f"0x{((l1_addr + offset) & mask):040x}")
PY
}

require_command cast
require_command jq
require_command python3
require_file "$BRIDGE_PLAN_FILE"
require_file "$BRIDGE_MANIFEST_FILE"

RECIPIENT="$(json_value "$BRIDGE_PLAN_FILE" recipient)"
L1_STANDARD_BRIDGE="$(json_value "$BRIDGE_PLAN_FILE" l1StandardBridge)"
L2_STANDARD_BRIDGE="$(json_value "$BRIDGE_MANIFEST_FILE" l2StandardBridge)"
ALIASED_L1_MESSENGER="$(compute_aliased_address "$L1_CROSS_DOMAIN_MESSENGER")"

TOKEN_KEYS=(tta ttb ttc demoWeth rich)
TOKEN_COUNT="${#TOKEN_KEYS[@]}"

CURRENT_L1_NONCE="$(cast_uint_call "$ETHEREUM_RPC_URL" "$L1_CROSS_DOMAIN_MESSENGER" "messageNonce()(uint256)")"

if [[ -n "${BRIDGE_START_NONCE:-}" ]]; then
  START_NONCE="$BRIDGE_START_NONCE"
else
  START_NONCE="$(python3 - "$CURRENT_L1_NONCE" "$TOKEN_COUNT" <<'PY'
import sys

current_nonce = int(sys.argv[1], 0)
token_count = int(sys.argv[2], 0)
if current_nonce < token_count:
    raise SystemExit("Current L1 messenger nonce is lower than the expected bridge message count")
print(current_nonce - token_count)
PY
)"
fi

echo "Base relay fallback"
echo "  bridge plan:      $BRIDGE_PLAN_FILE"
echo "  bridge manifest:  $BRIDGE_MANIFEST_FILE"
echo "  ethereum rpc:     $ETHEREUM_RPC_URL"
echo "  base rpc:         $BASE_RPC_URL"
echo "  recipient:        $RECIPIENT"
echo "  l1 messenger:     $L1_CROSS_DOMAIN_MESSENGER"
echo "  aliased sender:   $ALIASED_L1_MESSENGER"
echo "  l1 bridge:        $L1_STANDARD_BRIDGE"
echo "  l2 messenger:     $L2_CROSS_DOMAIN_MESSENGER"
echo "  l2 bridge:        $L2_STANDARD_BRIDGE"
echo "  current l1 nonce: $CURRENT_L1_NONCE"
echo "  start nonce:      $START_NONCE"

for token_key in "${TOKEN_KEYS[@]}"; do
  l2_key="${token_key}L2Token"
  l2_token="$(json_value "$BRIDGE_PLAN_FILE" "$l2_key")"

  if ! contract_has_code "$BASE_RPC_URL" "$l2_token"; then
    echo "Missing code for $token_key wrapper on Base: $l2_token" >&2
    echo "The current Base fork does not match the bridge artifacts." >&2
    echo "Re-run Stage 2A on this SuperSim instance before testing the relay helper." >&2
    exit 1
  fi
done

if [[ "$DRY_RUN" -eq 0 ]]; then
  cast rpc anvil_impersonateAccount "$ALIASED_L1_MESSENGER" --rpc-url "$BASE_RPC_URL" >/dev/null
  cast rpc anvil_setBalance "$ALIASED_L1_MESSENGER" "$IMPERSONATED_BALANCE_WEI" --rpc-url "$BASE_RPC_URL" >/dev/null
fi

for index in "${!TOKEN_KEYS[@]}"; do
  token_key="${TOKEN_KEYS[$index]}"
  amount_key="${token_key}Amount"
  l1_key="${token_key}L1Token"
  l2_key="${token_key}L2Token"

  amount="$(json_value "$BRIDGE_PLAN_FILE" "$amount_key")"
  l1_token="$(json_value "$BRIDGE_PLAN_FILE" "$l1_key")"
  l2_token="$(json_value "$BRIDGE_PLAN_FILE" "$l2_key")"
  nonce="$(python3 - "$START_NONCE" "$index" <<'PY'
import sys

print(int(sys.argv[1], 0) + int(sys.argv[2], 0))
PY
)"

  balance_before="$(cast_uint_call "$BASE_RPC_URL" "$l2_token" "balanceOf(address)(uint256)" "$RECIPIENT")"

  if python3 - "$balance_before" "$amount" <<'PY'
import sys

balance = int(sys.argv[1], 0)
amount = int(sys.argv[2], 0)
raise SystemExit(0 if balance >= amount else 1)
PY
  then
    echo "Skipping $token_key: recipient already has $balance_before >= $amount"
    continue
  fi

  finalize_message="$(cast calldata "finalizeBridgeERC20(address,address,address,address,uint256,bytes)" "$l2_token" "$l1_token" "$RECIPIENT" "$RECIPIENT" "$amount" 0x)"

  echo "Relaying $token_key"
  echo "  nonce:      $nonce"
  echo "  l1 token:   $l1_token"
  echo "  l2 token:   $l2_token"
  echo "  amount:     $amount"
  echo "  prebalance: $balance_before"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    cast send "$L2_CROSS_DOMAIN_MESSENGER" \
      "relayMessage(uint256,address,address,uint256,uint256,bytes)" \
      "$nonce" \
      "$L1_STANDARD_BRIDGE" \
      "$L2_STANDARD_BRIDGE" \
      0 \
      "$MIN_GAS_LIMIT" \
      "$finalize_message" \
      --from "$ALIASED_L1_MESSENGER" \
      --unlocked \
      --rpc-url "$BASE_RPC_URL" \
      >/dev/null

    balance_after="$(cast_uint_call "$BASE_RPC_URL" "$l2_token" "balanceOf(address)(uint256)" "$RECIPIENT")"
    echo "  postbalance: $balance_after"
  fi
done

echo "Done. If these relays succeeded, continue with Stage 3 on Base."