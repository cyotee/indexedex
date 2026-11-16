# Verified bounded DTF-custody SE local source delivery

Date: 2026-11-12. Status: **complete for local source delivery only**.

## Exact local commit

- Commit: `4a53299b490343ed904d70c92ecbc7360fcb7659`
- Subject: `Add verified bounded DTF-custody SE surrender and recovery`
- Parent: `2baab6e58dafcc3fe5f9a94570d99987d58bf42b`
- Tree: `318cdbf5e6af7c1ebd00d51d164edf7dade3255b`
- Author date: `2026-11-11T16:25:58-08:00`
- Branch: `work/dtf-migration-phase-15-dtf-custody-se`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se`
- Exactly **34 source/test/operator/runbook paths**: 27 modifications and 7 additions, 1575 insertions and 55 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`.
- Exactly one commit after the required parent. No push, PR, merge, public action or source fix.
- No upstream is configured. No fetch or push was attempted.
- The source commit deliberately excludes this manifest/receipt, the precommit inventories, and all other evidence/generated artifacts. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `c9c1c35eb5ee37e5f635116afb27975ba8939d9c87cdcc5c8072c2bb89c0b010`.

## Source provenance

`source-manifest.json` binds every candidate path, mode, accepted SHA-256, verifier actual SHA-256, current SHA-256, committed SHA-256, Git blob, and parent blob. The candidate set was derived from the independent verifier's 34 `sourceFiles` in `verification/bindings.json`, checked against `verification/source-authority.json` snapshots where expected, snapshot, and actual hashes are equal, then intersected with the actual parent/index/worktree diff. It was not taken from a directory listing or a producer pass flag. All 34 current bytes match the verifier accepted SHA-256, the verifier actual SHA-256, the producer source-snapshot SHA-256 and embedded snapshot bytes, and `git show HEAD:path`. There is no post-runtime hash exception.

Historical runtime evidence records bytes, not file modes. Every tracked parent mode is `100644`. All seven new files are regular files with no executable bit and were committed as `100644`. `core.autocrlf` is unset. Worktree bytes, committed blob bytes, and accepted SHA-256 values match for all 34 paths, so no newline conversion was observed.

Independent acceptance is the complete `verification/report.md`, raw SHA-256 `77e67678c3180b4ef487fb40567131e9aea0e6c03f7f0f0f1f66003d1226669e`, disposition confirmed. That hash was recomputed from the file before commit and again when the manifest was written. Bound inputs matched: plan r5 `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d`, PRD r22 `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed`, phase15 brief `fe961165903c72cfd3ebd8a9c139d64ff841b799743109a2eb65e9fdcc785433`, producer report `5903665aa38c173554ea7a1f66602da3da0e656523ba4aeb6866067b54dd538c`, producer bindings `9773941ec57f79711e2f01af0791d758b799739cca6745bee6c3fdda6ca81a2e`.

## Verification performed here

- Read the complete commit brief, the complete phase15 brief, plan r5 sections 1 through 1.5, 5.6 and 6, PRD r22 sections 1, 6 and 7, the complete producer report, and the complete independent verification report. Verified the report hash, branch, parent `2baab6e58dafcc3fe5f9a94570d99987d58bf42b`, empty incoming staged set, and recent subject-only commit convention.
- Read the entire 27-file tracked candidate diff and all seven added files. The staged tracked diff was byte-identical to that candidate diff, 82185 bytes. Staged blob hashes matched worktree `git hash-object` values and the accepted SHA-256 set before the commit. `git diff --check` exited 0 on the staged diff and again on `HEAD^..HEAD`.
- URL/signing-material inspection found only loopback templates and `https://example.invalid`. `PRIVATE_KEY` is deleted from the forge environment. The runbook names the archive alias `robinhood_mainnet_alchemy` and does not embed a resolved endpoint. The accepted source retains the public Anvil mnemonic for development derivation index 104, gated to `127.0.0.1:18565`, and the Foundry test holder `vm.addr(0xD7FC0570D1)`. Those are local test fixtures in the independently accepted bytes. They were not stripped, because delivery may not modify source. No PEM block, assigned production private key, or keyed RPC URL is in the candidate.
- After the commit, `HEAD^`, one-child count, subject, exactly one coauthor trailer, `diff-tree` path set, and each committed `ls-tree` mode/blob plus committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the new commit tree `318cdbf5e6af7c1ebd00d51d164edf7dade3255b`.
- Prior independent runtime evidence was corroborated from its sealed report, not rerun: 122 specs, 71 pinned forks, 62 operator tests, both operator-stage builds, strict TypeScript, the fixed18565 CLI, signed controlled-wallet acquisition, three mined resumes, source stopped and cleanup complete. No unchanged transaction suite was rerun.

## Preservation

Precommit inventories were captured before any `commit/` file existed and are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`, SHA-256 `44543685c7fe131d468744a8427a7ebae25b57f988ba65b870c12121d23278e9`. Serialization is UTF-8 JSON Lines, one object per line, keys `path`, `kind`, `mode`, `size`, `sha256`, `target`, sorted by POSIX path, with SHA-256 of raw file bytes or of the symlink target string. An aggregate hash is recorded only with that JSONL.

- All **802 pre-commit `docs/incidents` entries** retain identical path/kind/mode/size/SHA-256/target inventories. Inventory hash `976afcfeaea79c66ae6488482c4f0810c0bbd5ff3899860cfd7875a08ef40204`. Post-commit rewalk: 0 missing, 0 changed. New paths are only this excluded `commit/` evidence. No historical report, binding, snapshot, witness, log, journal, broadcast or seal was rewritten.
- All **7321 `out/` entries** retain inventory hash `90924744f2003f47870fc12db271363666e233e85ccb40b63482bceb390179ad`. Post-commit rewalk: 0 missing, 0 changed, 0 new. No build or deletion was performed.
- All **592 `cache_forge/` entries** retain inventory hash `82dfe6b7ace19101efbfff4201c5279630510a9b5766489956cbc29b03b08077`. Post-commit rewalk: 0 missing, 0 changed, 0 new.
- `lib/crane` remains a symlink to `/Users/cyotee/Projects/indexedex/lib/crane`, inode `18688325`, mode `755`. `node_modules` remains a symlink to `/Users/cyotee/Projects/indexedex/node_modules`, inode `18688326`, mode `755`. No configuration, dependency or link change.
- All refs other than `work/dtf-migration-phase-15-dtf-custody-se` remain identical, including main `90ff0307a7a8e084aa073e02eff125e9c7973933`, origin/main, phase14 at the parent `2baab6e58dafcc3fe5f9a94570d99987d58bf42b`, held phase09 `421072a7630a0d3d47a6f36e1062d9eae98c93e2`, and stash `7321b70c984423699475cfb45907b6dd70bb8ef4`. The only ref movement is this branch from the parent to `4a53299b490343ed904d70c92ecbc7360fcb7659`. No held phase09 candidate was read, imported, tested or committed.
- The incoming staged set was empty and matched parent tree `7cce28c369bd5889da9ea10bc8954c07ece0f678`. The final staged set is empty. The index tree matches the new commit, and the commit changes only the 34 accepted paths. No merge, cherry-pick or rebase state is present.
- Port 18565 has no listener and the verifier's Anvil PID 2461 is absent. Commit and inspection processes completed. **No pending operation.**

## Rebuilt test artifact

`out/MigrationNftConfiguration.t.sol/MigrationNftConfigurationTest.json` is not a source commit member and was not rebuilt or edited here. Current raw SHA-256 `99ce5bd22525c8acad1b84c632a7bc50e7bb958a3d8d5b212a421dce27a9a2e5`, 997658 bytes, mode `100644`, matches the independent verifier's recorded rebuilt hash and does not match the producer admitted hash `a333899524467f478b78168fa79bb29600066910cb652eceec20f60bfe0d9e3c`. This is the same recorded raw JSON difference already qualified in verification report section 6. Field-level old/new equivalence is not asserted, because the producer did not retain the complete old raw test JSON. Verification and implementation seals were not modified; their precommit inventory entries are unchanged.

## Retained scope limits

This delivers only the bounded W-SD increment. It is not full-category Migration acceptance, not target-gas acceptance, and not public-deployment approval. The independent local parent deployment used 43,770,976 gas and does not meet the retained historical 32,000,000 transaction limit. Operational original-wallet, canonical-origin, Q0 and ETH/DTF contribution records remain required; fixture amounts are synthetic. W-SW, earlier SE, owner-restricted LP, raw weight/receipt and full-category support remain open. This increment does not authorize resuming the held deployment-gas lane or public execution.

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
- `scripts/recovery/dtf-migration/dtf-custody-se.test.ts`
- `scripts/recovery/dtf-migration/execution-plan.ts`
- `scripts/recovery/dtf-migration/execution-state.ts`
- `scripts/recovery/dtf-migration/payloads.ts`
- `scripts/recovery/dtf-migration/preparation.fixture.ts`
- `scripts/recovery/dtf-migration/preparation.test.ts`
- `scripts/recovery/dtf-migration/preparation.ts`
- `scripts/recovery/dtf-migration/provenance.ts`
- `scripts/recovery/dtf-migration/quotes.ts`
- `scripts/recovery/dtf-migration/rehearsal-data.ts`
- `scripts/recovery/dtf-migration/rehearsal-dtf-custody-se.ts`
- `scripts/recovery/dtf-migration/rehearsal-dtf-custody-source.ts`
- `scripts/recovery/dtf-migration/rehearsal-proof.ts`
- `scripts/recovery/dtf-migration/rehearse.ts`
- `scripts/recovery/dtf-migration/schema.ts`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDtfCustodySe.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDtfCustodySeForkBase.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDtfCustodySe.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationCore.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDtfCustodySeConfiguration.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftConfiguration.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol`
