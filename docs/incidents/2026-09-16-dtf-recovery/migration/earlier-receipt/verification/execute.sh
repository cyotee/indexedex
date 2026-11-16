#!/bin/zsh
set -euo pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt
export PATH="/Users/cyotee/.foundry/bin:$PATH"
v=docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt/verification
roots=(
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryRepo.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryFacet.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationFacet.sol
)
printf 'BEGIN build\n'
python3 scripts/forge-artifacts.py build "${roots[@]}" 2>&1 | tee "$v/build.log"
printf 'PASS build\nBEGIN specs\n'
python3 scripts/forge-artifacts.py test "${roots[@]}" --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration 2>&1 | tee "$v/specs.log"
printf 'PASS specs\nBEGIN forks\n'
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test "${roots[@]}" --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration 2>&1 | tee "$v/forks.log"
printf 'PASS forks\nBEGIN stages\n'
forge build --use solar scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol 2>&1 | tee "$v/stages.log"
printf 'PASS stages\nBEGIN types\n'
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts 2>&1 | tee "$v/types.log"
printf 'PASS types\nBEGIN operator-tests\n'
bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution.test.ts ./scripts/recovery/dtf-migration/weighted-liquid.test.ts ./scripts/recovery/dtf-migration/weighted-sy.test.ts ./scripts/recovery/dtf-migration/dtf-custody-se.test.ts ./scripts/recovery/dtf-migration/claim-vault.test.ts ./scripts/recovery/dtf-migration/weighted-receipt.test.ts ./scripts/recovery/dtf-migration/earlier-receipt.test.ts 2>&1 | tee "$v/operator-tests.log"
printf 'PASS operator-tests\nBEGIN cli\n'
bun scripts/recovery/dtf-migration/cli.ts rehearse --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18568 --checkpoint .omo-runtime/dtf-migration-earlier-receipt/checkpoints --evidence "$v/runtime-01" 2>&1 | tee "$v/cli.log"
printf 'PASS cli\n'
rmdir .omo-runtime/dtf-migration-earlier-receipt
printf 'PASS empty-runtime-parent-cleanup\n'
