#!/bin/bash
set -u
set -C
cd /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 || exit 98
export LC_ALL=C
recorder=docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/prepared-census/record.sh
overall=0
bash "$recorder" attempt-09-full-tests bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts || overall=1
bash "$recorder" attempt-10-operator-types bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts || overall=1
bash "$recorder" attempt-11-helper-types bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts || overall=1
printf '%s\n' "$overall" > 'docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/prepared-census/combined.exit.txt'
printf "PREPARED_CENSUS_COMBINED exit=%s\n" "$overall"
exit "$overall"
