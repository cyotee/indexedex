# Verified bounded earlier-receipt local source delivery

Date: 2026-11-12. Status: **complete for this bounded local source delivery only**.

## Exact local commit

- Commit: `1df9076c73b94a4f63172395763fa8cdd48fe060`
- Subject: `Add verified bounded earlier receipt custody and credit`
- Parent: `acdbe319f3a20c3af6bea594c62461b6c7988717`
- Tree: `5a7725f9569d35556669f9f485b06c629644234d`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-12T01:18:18-08:00`
- Committer: `Cyotee Doge <not_cyotee@proton.me>`
- Committer date: `2026-11-12T01:18:18-08:00`
- Branch: `work/dtf-migration-phase-18-earlier-receipt`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt`
- Exactly **34 source/test/operator/runbook paths**: 30 modifications and 4 additions, 1376 insertions and 40 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. `git verify-commit` exit 0. GnuPG also prints unknown ownertrust; that is not a bad signature. The one-shot commit used `gpg.program=/usr/local/bin/gpg` so signing matched the running GnuPG 2.2.41 agent. Stored `gpg.program` remains unset.
- Exactly one commit after the required parent. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{upstream}` exit 128). No fetch or push was attempted.
- The source commit excludes this manifest, this receipt, the precommit inventories, and all other evidence. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `ae2567dee5302a918e4f95de8977705a9f1ec9f21fd1b519562c8c2eae71e58d`.

## Source provenance

`source-manifest.json` binds every candidate path, mode, accepted SHA-256, producer SHA-256, producer-audit SHA-256, both independent-audit SHA-256 values, current SHA-256, committed SHA-256, Git blob, and parent blob. The candidate set was derived from `verification/bindings.ts` rebinding `implementation/seal.json` `source` into `audit-fresh-final.json` and `audit-producer-final.json` `runtimeBindings.preserved[0:34]`, cross-checked to `implementation/audit.json` `source` and the actual parent/index/worktree delta. It was not taken from a directory listing. All 34 current bytes match the verifier accepted SHA-256, the producer binding, both audit bindings, and `git cat-file blob HEAD:path`. There is no post-runtime source-hash exception.

Historical runtime evidence records decimal mode 420, which is `0o644`. Every tracked parent mode and all four new files are regular non-executable files and were committed as `100644`. `core.autocrlf` is unset (exit 1). Worktree bytes, committed blob bytes, and accepted SHA-256 values match for all 34 paths, so no newline conversion was observed.

Before staging, `git diff --ignore-submodules=all --check` on the tracked candidate exited 0. That did not cover the four untracked files. After staging only the 34 accepted paths, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check acdbe319f3a20c3af6bea594c62461b6c7988717
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
```

After the commit, `git diff --ignore-submodules=all --check acdbe319f3a20c3af6bea594c62461b6c7988717 HEAD` exited 0 with empty output. Accepted hashes were not a waiver. No source byte was edited to satisfy whitespace.

Independent acceptance is the complete `verification/report.md`, raw SHA-256 `79d34b17e0b06b273c0350d450561650e09d312482efefd2effa01dbc7efe4bd`, disposition confirmed for bounded ER custody and frozen credit. That hash was recomputed from the file after the commit and still matches the admitted value. Producer seal `implementation/seal.json` remains `5ef85c26ab00282904ad27b47b151427d9018287bd91a9d10ae45e3d0c48c3b6`.

## Verification performed here

- Read the complete commit brief, the original phase18 brief, the implementation brief, the complete producer report, and the complete independent verification report. Verified the report hash, branch, parent `acdbe319f3a20c3af6bea594c62461b6c7988717`, empty incoming staged set, and recent subject-only commit convention.
- Read the entire tracked candidate diff and all four added files. The diff is confined to Migration interfaces, storage, allocation/recovery facets and targets, the legacy recovery library, adjacent specs/forks, the existing operator/stage home, and the runbook. No ordinary/common/Crane production, dependency, configuration, provider, or held09 path is in the commit.
- URL/signing-material inspection found only `127.0.0.1` loopback gates, the public Anvil mnemonic, the archive alias `robinhood_mainnet_alchemy`, and the pinned block hash. The new ER signer is gated to `127.0.0.1` ports `18567` and `18568`. The runbook names the archive alias and does not embed a resolved endpoint. Those fixtures are inside the independently accepted bytes and were not stripped.
- Staged blob hashes and modes matched worktree bytes and the accepted SHA-256 set before the commit. After the commit, `HEAD^`, one-child count, subject, exactly one coauthor trailer, `diff` path set, and each committed `ls-tree` mode/blob plus committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the new commit tree `5a7725f9569d35556669f9f485b06c629644234d`.
- Prior independent runtime evidence was corroborated from its sealed report and final audit JSON, not rerun: 142 specs, 101 pinned forks, 72 operator tests, strict operator types, both operator-stage builds, and the actual fixed 18568 CLI with three real mined-before-checkpoint/fresh-process resumes. Each final audit binds 75 runtime capture entries and 57 artifact/runtime comparisons across 29 distinct artifacts, plus 2 separately checked stage artifacts and 23 prepared inputs. Repeated captures are not 75 distinct contracts. No unchanged suite was replayed.

## Qualifications that remain explicit

This is a bounded local immutable delivery of the stopped candidate, not full-plan acceptance, target-gas acceptance, operational allocation approval, or a public operation. ER liquidation remains blocked. Final strict typechecks passed. TypeScript LSP freshness was not reliable, and Bash LSP is unavailable. Those tooling gaps are not claimed as passes.

Independent compilation changed only the terminal Solar source-unit id in four raw ABI JSON files under ignored `out/`: Allocation and Migration `2442` to `534`, MigrationDFPkg `2444` to `536`, and Recovery `2457` to `543`. Substituting that id in memory recovers the sealed original length and SHA-256. Those recovered strings are not original captured files, and the files were not restored. Fresh prepared inputs match the current raw artifacts directly (`producerInputReconstruction` is empty in the fresh audit and has 48 repeated records across those same 4 paths in the producer audit). The preservation baseline is the current post-verification `out/` and `cache_forge/`.

Four inherited claim-vault and W-SD acquisition signatures, two nonces each, were reconstructed offline. Each final audit retains 4 reconstructed records and 72 raw signed payloads. Reconstructed bytes are not originally captured raw signed bytes. Their hashes match the actual mined receipts recorded by the independent audit. No transaction was sent by this commit lane.

The fresh actual signed parent deployment uses **44,653,392 gas**, transaction `0x79b37c8f8d6274380acb04c0d2f6af7b000ab1de236ba1e340a0a23a30238ab4`, above the retained 32-million limit. Prior parent gas 44,353,454 remains the earlier open observation. Neither figure was rerun or relabeled as target-gas acceptance. Allocation runtime is 24510 bytes, 66 bytes below EIP-170, and code-size enforcement stayed enabled.

ER conversion and donation, operational original datasets, opaque-origin reconciliation, other source categories, host/archive portability, and full hermetic/full-plan acceptance remain open. Positive remaining Q/C is recorded state, not a pending operation.

The phase15 W-SD archive remains at `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se/docs/incidents/2026-09-16-dtf-recovery/migration/dtf-custody-se/implementation/source-archive.json`, 1,047,506 bytes, mode `0644`, SHA-256 `600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`. Phase17 admitted inputs remain at their retained paths, including `weighted-receipt/source/contract.md` (18,779 bytes, SHA-256 `8505a56f2b9dec9a34d9fb322d1a9cd78aa7e151678008427143cce9ff782bd6`) and `weighted-receipt/source-verification/report.md` (15,387 bytes, SHA-256 `b39dd7edeb5f0250ffd257744df2304eb18485c195f121ec64f058eebb077c56`). They were not deleted, relocated, or rewritten. `lib/crane` remains a symlink to `/Users/cyotee/Projects/indexedex/lib/crane`, inode `19330661`, mode `0755`. `node_modules` remains a symlink to `/Users/cyotee/Projects/indexedex/node_modules`, inode `19330663`, mode `0755`.

## Preservation

Precommit inventories were captured before any `commit/` file existed and are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`, SHA-256 `2e746e82453156799fd6fb6b10694a43b4ce97433f090c001a4730031a146dc2`. The git-mode serialization is UTF-8 JSON Lines, one object per line, keys `path`, `kind`, `mode`, `size`, `sha256`, `target`, sorted by POSIX path. That git-mode field collapses non-executable regular files to `100644` and is not a read-only-mode proof. The permission inventory `docs-incidents-perms.jsonl` records `perm` as `oct(st_mode & 0o777)` and is the encoding for sealed read-only modes.

- All **2126 pre-commit `docs/incidents` git-mode entries** retain identical path/kind/mode/size/SHA-256/target inventories. Inventory hash `b0f13a36c69056b1287bb25df38b729ec39ef97ed3a15b0f49010cff69001082`. Post-commit rewalk: 0 missing, 0 changed, 15 new paths, all under excluded `commit/precommit/`. This receipt and `source-manifest.json` were written after that rewalk and are also excluded.
- All **2283 pre-commit permission entries** retain identical path/kind/perm/size/SHA-256 except the directory-size change caused by creating `commit/`: `docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt` 192 to 224. Inventory hash `55bc0a5445e77a9e670509e9dfa445653ad1bb8529da2b4238ea0b3bef0a6b60`. Post-commit rewalk: 0 missing, 0 file changes, 17 new paths. Those new paths are the excluded `commit` directory, `commit/precommit`, and the 15 precommit files. The permission walk records the `commit` directory without a trailing slash; it is the exclusion root, not a foreign path. Sealed file modes and hashes are unchanged. No historical report, binding, snapshot, witness, log, journal, or seal was rewritten or chmodded.
- All **7340 `out/` entries** retain inventory hash `da29a6cc29d8bd75aac8b9cb56a033b7e1bbea9c6fe9660d8f73c847cade97b0`. Post-commit rewalk: 0 missing, 0 changed, 0 new. No build, deletion, or artifact restoration was performed. The four ABI id drifts above are inside this current baseline; original hashes were not restored.
- All **603 `cache_forge/` entries** retain inventory hash `59e469d1708c72b13852d0eb5e95664d3f4ba8aa022c7dd1163213c81ca36212`. Post-commit rewalk: 0 missing, 0 changed, 0 new.
- All refs other than `work/dtf-migration-phase-18-earlier-receipt` remain identical. The only ref movement is this branch from `acdbe319f3a20c3af6bea594c62461b6c7988717` to `1df9076c73b94a4f63172395763fa8cdd48fe060`. `show-ref` baseline SHA-256 `7abe2969d8a94df50f87277963bbe6c5f7f7068ff2f669a59793be19030e5859`. No held phase09 candidate was read, imported, tested, or committed.
- Nineteen foreign worktree indexes are unchanged. This worktree index changed from `37ced8a155fa31fbd9dbd3c69c1a2b882b7341a4b6d891b0a2fce521096ad857` to `a2c5742f0e9c18b5ce04298b218b0fb82fb77ec3f00ff5ee6d3dc53be1422057`. The index matches the new commit: staged diff empty and `git write-tree` equals `5a7725f9569d35556669f9f485b06c629644234d`.
- Twenty-eight external producer-seal authority/input files, recorded in `precommit/host-dependencies.jsonl`, retain identical size, mode, and SHA-256. The phase15 archive and phase17 admitted inputs above are in that set.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the 34 accepted paths. No merge, cherry-pick, rebase, or index lock is present.
- Port 18568 listener check exit 1 with empty output. The checkpoint and runtime parent are absent. Commit and inspection processes completed. **No pending operation.**
