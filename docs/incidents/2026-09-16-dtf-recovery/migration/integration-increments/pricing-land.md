# Pricing increment landing receipt

Date: 2026-11-10.

## Branch and integration

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-integration`
- Branch: `work/dtf-migration`
- Expected base and commit parent: `90ff0307a7a8e084aa073e02eff125e9c7973933`
- Landed commit and resulting HEAD: `215c2bba6aa75e3e79bf68b7980b730927a85817`
- Subject: `Add frozen Migration quote capture and evaluation`
- Integration operation: `GIT_MASTER=1 git cherry-pick --ff 215c2bba6aa75e3e79bf68b7980b730927a85817`

The commit has the expected base as its sole parent. This was a direct
fast-forward; no source content was rewritten.

## Exact committed path scope

The commit contains exactly these 19 paths:

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

The preparation commit `6d82859ee0b20804a4ced6e7a5ae395a49f5cdfd` also has
the expected base as its parent and changes exactly five paths. Its committed
path set is disjoint from the pricing commit's 19 paths. The preparation
increment was not applied by this pricing-only landing.

## State and preservation evidence

Before integration, `work/dtf-migration` was at the expected base with an
empty index, no tracked diff, and no untracked files reported by
`git ls-files --others --exclude-standard`. The requested evidence file did
not exist before this operation.

After integration:

- `git show -s` reports HEAD
  `215c2bba6aa75e3e79bf68b7980b730927a85817`, with sole parent
  `90ff0307a7a8e084aa073e02eff125e9c7973933`.
- `git diff-tree --no-commit-id --name-only -r HEAD` reports exactly the 19
  paths listed above.
- `git status --short --ignore-submodules=all`,
  `git diff --stat --ignore-submodules=all`, and
  `git diff --staged --stat --ignore-submodules=all` report no changes.
- `git ls-files --others --exclude-standard` reports zero untracked files.
- `refs/heads/main` remains
  `90ff0307a7a8e084aa073e02eff125e9c7973933`.
- No runtime resources were created.

## Accepted verification evidence and limits

The phase-two commit receipt is
`../phase-02/docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/commit/receipt.md`
in the phase-two worktree. The independent bounded pricing report is
`migration/pricing/evidence/verification/report.md`; it records 111 passing
regression tests and the independently executed exact-signature case, while
its overall verdict was `needs-fix` for findings F1 and F2. The subsequent
`migration/pricing/evidence/correction-verification/report.md` confirms those
two corrections and records a fresh successful local invocation.

These are the accepted prior source-bound passes; tests and builds were not
rerun for this fast-forward. The pricing evidence explicitly leaves full
task-2 / actual-configuration E3 and Migration lifecycle work open. This
landing does not close them or claim combined-increment verification.

## DoneClaim

The independently verified pricing commit
`215c2bba6aa75e3e79bf68b7980b730927a85817` is the exact HEAD of
`work/dtf-migration`, directly on its expected base, with its 19-path scope
preserved, the tracked tree and index clean, no untracked files reported, and
`main` unchanged. No source content was rewritten. This claim is limited to
landing the pricing increment; it is not full Migration, E3, lifecycle, or
combined-increment acceptance.
