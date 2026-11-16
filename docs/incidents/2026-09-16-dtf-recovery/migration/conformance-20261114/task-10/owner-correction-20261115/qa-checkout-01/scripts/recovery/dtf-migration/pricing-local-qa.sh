#!/usr/bin/env bash
set -euo pipefail

# Called by vm.ffi: PPID is the executing Forge, not a caller-supplied assertion.
# Restrict the whole CLI so duplicate RPC flags, resume, signer overrides and
# alternate targets cannot bypass the endpoint/sender contract. No launcher and
# no fork selection are involved; the documented direct Forge command is used.
[[ $# -eq 0 ]] || { printf 'local QA guard accepts no arguments\n' >&2; exit 1; }
parent=$(/bin/ps -ww -p "$PPID" -o command=)
executable=${parent%% *}
expected='script --use solar scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol:MigrationSnapshotLocalQA --rpc-url http://127.0.0.1:18546 --broadcast --unlocked --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'
if [[ ${executable##*/} != forge || ${parent#* } != "$expected" ]]; then
    printf 'local QA requires exact Forge CLI: forge %s\n' "$expected" >&2
    exit 1
fi
printf '0x01'
