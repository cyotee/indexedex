# Bounded pricing commit verification

Date: 2026-11-10. **AdversarialVerify: confirmed.**

## Commit identity and exact scope

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02`
- Branch: `work/dtf-migration-phase-02`
- Commit: `215c2bba6aa75e3e79bf68b7980b730927a85817`
- Subject: `Add frozen Migration quote capture and evaluation`
- Parent: `90ff0307a7a8e084aa073e02eff125e9c7973933`, matching the required original base.
- `git diff-tree --no-commit-id --name-only -r 215c2bba6aa75e3e79bf68b7980b730927a85817` returned exactly the following 19 paths; they match the authorized path set:

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

## Byte and integrity checks

`git diff --exit-code --ignore-submodules=all 215c2bba6aa75e3e79bf68b7980b730927a85817 -- <commit-paths>` exited 0: current tracked file contents for all 19 paths exactly match their committed blobs.

The independent correction verifier's `source-artifact-binding.json` was used as the hash authority. SHA-256 of every manifest-bound committed source matched its declared `expected` value. The applicable superseding `guardHashes` also matched current bytes:

| Path | SHA-256 |
| --- | --- |
| `scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol` | `835f94e84920865b29b4236be04020cf3bf54a4dbc0834bb2e7c30b0bc20f037` |
| `scripts/recovery/dtf-migration/pricing-local-qa.sh` | `29de90e5b906195447f7fab8ca9f64f5430d6341687ce5142c9314e9aff17f76` |
| `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` | `629feb9a4f1452f0209a9f0dd4647673209eae52c67e6c1f6f358ad48bb24b8d` |

The QA script hash is the correction verifier's declared superseding hash, not the earlier implementation-manifest value. No mismatch was observed.

## Message and worktree state

`git show -s --format=fuller` identifies commit `215c2bba6aa75e3e79bf68b7980b730927a85817` with the bounded frozen Migration quote capture/evaluation subject. The message contains exactly one required trailer:

```text
Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
```

`git diff --cached --name-status --ignore-submodules=all` and `git diff --name-status --ignore-submodules=all` were empty; both index and tracked worktree are clean. Status with `--ignore-submodules=all` shows the copied incident materials and pricing evidence as untracked, not part of the commit. These were preserved; this verification did not stage or modify them.

The shared Crane discrepancy remains untouched: the worktree's `lib/crane` symlink resolves to `/Users/cyotee/Projects/indexedex/lib/crane`, while `git ls-tree HEAD lib/crane` records gitlink commit `fc0618bf5c34d0564f4367130feff443bd4efc89`. This pre-existing shared dependency arrangement was excluded from scope comparisons with `--ignore-submodules=all`.

## Verification provenance and limits

No tests, builds, installs, or runtime processes were started for this commit verification. The existing bounded-pricing report records the actual 111-test regression pass, and its exact-signature receipt records `1 passed, 0 failed, 0 skipped` for the named real-proxy case. The independent F1/F2 correction report and its preservation ledger were read: the ledger records 5,351 preserved source/historical files and 210 pre-existing evidence files, with zero preservation, evidence, or binding failures. These are cited prior receipts, not new executions here.

The correction report confirms only F1/F2. Full task-2/E3 and Migration lifecycle work remain open; this commit verdict does not upgrade those scopes or claim their acceptance. No push, merge, cherry-pick, rebase, amend, reset, checkout restoration, source/evidence edit, or index change was performed. No runtime resources were created, so none required cleanup.
