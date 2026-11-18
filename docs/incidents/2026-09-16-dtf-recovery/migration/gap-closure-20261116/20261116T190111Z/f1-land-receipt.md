# F1 worker receipt

Source: isolated worker st_01a1e5be, applied to the integration working tree with git apply. No commit.

Command:
python3 scripts/forge-artifacts.py test contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationMaintenanceFacet.sol contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDonationRemainder.t.sol --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationCore.t.sol --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationGenesisCapital.t.sol --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHostileContribution.t.sol --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol -- -vvv

Worker result: 39 tests passed, 0 failed, 0 skipped. Log copied to c2-f1-worker.log.
Fork witness authored in MigrationRecoveryDonation.t.sol and not run in this hermetic command.
This is prior-to-integration evidence. The official C2 rerun happens after F3 and P1 also land.
