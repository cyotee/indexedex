# Verified bounded direct claim-vault local source delivery

Date: 2026-11-12. Status: **complete for local source delivery only**.

## Exact local commit

- Commit: `9c227900b280713305d4a1a1d1cdc3d8d273f23d`
- Subject: `Add verified bounded direct claim-vault surrender and recovery`
- Parent: `4a53299b490343ed904d70c92ecbc7360fcb7659`
- Tree: `d0729eb87d2ab3c5f22b12e2bef0549226ba4239`
- Author date: `2026-11-11T18:32:52-08:00`
- Branch: `work/dtf-migration-phase-16-claim-vault`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-16-claim-vault`
- Exactly **40 source/test/operator/runbook paths**: 31 modifications and 9 additions, 1726 insertions and 69 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`.
- Exactly one commit after the required parent. No push, PR, merge, public action or source fix.
- No upstream is configured. No fetch or push was attempted.
- The source commit deliberately excludes this manifest/receipt, the precommit inventories, and all other evidence/generated artifacts. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `a2d5599854282782a3443d910f8f78a8bddd813537ccf44fd652c5651cc787ea`.

## Source provenance

`source-manifest.json` binds every candidate path, mode, accepted SHA-256, producer SHA-256, final-snapshot SHA-256, current SHA-256, committed SHA-256, Git blob, and parent blob. The candidate set was derived from the independent verifier's 40 `sourceSnapshots` in `verification-e1/reviewed-summary.json`, checked against producer `final-source-bindings.json` and byte-exact `final-source-snapshot/` copies, then intersected with the actual parent/index/worktree delta. It was not taken from a directory listing or a producer pass flag. All 40 current bytes match the verifier accepted SHA-256, the producer binding, the final snapshot bytes, and `git cat-file blob HEAD:path`. There is no post-runtime hash exception.

Historical runtime evidence records bytes, not file modes. Every tracked parent mode is `100644`. All nine new files are regular files with no executable bit and were committed as `100644`. `core.autocrlf` is unset. Worktree bytes, committed blob bytes, and accepted SHA-256 values match for all 40 paths, so no newline conversion was observed.

`git diff --check` on the 31 tracked candidate files exited 0. After staging, `git diff --cached --check` exited 2 only because each of the nine added files has a new blank line at EOF. Those blank lines are inside the accepted hashes. They were not stripped.

Independent acceptance is the complete `verification-e1/report.md`, raw SHA-256 `eeeb506d011189454c005adeb703b1ce7646d69ca79951116ea81cec833d9e81`, disposition confirmed. That hash was recomputed from the file before commit. Bound inputs matched: plan r5 `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d`, PRD r22 `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed`, corrected phase16 brief `d891944faa7c106ad340d89466340d4f70e8b1cb28d77c0bddf952e4aa79a2f1`, producer report `ee81d2c9d15f35befe95bbfe6af48152537af3d2363c4601a1bfd9a248240125`.

## Verification performed here

- Read the complete commit brief, the corrected phase16 brief, plan r5 E1/E2 and file-boundary gates, the complete producer report, and the complete independent verification report. Verified the report hash, branch, parent `4a53299b490343ed904d70c92ecbc7360fcb7659`, empty incoming staged set, and recent subject-only commit convention.
- Read the entire 31-file tracked candidate diff and all nine added files. The staged tracked diff was byte-identical to that candidate diff. Staged blob hashes matched worktree bytes and the accepted SHA-256 set before the commit.
- URL/signing-material inspection found only a `127.0.0.1` loopback template and `https://example.invalid`. `PRIVATE_KEY` is deleted from the forge environment. The runbook names the archive alias `robinhood_mainnet_alchemy` and does not embed a resolved endpoint. The accepted source retains the public Anvil mnemonic for development derivation index 105, gated to `127.0.0.1:18566`, the existing index-104 fixture now gated to the same port, and the Foundry test holder `vm.addr(0xD7FC0570D1)`. Those are local test fixtures in the independently accepted bytes. They were not stripped, because delivery may not modify source. No PEM block, assigned production private key, or keyed RPC URL is in the candidate.
- After the commit, `HEAD^`, one-child count, subject, exactly one coauthor trailer, `diff-tree` path set, and each committed `ls-tree` mode/blob plus committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the new commit tree `d0729eb87d2ab3c5f22b12e2bef0549226ba4239`.
- Prior independent runtime evidence was corroborated from its sealed report, not rerun: 130 specs, 81 pinned forks, 64 operator tests, strict operator types, current artifact preparation, both operator-stage builds, the actual fixed18566 CLI, exact ten-selector removal on the new facet runtime, and three independently decoded signature/receipt resumes. No unchanged transaction suite was rerun.

## Qualifications that remain explicit

Exact archived claim-vault source equivalence is unestablished. Historical commits locate the implementation family; they are not a byte-identical deployed-source proof. Actual pinned E1 execution is the accepted route proof. Direct shares are not raw TokenStaking rights and are not proof of affected users' direct-share holdings.

Unlinked artifact templates are not deployed runtime. The independent verifier recorded the new allocation linked runtime hash `0x1baf3f6df765aa47c65c37e54fbe275a6a63cf3485d13b5089cd2c8fe3380fc3` and recovery runtime hash `0xc0ca13b7e9d7eb488cd8a2eab5c0aa631feaac17f18d31181dcdcba2a51cef9d`. Those identities were not recomputed here.

This is a workstation-local rehearsal, not portable or full-F3 acceptance. Existing authority paths bind this workstation's Foundry installation at `/Users/cyotee/.foundry/bin/forge`. The retained W-SD archive input is:

`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se/docs/incidents/2026-09-16-dtf-recovery/migration/dtf-custody-se/implementation/source-archive.json`

Its 1,047,506 bytes still hash to `600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`. It was not deleted or rewritten. Operational original datasets, other source categories, full hermetic/full-plan completion, and deployment-gas feasibility remain open. The verifier's observed parent deployment receipt of 44,099,850 gas was not rerun and is not target-gas acceptance.

## Preservation

Precommit inventories were captured before any `commit/` file existed and are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`, SHA-256 `45c2c071e55e759d45dae306ef15133cbf314a22af6a0ce80b9d28dc62924804`. The git-mode serialization is UTF-8 JSON Lines, one object per line, keys `path`, `kind`, `mode`, `size`, `sha256`, `target`, sorted by POSIX path. That git-mode field collapses non-executable regular files to `100644` and is not a read-only-mode proof. The permission inventory `docs-incidents-perms.jsonl` records `perm` as `oct(st_mode & 0o777)` for files and directories and is the encoding for sealed read-only modes.

- All **996 pre-commit `docs/incidents` git-mode entries** retain identical path/kind/mode/size/SHA-256/target inventories. Inventory hash `53690222c0e48e6391a983defa96e7173760469a66c7a2fce77fb271030540ab`. Post-commit rewalk: 0 missing, 0 changed. New paths are only this excluded `commit/` evidence.
- All **1149 pre-commit permission entries** retain identical path/kind/perm/size/SHA-256 except the `claim-vault` directory itself. Inventory hash `63c69e9609eccc19f61690d00f267f230ab8cf34e09a3dd095ef4072ba119845`. Its permission stayed `0o755`; its directory size changed from 192 to 224 only because `commit/` was created inside it. Sealed `implementation/`, `verification/`, `implementation-e1/` (`0o555`), and `verification-e1/` permissions, sizes, and file hashes are unchanged. No historical report, binding, snapshot, witness, log, journal, broadcast, or seal was rewritten or chmodded.
- All **7330 `out/` entries** retain inventory hash `bfe01d54b8c2e90c6386905ac881b860553f552571d01c64cdaa41531e2a939f`. Post-commit rewalk: 0 missing, 0 changed, 0 new. No build or deletion was performed.
- All **595 `cache_forge/` entries** retain inventory hash `59f14a7400dfddad607032730144de3c280e5b44e483561ac280b0d0d8bab0b7`. Post-commit rewalk: 0 missing, 0 changed, 0 new.
- `lib/crane` remains a symlink to `/Users/cyotee/Projects/indexedex/lib/crane`, inode `18755930`, mode `755`. `node_modules` remains a symlink to `/Users/cyotee/Projects/indexedex/node_modules`, inode `18755931`, mode `755`. No configuration, dependency, or link change.
- All refs other than `work/dtf-migration-phase-16-claim-vault` remain identical. The only ref movement is this branch from the parent to `9c227900b280713305d4a1a1d1cdc3d8d273f23d`. No held phase09 candidate was read, imported, tested, or committed.
- The incoming staged set was empty and matched parent tree `318cdbf5e6af7c1ebd00d51d164edf7dade3255b`. The final staged set is empty. The index tree matches the new commit, and the commit changes only the 40 accepted paths. No merge, cherry-pick, or rebase state is present.
- Port 18566 has no listener. Commit and inspection processes completed. **No pending operation.**
