#!/bin/bash
set -euo pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-26-portable-operator
E="$PWD/docs/incidents/2026-09-16-dtf-recovery/migration/portable-operator/verification-r2"
export GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat PAGER=cat
export PATH="$HOME/.foundry/bin:$PATH"
export FORGE_BIN="$HOME/.foundry/bin/forge" ANVIL_BIN="$HOME/.foundry/bin/anvil"
test ! -e .omo-runtime/dtf-migration-portable/checkpoints
if lsof -nP -iTCP:18575 -sTCP:LISTEN; then exit 1; fi
sandbox-exec -f "$E/no-original-inputs.sb" bun "$E/access.ts" | tee "$E/physical-access.log"
printf 'VERIFIER_PHYSICAL_ACCESS_COMPLETE\n'
sandbox-exec -f "$E/no-original-inputs.sb" \
  bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --bundle "$E/authority-b/bundle.json" \
  --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18575 \
  --checkpoint .omo-runtime/dtf-migration-portable/checkpoints \
  --evidence "$E/runtime" 2>&1 | tee "$E/cli.log"
printf 'VERIFIER_RUNTIME_COMPLETE\n'
