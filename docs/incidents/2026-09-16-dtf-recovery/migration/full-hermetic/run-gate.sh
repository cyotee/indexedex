#!/bin/bash
set -euo pipefail
cd '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic'
export GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0
test "$(git rev-parse HEAD)" = 8db3f5ee6310e8a700dad2d6a33e21d0955e63ca
git diff --ignore-submodules=all --exit-code
git diff --cached --ignore-submodules=all --exit-code
test ! -e .env
printf "HERMETIC_PROFILE=%s RPC_CREDENTIALS=not-forwarded\n" "$FOUNDRY_PROFILE"
run_gate() {
  local name="$1" logfile="$2"
  shift 2
  local -a statuses
  printf "HERMETIC_%s_STARTED\n" "$name"
  set +e
  "$@" 2>&1 | tee "$logfile"
  statuses=("${PIPESTATUS[@]}")
  set -e
  printf "HERMETIC_%s_EXIT=%s CAPTURE_EXIT=%s\n" "$name" "${statuses[0]}" "${statuses[1]}"
  if [ "${statuses[0]}" -ne 0 ] || [ "${statuses[1]}" -ne 0 ]; then return 1; fi
}
run_gate VERSION '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic/docs/incidents/2026-09-16-dtf-recovery/migration/full-hermetic/forge-version.log' forge --version
run_gate BUILD '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic/docs/incidents/2026-09-16-dtf-recovery/migration/full-hermetic/build.log' forge build --use solar
run_gate ARTIFACTS '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic/docs/incidents/2026-09-16-dtf-recovery/migration/full-hermetic/runtime-artifacts.log' python3 scripts/forge-artifacts.py build --all-artifacts
run_gate TEST '/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic/docs/incidents/2026-09-16-dtf-recovery/migration/full-hermetic/tests.log' env -u FOUNDRY_ETH_RPC_URL -u ETH_RPC_URL forge test --use solar -vv --no-match-path '**/fork/**' --no-match-contract Fork
printf "FULL_HERMETIC_GATE_COMPLETE\n"
