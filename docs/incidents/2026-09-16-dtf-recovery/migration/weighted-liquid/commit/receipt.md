# Verified bounded Stage2 surrender and owner-first bond local source delivery

Date: 2026-11-11. Status: **complete for local source delivery only**.

## Exact local commit

- Commit: `75d513cb8b36e53f14c8aa3a352f21703ad91ba1`
- Subject: `Add verified bounded Stage2 surrender and owner-first bond`
- Parent: `2c2b3370ded30cae1662329025d4fb58f7197330`
- Branch: `work/dtf-migration-phase-13-weighted-liquid`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-13-weighted-liquid`
- Exactly **54 source/test/operator/runbook paths**, 2093 insertions and 140 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`.
- Exactly one commit after the required parent. No push, PR, merge, public action or source fix.
- The source commit deliberately excludes this manifest/receipt and all other evidence/generated artifacts. Evidence remains local and uncommitted.

## Source provenance

`source-manifest.json` binds every candidate path, mode, accepted SHA-256, current SHA-256, Git blob, parent blob and provenance. The candidate set was derived from the independent verifier's 54 `sourceFiles` bindings and the actual parent/index/worktree diff, not from a directory listing or a stale count. All 54 current bytes match both the verifier `finalSha256` and the producer SHA-256. There is no post-runtime hash exception.

Historical runtime evidence records bytes, not file modes. Every tracked parent/index mode is `100644`. All eight new files are regular files with no executable bit and were committed as `100644`. Committed blobs, current bytes and accepted SHA-256 values match for all 54 paths.

Independent acceptance is the complete `owner-bond-verification/report.md`, raw SHA-256 `6f2b72c1a50919171790459be6699ce26fefdb4bdc09a2f577f9c01ba3fc365d`, disposition confirmed. Bound inputs matched: plan r5 `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d`, PRD r22 `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed`, owner-first-bond correction `29dca72edabe86612e98665a941d1f621cb7184e707bbfa841385fa779ccfb92`, producer report `b0aec1774148f103a8d2b6e265b3d3edc0de5a59ca20ed5fc7fa5eebe0f905e8`, producer bindings `8e801d24e1b9c87c60b68dabe9801fb77a65759b54be76dcab545f7e9f7f2687`.

## Verification performed here

- Read the complete commit brief, owner-first-bond correction, plan r5 section 1.5, PRD r22 section 1.2, and the complete independent verification report. Verified the report hash, branch, parent `2c2b3370ded30cae1662329025d4fb58f7197330`, empty incoming staged set, and recent one-line commit convention. No upstream is configured; no fetch or push was attempted.
- Read the entire 54-file candidate diff. URL/signing-material inspection found only loopback templates and `https://example.invalid`. `PRIVATE_KEY` is deleted from the forge environment. The Anvil comment does not embed mnemonic words or a private key. No resolved secret endpoint or signing material is in the candidate.
- Staged the 54 exact paths only. Staged modes/blobs matched the manifest. The staged diff body matched the already reviewed diff. `git diff --check` exited 0 before and after the commit.
- After the commit, `HEAD^`, one-child count, subject, exactly one coauthor trailer, `diff-tree` path set, and each committed `ls-tree` mode/blob plus committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the new commit tree.
- Prior independent runtime evidence was corroborated from its sealed report, not rerun: 109 specs, 52 pinned forks, 57 operator tests, both operator-stage builds, strict TypeScript, the fixed18563 CLI, three mined resumes, source stopped and cleanup complete. No unchanged transaction suite was rerun.

## Preservation

`preservation-baseline.json` and `commit-verification.json` record the before/after checks.

- All **2103 prior weighted-liquid evidence entries** retain identical path/mode/size/mtime/SHA-256 inventories. No historical report, binding, snapshot, witness, log, journal or broadcast was rewritten.
- All **7310 `out/` entries** and **588 `cache_forge/` entries** retain identical path/mode/size/mtime metadata inventories. No build, deletion or cache write was performed.
- `lib/crane` and `node_modules` symlink targets, inode identities and modes are unchanged. No configuration, dependency or link change.
- All refs other than `work/dtf-migration-phase-13-weighted-liquid` remain identical, including main `90ff0307a7a8e084aa073e02eff125e9c7973933`, origin/main, phase12 at the parent, held phase09 `421072a7630a0d3d47a6f36e1062d9eae98c93e2`, and stash. No held phase09 candidate was read, imported, tested or committed.
- The incoming staged set was empty. The final staged set is empty. Non-candidate index entries are unchanged because the index tree matches the new commit and the commit changes only the 54 accepted paths. Only local evidence remains untracked under `docs/incidents/2026-09-16-dtf-recovery/migration/weighted-liquid/`.
- This lane started no node, impersonation, transaction suite, child or monitor. After delivery, port 18563 has no listener (`lsof` exit 1, empty output) and the verifier's Anvil PID 54333 is absent (`ps` exit 1, empty output). Commit and inspection processes completed. **No pending operation.**

## Retained scope limits

This delivers only the bounded Stage2 NFT/W-L surrender and owner-paid first-bond increment. It is not full-category Migration acceptance, not target-gas acceptance, and not public-deployment approval. The independent local parent deployment used 43,263,865 gas and does not meet the retained historical 32,000,000 transaction limit. Operational original-wallet, canonical-origin, Q0 and ETH/DTF contribution records remain required; fixture amounts are synthetic. Other legacy source categories and the earlier sale-and-hold versus liquidation limit remain open. This increment does not authorize resuming the held deployment-gas lane.

## Exact committed path list

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationBondFacet.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationFacet.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol`
- `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md`
- `scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol`
- `scripts/recovery/dtf-migration/cli.ts`
- `scripts/recovery/dtf-migration/execution-owner-bond.ts`
- `scripts/recovery/dtf-migration/execution-plan.ts`
- `scripts/recovery/dtf-migration/execution-schema.ts`
- `scripts/recovery/dtf-migration/execution-state.ts`
- `scripts/recovery/dtf-migration/execution.test.ts`
- `scripts/recovery/dtf-migration/execution.ts`
- `scripts/recovery/dtf-migration/payloads.ts`
- `scripts/recovery/dtf-migration/preparation.fixture.ts`
- `scripts/recovery/dtf-migration/preparation.test.ts`
- `scripts/recovery/dtf-migration/preparation.ts`
- `scripts/recovery/dtf-migration/provenance.ts`
- `scripts/recovery/dtf-migration/quotes.ts`
- `scripts/recovery/dtf-migration/rehearsal-admission.ts`
- `scripts/recovery/dtf-migration/rehearsal-chain.ts`
- `scripts/recovery/dtf-migration/rehearsal-data.ts`
- `scripts/recovery/dtf-migration/rehearsal-owner-bond.ts`
- `scripts/recovery/dtf-migration/rehearsal-proof.ts`
- `scripts/recovery/dtf-migration/rehearsal-recovery.ts`
- `scripts/recovery/dtf-migration/rehearsal-weighted-liquid.ts`
- `scripts/recovery/dtf-migration/rehearse.ts`
- `scripts/recovery/dtf-migration/schema.ts`
- `scripts/recovery/dtf-migration/weighted-liquid.test.ts`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftForkBase.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftLifecycle.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationOriginalWallet.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDonation.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryEarlier.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryForkBase.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryGas.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryWeighted.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedLiquid.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationAdministration.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationCore.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEgress.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftConfiguration.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationOwnerBondCallbacks.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationOwnerFirstBond.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationPermitAndRetirement.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecovery.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRetainedAccounting.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedLiquidConfiguration.t.sol`
