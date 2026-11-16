#!/bin/zsh
set -euo pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid
export PATH="/Users/cyotee/.foundry/bin:$PATH"
e=docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/verification
m=contracts/vaults/detf/protocols/dexes/uniswap/v4/migration
roots=(
"$m/interfaces/IUniswapV4DetfMigration.sol"
"$m/UniswapV4DetfMigrationRepo.sol"
"$m/UniswapV4DetfMigrationRecoveryTarget.sol"
"$m/UniswapV4DetfMigrationRecoveryFacet.sol"
"$m/UniswapV4DetfMigrationAllocationTarget.sol"
"$m/UniswapV4DetfMigrationAllocationFacet.sol"
"$m/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol"
"$m/UniswapV4DetfMigrationClaimVaultAllocationFacet.sol"
)
python3 scripts/forge-artifacts.py build "${roots[@]}" 2>&1 | tee "$e/build.log"
printf 'PASS independent-build\n'
python3 scripts/forge-artifacts.py test "${roots[@]}" --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration 2>&1 | tee "$e/specs.log"
printf 'PASS independent-specs\n'
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test "${roots[@]}" --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration 2>&1 | tee "$e/forks.log"
printf 'PASS independent-forks\n'
forge build --use solar scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol 2>&1 | tee "$e/stages.log"
printf 'PASS independent-stages\n'
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts 2>&1 | tee "$e/types.log"
printf 'PASS independent-types\n'
bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution.test.ts ./scripts/recovery/dtf-migration/weighted-liquid.test.ts ./scripts/recovery/dtf-migration/weighted-sy.test.ts ./scripts/recovery/dtf-migration/dtf-custody-se.test.ts ./scripts/recovery/dtf-migration/claim-vault.test.ts ./scripts/recovery/dtf-migration/weighted-receipt.test.ts ./scripts/recovery/dtf-migration/earlier-receipt.test.ts ./scripts/recovery/dtf-migration/earlier-liquid.test.ts 2>&1 | tee "$e/operator-tests.log"
printf 'PASS independent-operator-tests\n'
bun scripts/recovery/dtf-migration/cli.ts rehearse --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18569 --checkpoint .omo-runtime/dtf-migration-earlier-liquid/checkpoints --evidence "$e/runtime-01" 2>&1 | tee "$e/cli.log"
printf 'PASS independent-cli\n'
rmdir .omo-runtime/dtf-migration-earlier-liquid
printf 'PASS independent-runtime-parent-cleanup\n'
