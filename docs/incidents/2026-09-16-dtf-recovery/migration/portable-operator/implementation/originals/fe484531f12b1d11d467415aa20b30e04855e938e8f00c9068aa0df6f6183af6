#!/usr/bin/env bash
set -euo pipefail

# The shell's forge function passes its actual argv here. Reject before any RPC
# or broadcast if that argv selects anything except this task's owned endpoint.
rpc=
rpc_count=0
previous=
for argument in "$@"; do
    if [[ "$previous" == --rpc-url || "$previous" == -r ]]; then
        rpc=$argument
        rpc_count=$((rpc_count + 1))
    elif [[ "$argument" == --rpc-url=* ]]; then
        rpc=${argument#--rpc-url=}
        rpc_count=$((rpc_count + 1))
    fi
    previous=$argument
done
if [[ "$rpc_count" != 1 || "$rpc" != http://127.0.0.1:18548 ]]; then
    printf '%s\n' 'MIGRATION_QA_ENDPOINT_REJECTED: require the actual CLI endpoint http://127.0.0.1:18548' >&2
    exit 64
fi
if [[ -z "${MIGRATION_NODE_INSTANCE:-}" || -z "${MIGRATION_FOUNDRY_BIN:-}" ]]; then
    printf '%s\n' 'MIGRATION_QA_OWNERSHIP_REQUIRED: bind the owned Anvil instance and selected Foundry directory' >&2
    exit 65
fi
chain=$("$MIGRATION_FOUNDRY_BIN/cast" chain-id --rpc-url "$rpc")
client=$("$MIGRATION_FOUNDRY_BIN/cast" rpc web3_clientVersion --rpc-url "$rpc")
instance=$("$MIGRATION_FOUNDRY_BIN/cast" rpc anvil_metadata --rpc-url "$rpc" | jq -r '.instanceId')
if [[ "$chain" != 31337 || "$client" != *anvil* || "$instance" != "$MIGRATION_NODE_INSTANCE" ]]; then
    printf '%s\n' 'MIGRATION_QA_NODE_REJECTED: endpoint is not the captured owned Anvil instance' >&2
    exit 66
fi
printf 'MIGRATION_QA_BOUND rpc=%s chain=%s instance=%s forge=%s\n' \
    "$rpc" "$chain" "$instance" "$MIGRATION_FOUNDRY_BIN/forge"
exec "$MIGRATION_FOUNDRY_BIN/forge" "$@"
