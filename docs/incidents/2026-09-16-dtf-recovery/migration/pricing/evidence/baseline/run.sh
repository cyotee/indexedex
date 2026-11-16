#!/bin/bash
# Evidence-only command recorder. No product or test source mutation.
set -u
set -o pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02 || exit 98
export TMPDIR=/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-baseline.iud2vw
export NODE_COMPILE_CACHE="$TMPDIR/node-compile-cache"
export BUN_RUNTIME_TRANSPILER_CACHE_PATH="$TMPDIR/bun-transpiler-cache"
export PATH="/Users/cyotee/.foundry/bin:$PATH"
export GIT_MASTER=1
E="$PWD/docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/baseline"
case "${1-}" in
    before|after)
        phase="$1"
        {
            date -u '+UTC=%Y-%m-%dT%H:%M:%SZ'
            printf 'CWD=%s\nTMPDIR=%s\nNODE_COMPILE_CACHE=%s\nBUN_RUNTIME_TRANSPILER_CACHE_PATH=%s\n' \
                "$PWD" "$TMPDIR" "$NODE_COMPILE_CACHE" "$BUN_RUNTIME_TRANSPILER_CACHE_PATH"
            printf 'RECORDER_PID=%s\n' "$$"
            git rev-parse HEAD
            git branch --show-current
            git status --porcelain=v1 --untracked-files=all --ignore-submodules=all
            printf 'STATUS_EXIT=%s\n' "$?"
            ls -ld out cache_forge lib/crane node_modules
            readlink lib/crane
            readlink node_modules
        } > "$E/$phase-state.txt" 2>&1
        git diff --binary -- contracts test scripts foundry.toml remappings.txt package.json \
            package-lock.json bun.lock bun.lockb > "$E/$phase-code.diff"
        git ls-files -z -- contracts test scripts foundry.toml remappings.txt package.json \
            package-lock.json bun.lock bun.lockb |
            xargs -0 shasum -a 256 > "$E/$phase-code.sha256"
        printf 'BOUNDARY_CAPTURED=%s\n' "$phase"
        ;;
    versions)
        {
            date -u '+UTC=%Y-%m-%dT%H:%M:%SZ'
            command -v forge
            forge --version
            /opt/homebrew/bin/forge --version
            command -v solar || true
            if command -v solar >/dev/null; then solar --version; fi
            command -v python3
            python3 --version
            /bin/bash --version
            uname -sm
            forge config --json
        } > "$E/toolchain.txt" 2>&1
        printf 'TOOLCHAIN_CAPTURED\n'
        ;;
    build) cmd=(forge build --use solar) ;;
    weighted)
        cmd=(forge test --use solar --match-path \
            test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted.t.sol -vvvv)
        ;;
    nested)
        cmd=(forge test --use solar --match-path \
            test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol -vvvv)
        ;;
    verify-cleanup)
        (
            set -x
            /bin/bash -n "$E/run.sh"
            printf 'RECORDER_SYNTAX_EXIT=%s\n' "$?"
            cmp "$E/before-code.sha256" "$E/after-code.sha256"
            printf 'CODE_MANIFEST_COMPARE_EXIT=%s\n' "$?"
            cmp "$E/before-code.diff" "$E/after-code.diff"
            printf 'CODE_DIFF_COMPARE_EXIT=%s\n' "$?"
            wc -l "$E/before-code.sha256" "$E/after-code.sha256"
            wc -c "$E/before-code.diff" "$E/after-code.diff"
            ps -p 21714,23806,24033 -o pid,ppid,command
            printf 'COMPLETED_COMMAND_RECORDER_PS_EXIT=%s\n' "$?"
            ls -ld "$TMPDIR"
            find "$TMPDIR" -maxdepth 2 -print
            rm -rf -- "$TMPDIR"
            printf 'OWNED_RUNTIME_REMOVE_EXIT=%s\n' "$?"
            test ! -e "$TMPDIR"
            printf 'OWNED_RUNTIME_ABSENT_EXIT=%s\n' "$?"
            ls -ld out cache_forge lib/crane node_modules
            readlink lib/crane
            readlink node_modules
            date -u '+CLEANUP_UTC=%Y-%m-%dT%H:%M:%SZ'
        ) > "$E/boundary-cleanup.txt" 2>&1
        printf 'BOUNDARY_AND_CLEANUP_CAPTURED\n'
        ;;
    *) printf 'Expected before, after, versions, build, weighted, nested or verify-cleanup\n' >&2; exit 97 ;;
esac
if [ "${cmd+x}" = x ]; then
    name="$1"
    {
        date -u '+START_UTC=%Y-%m-%dT%H:%M:%SZ'
        printf 'CWD=%s\nRECORDER_PID=%s\nBINARY=%s\n' "$PWD" "$$" "$(command -v forge)"
        printf 'TMPDIR=%s\nNODE_COMPILE_CACHE=%s\nBUN_RUNTIME_TRANSPILER_CACHE_PATH=%s\n' \
            "$TMPDIR" "$NODE_COMPILE_CACHE" "$BUN_RUNTIME_TRANSPILER_CACHE_PATH"
        printf 'COMMAND='; printf '%q ' "${cmd[@]}"; printf '\n'
    } > "$E/$name-command.txt"
    "${cmd[@]}" 2>&1 | tee "$E/$name.log"
    statuses=("${PIPESTATUS[@]}")
    {
        printf 'COMMAND_EXIT=%s\nTEE_EXIT=%s\n' "${statuses[0]}" "${statuses[1]}"
        date -u '+END_UTC=%Y-%m-%dT%H:%M:%SZ'
    } > "$E/$name-exit.txt"
    printf 'BASELINE_COMMAND_DONE=%s EXIT=%s TEE=%s\n' "$name" "${statuses[0]}" "${statuses[1]}"
    exit "${statuses[0]}"
fi
