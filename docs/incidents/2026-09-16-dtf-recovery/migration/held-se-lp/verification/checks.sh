#!/bin/zsh
set -eu
set -o pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-21-held-se-lp
export PATH="/Users/cyotee/.foundry/bin:$PATH"
evidence=docs/incidents/2026-09-16-dtf-recovery/migration/held-se-lp/verification
roots=(
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationFacet.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryFacet.sol
)
run_check() {
  local name="$1"
  shift
  printf 'START %s\n' "$name"
  "$@" 2>&1 | tee "$evidence/$name.log"
  printf 'PASS %s\n' "$name"
}
run_check build python3 scripts/forge-artifacts.py build "${roots[@]}"
run_check specs python3 scripts/forge-artifacts.py test "${roots[@]}" --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration
run_check forks env FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test "${roots[@]}" --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration
run_check stages forge build --use solar scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol
run_check types bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
run_check operator-tests bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
printf 'ALL_REQUIRED_CHECKS_PASS\n'
