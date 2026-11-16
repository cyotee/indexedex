#!/bin/zsh
set -euo pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid
export PATH="/Users/cyotee/.foundry/bin:$PATH"
e=docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/implementation
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts 2>&1 | tee "$e/types-final.log"
printf 'PASS types\n'
bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution.test.ts ./scripts/recovery/dtf-migration/weighted-liquid.test.ts ./scripts/recovery/dtf-migration/weighted-sy.test.ts ./scripts/recovery/dtf-migration/dtf-custody-se.test.ts ./scripts/recovery/dtf-migration/claim-vault.test.ts ./scripts/recovery/dtf-migration/weighted-receipt.test.ts ./scripts/recovery/dtf-migration/earlier-receipt.test.ts ./scripts/recovery/dtf-migration/earlier-liquid.test.ts 2>&1 | tee "$e/operator-tests-final.log"
printf 'PASS operator-tests\n'
bun scripts/recovery/dtf-migration/cli.ts rehearse --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18569 --checkpoint .omo-runtime/dtf-migration-earlier-liquid/checkpoints --evidence "$e/runtime-01" 2>&1 | tee "$e/cli-01.log"
printf 'PASS cli\n'
rmdir .omo-runtime/dtf-migration-earlier-liquid
printf 'PASS empty-runtime-parent-cleanup\n'
