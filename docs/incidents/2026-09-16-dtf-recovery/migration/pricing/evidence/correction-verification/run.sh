#!/usr/bin/env bash
set -uo pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02 || exit 2
export TMPDIR=/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-correction-verification.st01a1c62a
export NODE_COMPILE_CACHE="$TMPDIR/node-cache"
export BUN_RUNTIME_TRANSPILER_CACHE_PATH="$TMPDIR/bun-cache"
export PATH="/Users/cyotee/.foundry/bin:$PATH"
evidence=docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/correction-verification
export FOUNDRY_BROADCAST="$PWD/$evidence/broadcast"
label=$1
shift
[[ ! -e "$evidence/$label-command.txt" ]] || { printf "Refusing receipt overwrite: %s\n" "$label" >&2; exit 2; }
{
    date -u
    printf 'cwd=%s\nTMPDIR=%s\nNODE_COMPILE_CACHE=%s\nBUN_RUNTIME_TRANSPILER_CACHE_PATH=%s\nrecorder_pid=%s\n' \
        "$PWD" "$TMPDIR" "$NODE_COMPILE_CACHE" "$BUN_RUNTIME_TRANSPILER_CACHE_PATH" "$$"
    printf 'PATH=%s\nFOUNDRY_BLOCK_GAS_LIMIT=%s\nFOUNDRY_BROADCAST=%s\n' "$PATH" "${FOUNDRY_BLOCK_GAS_LIMIT-unset}" "$FOUNDRY_BROADCAST"
    printf '%q ' "$@"
    printf '\n'
} > "$evidence/$label-command.txt"
"$@" 2>&1 | tee "$evidence/$label.log"
codes=("${PIPESTATUS[@]}")
{
    printf 'command_exit=%s\ntee_exit=%s\n' "${codes[0]}" "${codes[1]}"
    date -u
} > "$evidence/$label-exit.txt"
printf 'CORRECTION_VERIFY_DONE %s command_exit=%s tee_exit=%s\n' "$label" "${codes[0]}" "${codes[1]}"
if [ "${codes[0]}" -ne 0 ]; then exit "${codes[0]}"; fi
exit "${codes[1]}"
