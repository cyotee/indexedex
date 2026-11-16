#!/bin/zsh
set -euo pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid
export PATH="/Users/cyotee/.foundry/bin:$PATH"
e=docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/implementation
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
python3 scripts/forge-artifacts.py build "${roots[@]}" 2>&1 | tee "$e/build-01.log"
printf 'PASS build\n'
python3 scripts/forge-artifacts.py test "${roots[@]}" --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration 2>&1 | tee "$e/specs-01.log"
printf 'PASS specs\n'
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test "${roots[@]}" --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration 2>&1 | tee "$e/forks-01.log"
printf 'PASS forks\n'
