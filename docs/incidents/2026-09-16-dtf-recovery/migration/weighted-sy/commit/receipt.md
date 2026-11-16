# Verified bounded weighted SY local source delivery

Date: 2026-11-11. Status: **complete for local source delivery only**.

## Exact local commit

- Commit: `2baab6e58dafcc3fe5f9a94570d99987d58bf42b`
- Subject: `Add verified bounded weighted SY surrender and recovery`
- Parent: `75d513cb8b36e53f14c8aa3a352f21703ad91ba1`
- Tree: `7cce28c369bd5889da9ea10bc8954c07ece0f678`
- Branch: `work/dtf-migration-phase-14-weighted-sy`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-14-weighted-sy`
- Exactly **33 source/test/operator/runbook paths**, 1435 insertions and 54 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`.
- Exactly one commit after the required parent. No push, PR, merge, public action or source fix.
- The source commit deliberately excludes this manifest/receipt and all other evidence/generated artifacts. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `bf1c9538890263aa3b88dcb4f87ad83df06617727542ebd735e6fc299d7f9a19`.

## Source provenance

`source-manifest.json` binds every candidate path, mode, accepted SHA-256, current SHA-256, Git blob, parent blob and provenance. The candidate set was derived from the independent verifier's 33 `sourceFiles` in `source-authority.json` and `bindings.json`, intersected with the actual parent/index/worktree diff, not from a directory listing or a producer pass flag. All 33 current bytes match the verifier admitted SHA-256, the verifier final SHA-256, and the producer source-snapshot SHA-256 and embedded snapshot bytes. There is no post-runtime hash exception.

Historical runtime evidence records bytes, not file modes. Every tracked parent/index mode is `100644`. All five new files are regular files with no executable bit and were committed as `100644`. Committed blobs, current bytes and accepted SHA-256 values match for all 33 paths.

Independent acceptance is the complete `verification/report.md`, raw SHA-256 `a8239596a190ea6f3b236fe8fa55998e06a0bcd1ac34d5040dad5c6d17773f80`, disposition confirmed. Bound inputs matched: plan r5 `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d`, PRD r22 `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed`, phase14 brief `6fd8d01b1f279a1245ac70ce68e7b1918df9cf41e53324bbedf6d2f51415b384`, owner-first-bond correction `29dca72edabe86612e98665a941d1f621cb7184e707bbfa841385fa779ccfb92`, producer report `29daaa4d0db079f656f62cb122f62eb6ada954082a523337850a4e557a8884e5`, producer bindings `53cef93e4cacb60dbd53cd51d72b0a33de42ebde3312c8efe634948df39fd342`.

## Verification performed here

- Read the complete commit brief, phase14 brief, plan r5 sections 1 through 1.5 and the weighted SY evidence row, PRD r22 sections 1 through 1.2, the complete producer report, and the complete independent verification report. Verified the report hash, branch, parent `75d513cb8b36e53f14c8aa3a352f21703ad91ba1`, empty incoming staged set, and recent subject-only commit convention. No upstream is configured; no fetch or push was attempted.
- Read the entire 33-file candidate diff, including the five new files. URL/signing-material inspection found only loopback templates and `https://example.invalid`. `PRIVATE_KEY` is deleted from the forge environment. The Anvil comment does not embed mnemonic words or a private key. No resolved secret endpoint or signing material is in the candidate.
- Staged the 33 exact paths only. Staged modes/blobs matched the working-tree hash-object values and the accepted SHA-256 set. `git diff --check` exited 0 before and after the commit.
- After the commit, `HEAD^`, one-child count, subject, exactly one coauthor trailer, `diff-tree` path set, and each committed `ls-tree` mode/blob plus committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the new commit tree `7cce28c369bd5889da9ea10bc8954c07ece0f678`.
- Prior independent runtime evidence was corroborated from its sealed report, not rerun: 115 specs, 61 pinned forks, 59 operator tests, both operator-stage builds, strict TypeScript, the fixed18564 CLI, three mined resumes, source stopped and cleanup complete. No unchanged transaction suite was rerun.

## Preservation

- All **742 pre-commit `docs/incidents` entries** retain identical path/mode/size/SHA-256 inventories. Inventory hash `7cf1c1b11704b69450146352b46f9053e9b5b757b79f24b9257fb0b981587e4b`. No historical report, binding, snapshot, witness, log, journal or broadcast was rewritten. This receipt and the manifest are new untracked files and are not part of that inventory.
- All **13756 `out/` entries** retain metadata inventory hash `b400f55691e1b567d9763ee0b1dda7179eabba813d13fda2a541dc97c260457d`. All **1100 `cache_forge/` entries** retain metadata inventory hash `524b5b29975920d4c93d4827707abe147807562327a11252c4abb714e41d4d1a`. No build, deletion or cache write was performed.
- `lib/crane` remains a symlink to `/Users/cyotee/Projects/indexedex/lib/crane`, inode `18626650`, mode `755`. `node_modules` remains a symlink to `/Users/cyotee/Projects/indexedex/node_modules`, inode `18626652`, mode `755`. No configuration, dependency or link change.
- All refs other than `work/dtf-migration-phase-14-weighted-sy` remain identical, including main `90ff0307a7a8e084aa073e02eff125e9c7973933`, origin/main, phase13 at the parent, held phase09 `421072a7630a0d3d47a6f36e1062d9eae98c93e2`, and stash `7321b70c984423699475cfb45907b6dd70bb8ef4`. No held phase09 candidate was read, imported, tested or committed.
- The incoming staged set was empty and matched parent tree `22d0c2c07e5a17bf4a61637dccf4d829860273c1`. The final staged set is empty. Non-candidate index entries are unchanged because the index tree matches the new commit and the commit changes only the 33 accepted paths. Only local evidence remains untracked under `docs/incidents/2026-09-16-dtf-recovery/migration/weighted-sy/`.
- No merge, cherry-pick or rebase state is present. Port 18564 has no listener (`lsof` exit 1, empty output) and the verifier's Anvil PID 64671 is absent (`ps` exit 1, empty output). Commit and inspection processes completed. **No pending operation.**

## Retained scope limits

This delivers only the bounded weighted SY increment. It is not full-category Migration acceptance, not target-gas acceptance, and not public-deployment approval. The independent local parent deployment used 43,517,419 gas and does not meet the retained historical 32,000,000 transaction limit. Operational original-wallet, canonical-origin, Q0 and ETH/DTF contribution records remain required; fixture amounts are synthetic. Weighted receipt, earlier liquid/receipt, claim-vault, raw TokenStaking, standalone SE/LP and native exposure remain open. This increment does not authorize resuming the held deployment-gas lane or public execution.

## Exact committed path list

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationFacet.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol`
- `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md`
- `scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol`
- `scripts/recovery/dtf-migration/cli.ts`
- `scripts/recovery/dtf-migration/execution-plan.ts`
- `scripts/recovery/dtf-migration/execution-state.ts`
- `scripts/recovery/dtf-migration/payloads.ts`
- `scripts/recovery/dtf-migration/preparation.fixture.ts`
- `scripts/recovery/dtf-migration/preparation.test.ts`
- `scripts/recovery/dtf-migration/preparation.ts`
- `scripts/recovery/dtf-migration/provenance.ts`
- `scripts/recovery/dtf-migration/quotes.ts`
- `scripts/recovery/dtf-migration/rehearsal-chain.ts`
- `scripts/recovery/dtf-migration/rehearsal-data.ts`
- `scripts/recovery/dtf-migration/rehearsal-proof.ts`
- `scripts/recovery/dtf-migration/rehearsal-weighted-sy.ts`
- `scripts/recovery/dtf-migration/rehearse.ts`
- `scripts/recovery/dtf-migration/schema.ts`
- `scripts/recovery/dtf-migration/weighted-sy.test.ts`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryWeightedSy.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedSy.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationCore.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftConfiguration.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedSyConfiguration.t.sol`
