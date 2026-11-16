#!/usr/bin/env bash
# =============================================================================
# Verify IndexedEx architecture contracts on Robinhood Chain mainnet (4663).
#
# Explorer is Blockscout, not Etherscan:
#   https://robinhoodchain.blockscout.com
# Official Foundry verify (no API key):
#   https://docs.robinhood.com/chain/deploy-smart-contracts
#   https://docs.blockscout.com/devs/verification/foundry-verification
#
# Usage:
#   bash scripts/shell/verify_robinhood_main.sh --dry-run
#   bash scripts/shell/verify_robinhood_main.sh
#   bash scripts/shell/verify_robinhood_main.sh --only ERC20Facet
#   bash scripts/shell/verify_robinhood_main.sh --from 10 --limit 5
#
# Env:
#   RPC_URL              default Foundry alias robinhood_mainnet
#   VERIFIER_URL         default https://robinhoodchain.blockscout.com/api?
#                        Foundry requires the trailing '?' so query params attach
#                        to /api, not to a path that returns explorer HTML.
#   VERIFIER_API_KEY     optional; not required for a single verify
#   DEPLOYMENTS_DIR      default deployments/anvil_robinhood_main
#   VERIFY_SLEEP         seconds between submits (default 20)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INVENTORY_PY="$SCRIPT_DIR/lib/rh_4663_verify_inventory.py"

CHAIN_ID="${CHAIN_ID:-4663}"
VERIFIER="${VERIFIER:-blockscout}"
VERIFIER_URL="${VERIFIER_URL:-https://robinhoodchain.blockscout.com/api?}"
EXPLORER_URL="${EXPLORER_URL:-https://robinhoodchain.blockscout.com}"
DEPLOYMENTS_DIR="${DEPLOYMENTS_DIR:-deployments/anvil_robinhood_main}"
VERIFY_SLEEP="${VERIFY_SLEEP:-20}"
COMPILER_VERSION="${COMPILER_VERSION:-0.8.35}"
OPTIMIZER_RUNS="${OPTIMIZER_RUNS:-1}"

DRY_RUN=0
SKIP_VERIFIED=1
WATCH=0
FROM_INDEX=0
LIMIT=0
ONLY_NAME=""
CONTINUE_ON_ERROR=1
ONCHAIN=0

log_info() { printf '[INFO] %s\n' "$1"; }
log_warn() { printf '[WARN] %s\n' "$1" >&2; }
log_error() { printf '[ERROR] %s\n' "$1" >&2; }
log_ok() { printf '[OK] %s\n' "$1"; }
log_header() {
  echo ""
  echo "============================================================================="
  echo " $1"
  echo "============================================================================="
}

usage() {
  cat <<EOF
Verify IndexedEx contracts deployed by scripts/foundry/anvil_robinhood_main
on Robinhood Chain mainnet (chain id 4663) against Blockscout.

  bash scripts/shell/verify_robinhood_main.sh [options]

Options:
  --dry-run            Print the inventory; do not submit verification
  --watch / --no-watch Wait for each Blockscout result (default: --no-watch)
  --skip-verified      Skip addresses already verified on Blockscout (default)
  --resubmit           Do not skip already-verified addresses
  --only NAME          Verify only this contract name
  --from N             Skip the first N inventory rows (0-based)
  --limit N            Verify at most N rows
  --rpc-url URL        Override RPC
  --sleep N            Pause N seconds between submits (default ${VERIFY_SLEEP})
  --onchain            Also read CREATE3 facet/package registries (needs a
                       non-rate-limited RPC; public RH RPC often times out)
  --help, -h

What you need:
  1. This repo, with the 4663 broadcast logs and
     ${DEPLOYMENTS_DIR}/platform.json from the public deploy.
  2. Foundry (forge, cast). Compiler is solc ${COMPILER_VERSION},
     optimizer runs ${OPTIMIZER_RUNS} (foundry.toml). via_ir is off.
  3. An RPC for chain 4663. Public:
       https://rpc.mainnet.chain.robinhood.com
     Alchemy is better if the public endpoint rate-limits:
       https://docs.robinhood.com/chain/connecting
  4. No Blockscout API key for verification. Robinhood's own docs and
     Blockscout's Foundry page both submit with --verifier blockscout
     and no key. Hardhat configs use apiKey: "empty".
     Optional: VERIFIER_API_KEY only if this Blockscout instance starts
     requiring one. A Blockscout PRO key from https://dev.blockscout.com
     is for api.blockscout.com reads, not for forge verify-contract.
  5. Patience on first compile. A cold forge in this monorepo often takes
     20-40+ minutes with little output. Do not kill it.

Pins (Permit2, WETH, Uni V4 cores, Morpho) are skipped: those are not
IndexedEx bytecode.

After a green verify, the contract page is:
  ${EXPLORER_URL}/address/<address>
EOF
}

resolve_foundry_rpc_alias() {
  local alias_name="$1"
  local template resolved
  template="$(cd "$REPO_ROOT" && forge config --json | python3 -c 'import json,sys; print(json.load(sys.stdin).get("rpc_endpoints",{}).get(sys.argv[1],""))' "$alias_name")"
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --watch) WATCH=1; shift ;;
    --no-watch) WATCH=0; shift ;;
    --skip-verified) SKIP_VERIFIED=1; shift ;;
    --resubmit) SKIP_VERIFIED=0; shift ;;
    --only) ONLY_NAME="${2:-}"; shift 2 ;;
    --from) FROM_INDEX="${2:-0}"; shift 2 ;;
    --limit) LIMIT="${2:-0}"; shift 2 ;;
    --rpc-url) RPC_URL="${2:-}"; shift 2 ;;
    --sleep) VERIFY_SLEEP="${2:-3}"; shift 2 ;;
    --onchain) ONCHAIN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      log_error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${RPC_URL:-}" ]]; then
  if RPC_URL="$(resolve_foundry_rpc_alias robinhood_mainnet)"; then
    :
  else
    RPC_URL="https://rpc.mainnet.chain.robinhood.com"
  fi
fi
export RPC_URL

if [[ ! -f "$INVENTORY_PY" ]]; then
  log_error "Missing inventory helper: $INVENTORY_PY"
  exit 1
fi
if [[ ! -f "$REPO_ROOT/$DEPLOYMENTS_DIR/platform.json" ]]; then
  log_error "Missing $DEPLOYMENTS_DIR/platform.json (run Phase 09 or copy the public 4663 artifacts)"
  exit 1
fi

log_header "Robinhood mainnet (4663) Blockscout verification"
log_info "RPC           $RPC_URL"
log_info "Verifier      $VERIFIER $VERIFIER_URL"
log_info "Deployments   $DEPLOYMENTS_DIR"
log_info "API key       ${VERIFIER_API_KEY:+set (optional)}${VERIFIER_API_KEY:-not required}"

TMP_JSON="$(mktemp)"
TMP_SEL="$(mktemp)"
trap 'rm -f "$TMP_JSON" "$TMP_SEL"' EXIT

INVENTORY_RPC=""
if [[ "$ONCHAIN" -eq 1 ]]; then
  INVENTORY_RPC="$RPC_URL"
  log_info "Building inventory from broadcast + stage JSON + CREATE3 registries"
else
  log_info "Building inventory from broadcast + stage JSON (pass --onchain to add CREATE3 registries)"
fi
PYTHONUNBUFFERED=1 python3 "$INVENTORY_PY" \
  --repo "$REPO_ROOT" \
  --deployments "$DEPLOYMENTS_DIR" \
  --chain-id "$CHAIN_ID" \
  --rpc-url "$INVENTORY_RPC" \
  >"$TMP_JSON"

TOTAL="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$TMP_JSON")"
log_info "Inventory rows: $TOTAL"

python3 - "$TMP_JSON" "$TMP_SEL" "$ONLY_NAME" "$FROM_INDEX" "$LIMIT" "$DRY_RUN" <<'PY'
import json, sys
src, dest, only, frm, limit, dry = sys.argv[1:7]
frm, limit, dry = int(frm), int(limit), dry == "1"
rows = json.load(open(src))
raw_n = len(rows)
if only:
    rows = [r for r in rows if r.get("name") == only]
rows = rows[frm:]
if limit > 0:
    rows = rows[:limit]
json.dump(rows, open(dest, "w"), indent=2)
print(f"{'kind':<16} {'name':<72} {'address'}")
print("-" * 130)
for r in rows:
    print(f"{r.get('kind',''):<16} {r.get('name',''):<72} {r.get('address','')}")
    if dry:
        p = r.get("path") or "(no source path)"
        print(f"{'':16} {p}")
print(f"\nselected {len(rows)} / inventory {raw_n}")
PY

if [[ "$DRY_RUN" -eq 1 ]]; then
  log_ok "Dry run only. Re-run without --dry-run to submit to Blockscout."
  exit 0
fi

blockscout_verified() {
  local addr="$1"
  local body
  body="$(curl -fsS --max-time 20 \
    "${VERIFIER_URL}?module=contract&action=getsourcecode&address=${addr}" 2>/dev/null || true)"
  if [[ -z "$body" ]]; then
    return 1
  fi
  python3 -c '
import json,sys
raw=sys.stdin.read()
try:
    data=json.loads(raw)
except Exception:
    sys.exit(1)
result=data.get("result")
if isinstance(result, list) and result:
    src=result[0].get("SourceCode") or ""
    sys.exit(0 if src not in ("", "0x") else 1)
if isinstance(result, dict):
    src=result.get("SourceCode") or ""
    sys.exit(0 if src not in ("", "0x") else 1)
sys.exit(1)
' <<<"$body"
}

verify_one() {
  local addr="$1"
  local name="$2"
  local rel="$3"
  local ctor="$4"
  local ident="$name"
  if [[ -n "$rel" && "$rel" != "null" ]]; then
    ident="${rel}:${name}"
  fi
  # Do not pass --guess-constructor-args. CREATE3 creation data is not in
  # Blockscout's Etherscan-compat API; Foundry then errors with
  # "Response result is unexpectedly empty: status=1, message=OK".
  # Foundry's Blockscout URL must end with "api?" so module/action query
  # params attach. "/api/" returns explorer HTML.
  local cmd=(
    forge verify-contract
    "$addr"
    "$ident"
    --chain "$CHAIN_ID"
    --rpc-url "$RPC_URL"
    --verifier "$VERIFIER"
    --verifier-url "$VERIFIER_URL"
    --compiler-version "$COMPILER_VERSION"
    --num-of-optimizations "$OPTIMIZER_RUNS"
    --skip-is-verified-check
  )
  if [[ -n "$ctor" && "$ctor" != "0x" && "$ctor" != "null" ]]; then
    cmd+=(--constructor-args "$ctor")
  fi
  if [[ -n "${VERIFIER_API_KEY:-}" ]]; then
    cmd+=(--verifier-api-key "$VERIFIER_API_KEY")
  fi
  if [[ "$WATCH" -eq 1 ]]; then
    cmd+=(--watch)
  fi
  (
    cd "$REPO_ROOT"
    "${cmd[@]}"
  )
}

ok=0
skipped=0
failed=0
missing=0

while IFS=$'\t' read -r addr name rel ctor; do
  [[ -z "$addr" ]] && continue
  if [[ -z "$rel" ]]; then
    log_warn "No source path for $name at $addr"
    missing=$((missing + 1))
    continue
  fi
  if [[ "$SKIP_VERIFIED" -eq 1 ]] && blockscout_verified "$addr"; then
    log_ok "Already verified $name $addr"
    skipped=$((skipped + 1))
    continue
  fi
  log_header "Verify $name"
  log_info "$addr"
  log_info "$EXPLORER_URL/address/$addr"
  set +e
  verify_one "$addr" "$name" "$rel" "$ctor"
  st=$?
  set -e
  if [[ "$st" -eq 0 ]]; then
    log_ok "$name"
    ok=$((ok + 1))
  else
    log_error "Failed $name $addr (exit $st)"
    failed=$((failed + 1))
    if [[ "$CONTINUE_ON_ERROR" -ne 1 ]]; then
      exit "$st"
    fi
  fi
  if [[ "$VERIFY_SLEEP" != "0" ]]; then
    sleep "$VERIFY_SLEEP"
  fi
done < <(python3 -c 'import json,sys; [print("{address}\t{name}\t{path}\t{ctor}".format(address=r["address"], name=r["name"], path=r.get("path") or "", ctor=r.get("constructorArgs") or "")) for r in json.load(open(sys.argv[1]))]' "$TMP_SEL")

log_header "Done"
log_info "Verified $ok  skipped $skipped  failed $failed  missing-source $missing"
log_info "Explorer $EXPLORER_URL"
log_info "Submitted from $DEPLOYMENTS_DIR + broadcast/Phase_*/$CHAIN_ID"
log_info "Re-run with --skip-verified (default) to finish remaining addresses."
