# Verified bounded weighted-receipt local source delivery

Date: 2026-11-12. Status: **complete for this bounded local source delivery only**.

## Exact local commit

- Commit: `acdbe319f3a20c3af6bea594c62461b6c7988717`
- Subject: `Add verified bounded weighted receipt surrender and recovery`
- Parent: `a96f0fd26c1a1fdba35750cff74d866afa3a9796`
- Tree: `5c876ffe15dc89e8a47ceb84b7b3e81676a73dd7`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-11T22:11:26-08:00`
- Committer date: `2026-11-11T22:11:26-08:00`
- Branch: `work/dtf-migration-phase-17-weighted-receipt`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-17-weighted-receipt`
- Exactly **36 source/test/operator/runbook paths**: 29 modifications and 7 additions, 1537 insertions and 56 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. The one-shot commit used `gpg.program=/usr/local/bin/gpg` so signing matched the running GnuPG 2.2.41 agent. Stored `gpg.program` remains unset.
- Exactly one commit after the required parent. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{upstream}` exit 128). No fetch or push was attempted.
- The source commit excludes this manifest, this receipt, the precommit inventories, and all other evidence. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `c773d0b76c8fbbaf308b8d9e303cd5c30090147457d5b6980327c3b548f8f753`.

## Source provenance

`source-manifest.json` binds every candidate path, mode, accepted SHA-256, producer SHA-256, audit SHA-256, current SHA-256, committed SHA-256, Git blob, and parent blob. The candidate set was derived from the independent verifier seal `candidateSources`, checked against producer `finalSources` and `audit-02/source-bindings.json`, then intersected with the actual parent/index/worktree delta. It was not taken from a directory listing. All 36 current bytes match the verifier accepted SHA-256, the producer binding, the audit binding, and `git cat-file blob HEAD:path`. There is no post-runtime hash exception.

Historical runtime evidence records decimal mode 420, which is `0o644`. Every tracked parent mode and all seven new files are regular non-executable files and were committed as `100644`. `core.autocrlf` is unset (exit 1). Worktree bytes, committed blob bytes, and accepted SHA-256 values match for all 36 paths, so no newline conversion was observed.

Before staging, `git diff --ignore-submodules=all --check` on the tracked candidate exited 0. That did not cover the seven untracked files. After staging only the 36 accepted paths, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check a96f0fd26c1a1fdba35750cff74d866afa3a9796
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
GIT_MASTER=1 git diff --ignore-submodules=all --check a96f0fd26c1a1fdba35750cff74d866afa3a9796
```

Accepted hashes were not a waiver. No source byte was edited to satisfy whitespace.

Independent acceptance is the complete `verification/report.md`, raw SHA-256 `65108f5890f7c7371f1d8a7c2752e35a6a61705adc7ca70fd9c724ed445e9490`, disposition confirmed for the admitted bounded weighted-receipt implementation. That hash was recomputed from the file after the commit and still matches the admitted value. Producer seal `implementation/seal.json` remains `082357f4df799ddd70380f872d6f323e7ab1ce2e5b9865fa9a3e42d75716ce16`.

## Verification performed here

- Read the complete commit brief, the original phase17 brief, the implementation brief, the complete producer report, and the complete independent verification report. Verified the report hash, branch, parent `a96f0fd26c1a1fdba35750cff74d866afa3a9796`, empty incoming staged set, and recent subject-only commit convention.
- Read the entire tracked candidate diff and all seven added files. The diff is confined to Migration interfaces, storage, allocation/recovery facets and targets, the legacy recovery library, adjacent specs/forks, the existing operator/stage home, and the runbook. No ordinary/common/Crane production, dependency, configuration, provider, or held09 path is in the commit.
- URL/signing-material inspection found only `127.0.0.1` loopback templates, `https://example.invalid`, and the public Anvil mnemonic. The new WS signer is gated to `127.0.0.1:18567`. The runbook names the archive alias `robinhood_mainnet_alchemy` and does not embed a resolved endpoint. Those fixtures are inside the independently accepted bytes and were not stripped.
- Staged blob hashes and modes matched worktree bytes and the accepted SHA-256 set before the commit. After the commit, `HEAD^`, one-child count, subject, exactly one coauthor trailer, `diff` path set, and each committed `ls-tree` mode/blob plus committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the new commit tree `5c876ffe15dc89e8a47ceb84b7b3e81676a73dd7`.
- Prior independent runtime evidence was corroborated from its sealed report, not rerun: 134 specs, 92 pinned forks, 68 operator tests, strict operator types, both operator-stage builds, the actual fixed18567 CLI, 25 deployed bindings, 675 compiled sources, 49 signed operator completions, and all 15 raw receipt fields for each of three interrupted resumes. No unchanged suite was replayed.

## Qualifications that remain explicit

This is a bounded local immutable delivery of the stopped candidate, not full-plan acceptance, target-gas acceptance, or a public operation. Solidity LSP reported no errors for the inspected Recovery target. TypeScript LSP was not reliably fresh, and JSON LSP is unavailable because Biome is absent. Those tooling gaps are not claimed as passes. Final strict typechecks remain the accepted type evidence.

Actual signed parent deployment uses 44,353,454 gas, above the retained historical 32-million transaction limit. That observation was not rerun and is not target-gas acceptance. Operational original-wallet datasets, opaque-origin reconciliation, other source categories, host/archive portability, and full hermetic/full-plan acceptance remain open.

The phase15 W-SD archive dependency remains at `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se/docs/incidents/2026-09-16-dtf-recovery/migration/dtf-custody-se/implementation/source-archive.json`, 1,047,506 bytes, mode `0644`, SHA-256 `600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`. It was not deleted, relocated, or rewritten. `lib/crane` remains a symlink to `/Users/cyotee/Projects/indexedex/lib/crane`, inode `19240329`, mode `0755`. `node_modules` remains a symlink to `/Users/cyotee/Projects/indexedex/node_modules`, inode `19240330`, mode `0755`.

## Preservation

Precommit inventories were captured before any `commit/` file existed and are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`, SHA-256 `ebf55ae45f4fd64639e308b23cc74169785434b8ae261de2bcd2f1e9451f4d56`. The git-mode serialization is UTF-8 JSON Lines, one object per line, keys `path`, `kind`, `mode`, `size`, `sha256`, `target`, sorted by POSIX path. That git-mode field collapses non-executable regular files to `100644` and is not a read-only-mode proof. The permission inventory `docs-incidents-perms.jsonl` records `perm` as `oct(st_mode & 0o777)` and is the encoding for sealed read-only modes.

Attempt 01 wrote the two characters backslash and n instead of a newline and parsed only one worktree index. Those files are retained under `commit/precommit/failed-serialization-attempt-01/`. The same walk records were re-serialized to the recipe, and all 18 indexes were recaptured, before staging. No sealed evidence, source, `out/`, or `cache_forge/` file was rewritten to make the later walk match.

- All **1561 pre-commit `docs/incidents` git-mode entries** retain identical path/kind/mode/size/SHA-256/target inventories. Inventory hash `ca8f3c6e3486279d045c1d63723aa654f4d4acbc5074d5df521524c55f40bbce`. Post-commit rewalk: 0 missing, 0 changed, 18 new paths, all under excluded `commit/`. This receipt and `source-manifest.json` were written after that rewalk and are also excluded.
- All **1750 pre-commit permission entries** retain identical path/kind/perm/size/SHA-256 except directory-size changes caused by creating `commit/`: docs/incidents/2026-09-16-dtf-recovery/migration/weighted-receipt 192->224. Inventory hash `b46be8e2a0de767b2000b3573d8789d14244930ea65b39c22c75e0e4504f1522`. Sealed file modes and hashes are unchanged. No historical report, binding, snapshot, witness, log, journal, or seal was rewritten or chmodded.
- All **7337 `out/` entries** retain inventory hash `644ac1053a1dafa8f35323ea8778068cf3e190d80db7e61c7a1371c35d01aebe`. Post-commit rewalk: 0 missing, 0 changed, 0 new. No build or deletion was performed.
- All **599 `cache_forge/` entries** retain inventory hash `fac4556af9b93fad665070e677840c1802c5e89998fc12b078bf6c0d3d8f880f`. Post-commit rewalk: 0 missing, 0 changed, 0 new.
- All refs other than `work/dtf-migration-phase-17-weighted-receipt` remain identical. The only ref movement is this branch from `a96f0fd26c1a1fdba35750cff74d866afa3a9796` to `acdbe319f3a20c3af6bea594c62461b6c7988717`. `show-ref` baseline SHA-256 `c2ea68c17d7b3b1c9520e37cc267e034847dbd8542816f714487f8945cc6cde1`. No held phase09 candidate was read, imported, tested, or committed.
- Seventeen foreign worktree indexes are unchanged. This worktree index changed from `c97896e1ec5399cb1654f31b8707ad3d90433fca0112a977cd5d35cacadd4c83` to `ca6c853db62e934f402e816ff23702ca8fffba7f74923e4fb4e97ae770c83f6e`. The index matches the new commit: staged diff empty and `git write-tree` equals `5c876ffe15dc89e8a47ceb84b7b3e81676a73dd7`.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the 36 accepted paths. No merge, cherry-pick, rebase, or index lock is present.
- Port 18567 listener check exit 1 with empty output. Commit and inspection processes completed. **No pending operation.**
