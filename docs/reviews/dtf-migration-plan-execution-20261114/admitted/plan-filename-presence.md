# Plan filename presence index

This index is coordinator-supplied. It is not a finding, not a coverage claim, and not authority. Re-read every path before using a row. A present file does not show that a requirement was met. An absent exact name does not show that the behavior is missing.

Search date: 2026-11-14. Tracked presence is `git ls-files`. The required diff is `90ff0307a7a8e084aa073e02eff125e9c7973933..c33f70683cbaabfedc2dbce1142fdd65660d4cf3`.

## Section 4 component names

| Planned name | Tracked path found |
| --- | --- |
| `interfaces/IUniswapV4DetfMigration.sol` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol` |
| `interfaces/IUniswapV4DetfMigrationDFPkg.sol` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol` |
| `UniswapV4DetfMigrationRepo.sol` | present under the migration directory |
| `UniswapV4DetfMigrationAllocationTarget.sol` / `Facet.sol` | both present |
| `UniswapV4DetfMigrationTarget.sol` / `Facet.sol` | both present |
| `UniswapV4DetfMigrationSnapshotLib.sol` | present |
| `UniswapV4DetfMigrationDFPkg.sol` | present |
| component and package factory services | both present |
| bond NFT target, facet, package, and interface | present under `migration/bondNft/` |
| source adapters under `migration/legacy/` | `IMigrationLegacyNft.sol`, `IMigrationLegacyRecovery.sol`, `MigrationLegacyNftLib.sol`, `MigrationLegacyRecoveryLib.sol` |
| `TestBase_UniswapV4DetfMigration.sol` | present |
| `TestBase_UniswapV4DetfMigration_Adversarial.sol` | no tracked or working-tree file with this exact name |

The diff also contains migration files the section 4 table does not name, including policy, recovery, query, exchange, maintenance, claim-vault allocation, SY, reward-token, and claim-token files. Those are extra surfaces to read, not substitutes for an unread requirement.

## Task evidence names

| Plan evidence name | Exact tracked migration path |
| --- | --- |
| `migration/source-manifest.json` | none. Other `source-manifest.json` files exist under unrelated audit trees. Untracked copies under `.omo/ulw-execute/dtf-migration/` are outside the required diff and are not this file. |
| `migration/source-route-matrix.md` | none |
| `migration/surrender-spec.md` | none |
| `migration/quote-evidence.md` | `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` |
| `migration/package-evidence.md` | none |
| `migration/operator-runbook.md` | `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md` |
| `migration/verification.md` | none. Skill files named `source-verification.md` are not this file. |

## Section 7 QA names

| Plan QA name | Exact test filename in the diff |
| --- | --- |
| `MigrationLegacySources` | `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol` |
| `MigrationSnapshot` | no exact name. `UniswapV4DetfMigrationSnapshot.t.sol` is present. |
| `MigrationDeploy` | no exact name |
| `MigrationFunding` | no exact name |
| `MigrationConfiguration` | no exact name. Several `Migration*Configuration.t.sol` files are present. |
| `MigrationBonds` | no exact name |
| `MigrationRewardGates` | no exact name |
| `MigrationSurrender` | no exact name |
| `MigrationActivation` | no exact name |
| `MigrationSurface` | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol` |
| `MigrationHarvest` | no exact name. `MigrationRecovery.t.sol` and several `MigrationRecovery*.t.sol` fork files are present. |

## Not a completion judgment

The coordinator's read of the plan showed tasks 1-10 and F1-F4 still unchecked. Re-read the plan. Checkbox state is not the section 11 completion standard.
