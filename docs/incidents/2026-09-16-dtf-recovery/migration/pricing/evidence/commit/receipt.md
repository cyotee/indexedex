# Bounded pricing increment commit receipt

Date: 2026-11-10.

## Commit

- Branch: `work/dtf-migration-phase-02`
- Commit: `215c2bba6aa75e3e79bf68b7980b730927a85817`
- Subject: `Add frozen Migration quote capture and evaluation`
- Parent/base: `90ff0307a7a8e084aa073e02eff125e9c7973933`
- Scope: exactly 19 paths; no receipt included in the commit.

## Exact committed paths

```text
contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol
contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol
contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol
contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol
contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol
contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol
contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol
contracts/utils/StandardExchangeFrozenQuoteLib.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshotLib.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationSnapshot.sol
contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol
contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol
contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol
docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md
scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol
scripts/recovery/dtf-migration/pricing-local-qa.sh
test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol
test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet_IFacet_Test.t.sol
```

## Source and hash binding

The independent correction-verification report and
`evidence/correction-verification/source-artifact-binding.json` were read.
All manifest-bound source files matched their recorded `current` and `expected`
SHA-256 values at verification time (zero mismatches). The corrected QA script
`scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol` supersedes
its entry in the original implementation manifest. The CLI guard helper
`scripts/recovery/dtf-migration/pricing-local-qa.sh` is new; both files use the
independent correction verifier's applicable hash bindings.

The independent correction report confirms F1/F2. The prior independent
verification report records the bounded source behavior and 111 passing
regression tests. These checks do not close full task-2/E3 or lifecycle work.

## Commit checks

- Initial index was empty.
- `git diff --check --ignore-submodules=all`: passed before staging.
- Staged and committed path inventory: exactly the 19 paths listed above;
  staged diff check passed.
- Commit parent equals the specified original base.
- No build or tests were rerun, as instructed; prior independent reports were
  relied on.
- No push, merge, rebase, amend, reset, or checkout restoration was performed.

## Preserved untracked evidence

The commit-time scoped status reported 207 untracked files, all preserved.
This includes the copied incident inputs at
`docs/incidents/2026-09-16-dtf-recovery/` and the pricing evidence trees:
`migration/pricing/evidence/baseline/`,
`migration/pricing/evidence/correction/`,
`migration/pricing/evidence/correction-verification/`,
`migration/pricing/evidence/implementation/`, and
`migration/pricing/evidence/verification/`.
The shared Crane symlink discrepancy was not modified.

## DoneClaim

The bounded direct-pair / recognized ordinary V3-deposit / raw-DETF-output
pricing increment is committed and its source binding and independent
verification are recorded. This does not claim completion of full Migration,
task 2/E3, or lifecycle integration.
