# Gap-closure baseline

Recorded: 2026-11-16T19:01:11.121Z
Plan: dtf-migration-gap-closure-plan-20261116-final
Git: main @ 42d2efc0d, tree 15c55f7df

This note is an unrepaired-source baseline. No contract, test, or script file was edited to produce it. The gap-closure plan names old 236/183/28,641 results as baseline observations, not expected new totals. This run did not rerun them and does not treat them as repaired-source results. A direct read of verification.md did not show those three figures as a current test-total line; signer 236 there is an operational signer, not that count.

## Gaps still open

- F1: `sweepDust()` still calls `_entrySweepDust()`. The event `MigrationCapitalReleasedToResidual` is not declared. `MigrationDonationRemainder.t.sol` does not exist.
- F2: `deployAndIssue()` donates 100 ether of each leg, bootstraps 100 ether of each, and does not broadcast a paid owner purchase. The only `_buyOwnerFirstBond` is the internal prank helper at `TestBase_UniswapV4DetfMigration.sol:376`. The public `buyOwnerFirstBond` required by section 2.3 is absent. `MigrationCoreLocalQA.t.sol` does not exist.
- F3: `tokenURI` sets `migrationPresentation` only when the position is a cliff or `tokenId < 3`, and sets `rewardsClosed` only when that presentation flag is set. Section 2.2 requires presentation true for this Migration target and `rewardsClosed = !parent.migrationActivated()` independent of cliff style. Ordinary purchased Migration positions therefore do not yet get the required reward presentation.
- P1: `observedHook` is absent. `MigrationRawWeightedPricing.t.sol` does not exist.
- F4: the five named current documents were not edited. This directory is the new evidence entry.

## Preserved dirty work

`docs/testing/ARTIFACT_BUILDS.md` was already modified and was not touched. Untracked research and review documents were left in place.

## Toolchain

Forge 1.9.0 (`6056c584`, built 2026-11-02) at `~/.foundry/bin/forge`. Solar 0.3.0-dev (`a2b44354`) is on PATH. `foundry.toml` uses `out = 'out'` and `cache_path = 'cache_forge'`, `via_ir = false`, profiles `default` and `fork`. `forge build --help` accepts `--use <SOLC_VERSION>` as a version, path, or executable name. This baseline did not compile, so it does not claim a Solar build.
