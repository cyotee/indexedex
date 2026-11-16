# Verified bounded earlier-liquid local source delivery

Date: 2026-11-12. Status: **complete for this bounded local source delivery only**.

## Exact local commit

- Commit: `3ec0912bafebf9c0aa66770a72f04501e5c11865`
- Subject: `Add verified bounded earlier liquid custody and credit`
- Parent: `1df9076c73b94a4f63172395763fa8cdd48fe060`
- Tree: `c3531bcea33a4bd55a1c49e894243bbbd37afc25`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-12T02:52:44-08:00`
- Committer: `Cyotee Doge <not_cyotee@proton.me>`
- Committer date: `2026-11-12T02:52:44-08:00`
- Branch: `work/dtf-migration-phase-19-earlier-liquid`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid`
- Exactly **32 source/test/operator/runbook paths**: 28 modifications and 4 additions, 1218 insertions and 75 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. `git verify-commit` exit 0. GnuPG also prints unknown ownertrust; that is not a bad signature. The one-shot commit used `gpg.program=/usr/local/bin/gpg` so signing matched the running GnuPG 2.2.41 agent. Stored `gpg.program` remains unset.
- Exactly one commit after the required parent. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{upstream}` exit 128). No fetch or push was attempted.
- The source commit excludes this manifest, this receipt, the precommit inventories, and all other evidence. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `548d4f6681a1af9eb97a68c678268474b3e3665aa455ecb8b3e3fcf04db9bb7b`.

## Source provenance

`source-manifest.json` binds every candidate path, mode, accepted SHA-256, producer SHA-256, producer-audit SHA-256, both independent-audit SHA-256 values, current SHA-256, committed SHA-256, Git blob, and parent blob. The candidate set was derived from `verification/audit.ts` and `implementation/bindings.ts` rebinding `implementation/source-manifest.json` `source` into `verification/audit-final.json` `results[0].bound.preserved[0:32]` and `results[1].bound.preserved[0:32]`, cross-checked to the producer source array and the actual parent/index/worktree delta. It was not taken from a directory listing. All 32 current bytes match the verifier accepted SHA-256, the producer binding, both audit bindings, and `git cat-file blob HEAD:path`. There is no post-runtime source-hash exception.

Historical runtime evidence records decimal mode 420, which is `0o644`. Every tracked parent mode and all four new files are regular non-executable files and were committed as `100644`. `core.autocrlf` is unset (exit 1). Worktree bytes, committed blob bytes, and accepted SHA-256 values match for all 32 paths, so no newline conversion was observed.

Before staging, `git diff --ignore-submodules=all --check` on the tracked candidate exited 0. That did not cover the four untracked files. After staging only the 32 accepted paths, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check 1df9076c73b94a4f63172395763fa8cdd48fe060
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
```

After the commit, `git diff --ignore-submodules=all --check 1df9076c73b94a4f63172395763fa8cdd48fe060 HEAD` exited 0 with empty output. Accepted hashes were not a waiver. No source byte was edited to satisfy whitespace.

Independent acceptance is the complete `verification/report.md`, raw SHA-256 `71a56962d55ba43ffe9820a101312a936825842264ad86036b6b5183f99238db`, disposition confirmed for bounded ED custody and frozen credit. That hash was recomputed from the file after the commit and still matches the admitted value. Producer seal `implementation/seal.json` remains `331d8d5b9ecfbc719aa43fc2e4ae4208a93aab253421d9ad79d73b2bea6008f2`.

## Verification performed here

- Read the complete commit brief, the source brief, the implementation brief, the complete producer report, and the complete independent verification report. Verified the report hash, branch, parent `1df9076c73b94a4f63172395763fa8cdd48fe060`, empty incoming staged set, and recent subject-only commit convention.
- Read the entire tracked candidate diff and all four added files. The diff is confined to Migration interfaces, storage, allocation/recovery facets and targets, adjacent specs/forks, the existing operator/stage home, and the runbook. No ordinary/common/Crane production, dependency, configuration, provider, or held09 path is in the commit. Weighted-liquid loading moved into the existing smaller claim/receipt allocation facet; its selector and administration removal remain. ED conversion, debit, and donation were not installed.
- URL/signing-material inspection found no URL, the public Anvil mnemonic, the archive alias `robinhood_mainnet_alchemy`, and the pinned block hash. The ED, ER, WS, claim-vault, and W-SD signers are gated to `127.0.0.1` ports `18567`, `18568`, and `18569`. The runbook names the archive alias and does not embed a resolved endpoint. Those fixtures are inside the independently accepted bytes and were not stripped.
- Staged blob hashes and modes matched worktree bytes and the accepted SHA-256 set before the commit. After the commit, `HEAD^`, one-child count, subject, exactly one coauthor trailer, `diff` path set, and each committed `ls-tree` mode/blob plus committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the new commit tree `c3531bcea33a4bd55a1c49e894243bbbd37afc25`.
- Prior independent runtime evidence was corroborated from its sealed report and final audit JSON, not rerun: 146 specs, 109 pinned forks, 76 operator tests, strict operator types, both operator-stage builds, and the actual fixed 18569 CLI with three real mined-before-checkpoint/fresh-process resumes. Each final audit binds 75 runtime capture entries and 57 artifact/runtime comparisons. Repeated captures are not 75 distinct contracts. No unchanged suite was replayed.

## Qualifications that remain explicit

This is a bounded local immutable delivery of the stopped candidate, not full-plan acceptance, target-gas acceptance, operational allocation approval, or a public operation. ED and ER conversion remain blocked. Final strict typechecks passed. TypeScript LSP freshness was not reliable, and Bash LSP is unavailable. Those tooling gaps are not claimed as passes.

Independent wire capture retains 1762 HTTP response bodies, 584 canonical transaction objects, and 584 canonical receipts over 592 mined blocks. `verification/audit-final.json` `wire.fieldProof` classifies 417 as `canonical RPC fields, not captured raw signing bytes` and 167 as `Anvil impersonated acquisition/fixture transaction: synthetic r=s=1, no cryptographic signer claim`. The independent report states that those 417 reconstruct to their actual hash and signer. This commit lane did not recapture or reclassify them. Four inherited acquisition signatures remain `offline deterministic reconstruction; not original signing capture` in both audit runs, beside 89 raw signed records. Reconstructed bytes are not originally captured raw signing bytes. No transaction was sent by this commit lane.

Producer `implementation/audit-final.json` retains 48 prepared-input drift records, 12 for each of the four ABI files below, after its supplemental compilation. Its 24 exact original captured input files remain. Current on-disk ABI bytes match those captured originals. Both independent audit runs report 0 present drift. Current equality does not erase the historical observation, and this lane did not restore, delete, or rewrite `out/` or `cache_forge/`. The preservation baseline is that current post-verification tree.

| Current ABI file | Bytes | Captured and current SHA-256 | Historical producer-audit current SHA-256 |
| --- | ---: | --- | --- |
| `out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json` | 100740 | `748234305d20186497acbc40cee592095c3c25ba1c3268162db6f0ee81d8922b` | `1bf1b10eefdc08b91ab99177a82426aef758e946fc084630bf442c97735c3ebd` |
| `out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json` | 289236 | `10ef5c19757677bd2978d3e5903ae819d6da32f64e766c946626795efe92f599` | `cd11e7a938448592e5dfff23489ef22934494e4def5ed5712379ab30b0a6e880` |
| `out/IUniswapV4DetfMigrationDFPkg.sol/IUniswapV4DetfMigrationDFPkg.json` | 98419 | `13583717f202e217adb9e0b4820c8e4cf778ac54a709637c65ccaeec535a49fe` | `246a61e854dc82273290fdc93e502c999644dc479cd696d05b2bbe57ecf4a730` |
| `out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json` | 56070 | `45a156bdeb2e86d02170e91d40d7635b570f20afce9c146032aacb060cddfe09` | `dbeb056b3ea2bec175768ed70a39a2ea3e174efca0fac123e2bd8c78d57807c3` |

The frozen producer receipt auditor rejects a legitimate odd-digit fresh RPC signature scalar. The independent quantity-correct verifier authenticates that scalar without changing source or witnesses. This is the disclosed producer-auditor portability limit, not a clean producer-auditor replay and not a source defect. Inherited ER ABI source-unit-ID reconstruction qualifications remain historical and were not rewritten.

The fresh actual signed parent deployment uses **44,863,086 gas**, above the retained 32-million limit. Prior parent gas 44,653,392 remains the earlier open observation. Neither figure was rerun or relabeled as target-gas acceptance. Actual sizes Allocation 23999, Recovery 21587, ClaimVaultAllocation 10296, and principal Migration 24408 satisfy EIP-170. Local gas ceilings remain rehearsal settings.

The three genuine fresh mined-before-checkpoint resumes remain funding `0x5ad9f813667387d31d33a6680721398a31610767a5807425a5899e0b189fe958`, independent issuance `0xcedc64cad7ba70516c2a09f59b03889f370ca89d4dbff09b23abd8d3e00bc38e`, and paid owner-first bond `0xb953c166c6cd4a304b8c4933af23c8008fd939f3dda8f0911b7464138dead9b4`. They were not replayed.

ED and ER conversion, operational original datasets, opaque-origin reconciliation, other source rows, raw TokenStaking, native/WETH exposure, source-match and optional-facet qualifications, archive/host portability, and full hermetic/full-plan acceptance remain open. Positive inherited ER/WS nonrepresentable residue is recorded state, not a pending operation.

The separate older ED source worktree remains at `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source`. Its admitted `source/contract.md` is SHA-256 `86d4cf1d517b688b6b3aa8da73b00252c171d22182d92cb56a7e70f93d5339b4` and `source-verification/report.md` is SHA-256 `e56481a5040ae406b1c14122d404e227a0ea4391ecb03dd54b77283142b1af1b`. They were not deleted, relocated, or rewritten. `lib/crane` remains a symlink to `/Users/cyotee/Projects/indexedex/lib/crane`, inode `19477553`, mode `0755`. `node_modules` remains a symlink to `/Users/cyotee/Projects/indexedex/node_modules`, inode `19477554`, mode `0755`.

## Preservation

Precommit inventories were captured before any `commit/` file existed and are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`, SHA-256 `9917515ce883c91199aefc142d094ebc09e26240848ddb259fa5c405aff387d4`. The git-mode serialization is UTF-8 JSON Lines, one object per line, keys `path`, `kind`, `mode`, `size`, `sha256`, `target`, sorted by POSIX path. That git-mode field collapses non-executable regular files to `100644` and is not a read-only-mode proof. The permission inventory `docs-incidents-perms.jsonl` records `perm` as `oct(st_mode & 0o777)` and is the encoding for sealed read-only modes.

- All **1080 pre-commit `docs/incidents` git-mode entries** retain identical path/kind/mode/size/SHA-256/target inventories. Inventory hash `f1f756066474d7a0c55a2b50183f90b84a862bebdbf01b702fe5443b2383f18b`. Post-commit rewalk, before this receipt and `source-manifest.json`: 0 missing, 0 changed, 16 new paths, all under excluded `commit/precommit/`. This receipt and `source-manifest.json` were written after that rewalk and are also excluded.
- All **1150 pre-commit permission entries** retain identical path/kind/perm/size/SHA-256 except the directory-size change caused by creating `commit/`: `docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid` 128 to 160. Inventory hash `e45b44ee1650c8958d1076c5721ce817b2a4b1b9609c48eac51385a50f58a910`. Post-commit rewalk: 0 missing, 0 file changes, 18 new paths. Those new paths are the excluded `commit` directory, `commit/precommit`, and the 16 precommit files. Sealed file modes and hashes are unchanged. No historical report, binding, snapshot, witness, log, journal, or seal was rewritten or chmodded.
- All **7343 `out/` entries** retain inventory hash `bb19ac57b3c690b884825f476317d17b83a4ca7efea7864f9b548b3949848af4`. Post-commit rewalk: 0 missing, 0 changed, 0 new. No build, deletion, or artifact restoration was performed.
- All **605 `cache_forge/` entries** retain inventory hash `07553006db203678e9d2f3de779e62d0398101c4fd088ef7c2c6a5591b61f5cd`. Post-commit rewalk: 0 missing, 0 changed, 0 new.
- All refs other than `work/dtf-migration-phase-19-earlier-liquid` remain identical. The only ref movement is this branch from `1df9076c73b94a4f63172395763fa8cdd48fe060` to `3ec0912bafebf9c0aa66770a72f04501e5c11865`. `show-ref` baseline SHA-256 `822b6ce5ba8c5cb1b28819f4bcf60fe94ff1cb2348e7a21a661a7acf359a6bdb`. No held phase09 candidate was read, imported, tested, or committed.
- Twenty-one foreign worktree indexes are unchanged. This worktree index changed from `1fb8d0ea7e8a03bc8eb6e93de3ee92812c6f52f29381093df5a26a214c70da7a` to `8b4043cf4994258e1374f383aecce4eb06ad4b1fded56d570ee56df7a571601f`. The index matches the new commit: staged diff empty and `git write-tree` equals `c3531bcea33a4bd55a1c49e894243bbbd37afc25`.
- All **1490 bound external host inputs** — 26 authority files, 78 immutable source-only files, and 1386 parent-preserved phase18 producer files — retain identical size, mode, and SHA-256. Inventory hash `8d26437c76e3fefe921fe4edc32d5eaa1d9c6b52560a923c00c35028e2f0723f`. They were not deleted, relocated, or rewritten.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the 32 accepted paths. No merge, cherry-pick, rebase, or index lock is present.
- Port 18569 listener check exit 1 with empty output. The checkpoint and runtime parent are absent. Commit and inspection processes completed. **No pending operation.**
