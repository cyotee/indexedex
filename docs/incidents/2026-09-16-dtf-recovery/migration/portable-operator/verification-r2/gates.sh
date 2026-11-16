#!/bin/bash
set -euo pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-26-portable-operator
E="$PWD/docs/incidents/2026-09-16-dtf-recovery/migration/portable-operator/verification-r2"
P="$PWD/docs/incidents/2026-09-16-dtf-recovery/migration/portable-operator/implementation"
export GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat PAGER=cat
export PATH="$HOME/.foundry/bin:$PATH"
export FORGE_BIN="$HOME/.foundry/bin/forge" ANVIL_BIN="$HOME/.foundry/bin/anvil"
bun --version
forge --version
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext \
  --moduleResolution Bundler --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node \
  scripts/recovery/dtf-migration/*.ts "$P"/*.ts "$P"/probe/*.ts 2>&1 | tee "$E/types.log"
printf 'VERIFIER_TYPES_EXIT=0\n'
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts 2>&1 | tee "$E/operator-tests.log"
printf 'VERIFIER_OPERATOR_TESTS_EXIT=0\n'
python3 scripts/forge-artifacts.py build \
  --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol \
  2>&1 | tee "$E/artifacts.log"
printf 'VERIFIER_ARTIFACTS_EXIT=0\n'
forge build --use solar \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol \
  2>&1 | tee "$E/stages.log"
printf 'VERIFIER_STAGES_EXIT=0\n'
bash -n scripts/recovery/dtf-migration/core-local-qa-guard.sh
bash -n scripts/recovery/dtf-migration/pricing-local-qa.sh
git --no-pager diff --check --ignore-submodules=all
git --no-pager diff --cached --exit-code --ignore-submodules=all
printf 'VERIFIER_GATES_COMPLETE\n'
