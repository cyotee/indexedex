# Verified bounded held SE/LP local source delivery

Date: 2026-11-12. Status: **complete for this bounded local source delivery only**.

## Exact local commit

- Commit: `4eaa7decab80d24cf37cb3781eff5ffaf9362942`
- Subject: `Add verified bounded held SE/LP custody and credit`
- Parent: `3ec0912bafebf9c0aa66770a72f04501e5c11865`
- Tree: `97240957d250487230589e445797e2d6610ceccf`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-12T04:59:24-08:00`
- Committer: `Cyotee Doge <not_cyotee@proton.me>`
- Committer date: `2026-11-12T04:59:24-08:00`
- Branch: `work/dtf-migration-phase-21-held-se-lp`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-21-held-se-lp`
- Exactly **35 source/test/operator/runbook paths**: 30 modifications and 5 additions, 1528 insertions and 34 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. `git verify-commit` exit 0. GnuPG also prints unknown ownertrust; that is not a bad signature. The one-shot commit used `gpg.program=/usr/local/bin/gpg` (GnuPG/MacGPG2 2.2.41) so signing matched the running agent. Stored `gpg.program` remains unset.
- Exactly one commit after the required parent. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{upstream}` exit 128). No fetch or push was attempted.
- The source commit excludes this manifest, this receipt, the precommit inventories, and all other evidence. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `a4290758cd58127a815c0538195d389b459008e1ad306d57ccc1324259f0f082`. This receipt does not claim its own raw digest.

## Source provenance

`source-manifest.json` binds every candidate path, mode, accepted SHA-256, producer SHA-256, both independent-audit SHA-256 values, current SHA-256, committed SHA-256, Git blob, and parent blob. The candidate set was derived from `verification/audit.ts` and `implementation/bindings.ts` rebinding `implementation/source-manifest.json` `source` into `verification/audit-final.json` `results[0].bound.preserved[0:35]` and `results[1].bound.preserved[0:35]`, cross-checked to the producer source array and the actual parent/index/worktree delta. It was not taken from a directory listing. All 35 current bytes match the verifier accepted SHA-256, the producer binding, both audit bindings, and `git cat-file blob HEAD:path`. There is no post-runtime source-hash exception.

Producer `acceptedMode` 420 is decimal `st_mode & 0o777`, which is `0o644`. Full `st_mode` 33188 is `0o100644`. Every tracked parent mode and all five new files are regular non-executable files and were committed as `100644`. `core.autocrlf` is unset (exit 1). Worktree bytes, committed blob bytes, and accepted SHA-256 values match for all 35 paths, so no newline conversion was observed.

Before staging, `git diff --ignore-submodules=all --check` on the tracked candidate exited 0. That did not cover the five untracked files. After staging only the 35 accepted paths, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check 3ec0912bafebf9c0aa66770a72f04501e5c11865
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
```

After the commit, `git diff --ignore-submodules=all --check 3ec0912bafebf9c0aa66770a72f04501e5c11865 HEAD` exited 0 with empty output. Accepted hashes were not a waiver. No source byte was edited to satisfy whitespace.

Independent acceptance is the complete `verification/report.md`, raw SHA-256 `989a09b0ea2a3b73863df3c3fa7c4ba89b54b70f7d7af22e534998c4809e2df4`, disposition confirmed for bounded W-SW, E-P and W-P custody and frozen credit. That hash was recomputed from the file after the commit and still matches the admitted value. Producer seal `implementation/seal.json` remains `2e84389b5604aff83f600fc727b7d904884462c366264e1afc67f5ddb8fb7459`. Verifier seal `verification/seal.json` remains `feac04e48c4231284f47b386cafe787993b87447ebc34705ef5ca247c1bcbeec`.

Eight production roots are exclusively Migration-specific: allocation target, claim-vault allocation facet and target, recovery facet and target, repo, migration interface, and legacy recovery library. The five additions are `held-se-lp.test.ts`, `rehearsal-held-se-lp-source.ts`, `rehearsal-held-se-lp.ts`, `MigrationHeldSeLp.t.sol`, and `MigrationHeldSeLpConfiguration.t.sol`.

## Verification performed here

- Read the complete commit brief, the implementation brief, the complete producer report, and the complete independent verification report. Verified the report hash, the four phase20 admission hashes, branch, parent `3ec0912bafebf9c0aa66770a72f04501e5c11865`, empty incoming staged set, and recent subject-only commit convention.
- Read the entire tracked candidate diff and all five added files. The tracked diff is byte-identical to `verification/candidate.diff` (75884 bytes). The diff is confined to Migration interfaces, storage, allocation/recovery facets and targets, the legacy fixed-source predicate, adjacent specs, the existing operator/stage home, and the runbook. No ordinary/common/Crane production, dependency, configuration, provider, or held09 path is in the commit. No conversion, debit, donation stage, success decoder, or production collector-owner method was installed. Fixture `pullFee` use stays in the fork test and rehearsal acquisition file.
- URL/signing-material inspection found no URL and no embedded private key. The public Anvil mnemonic, the archive alias `robinhood_mainnet_alchemy`, and the pinned block are inside the independently accepted bytes and were not stripped. Held SE/LP signing is gated to `127.0.0.1` port `18571`. Inherited ED/ER/WS/claim-vault/W-SD signers remain gated to `127.0.0.1` ports `18567`, `18568`, `18569`, and `18571`. The runbook names the archive alias and does not embed a resolved endpoint.
- Staged blob hashes and modes matched worktree bytes and the accepted SHA-256 set before the commit. After the commit, `HEAD^`, one-child count, subject, exactly one coauthor trailer, `diff-tree` path set, and each committed `ls-tree` mode/blob plus committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the new commit tree `97240957d250487230589e445797e2d6610ceccf`.
- Prior independent runtime evidence was corroborated from its sealed report and final audit JSON, not rerun: 167 specs, 139 pinned forks, 88 operator tests, strict operator types, both operator-stage builds, and the actual fixed 18571 CLI with three real mined-before-checkpoint/fresh-process resumes. `audit-final.json` is 21061917 bytes, SHA-256 `b3db9108d65b774436452b706c6f151d52e95133b956ff267af12d9fa937e64d`. No unchanged suite was replayed.

## Qualifications that remain explicit

This is a bounded local immutable delivery of the stopped candidate, not full-plan acceptance, target-gas acceptance, operational allocation approval, liquidation acceptance, or a public operation. E-S remains unsupported. All three new conversion routes remain blocked.

Independent wire capture retains 1999 HTTP response bodies, 663 canonical transactions, and 663 canonical receipts over 671 mined blocks. Of these, 491 nonsynthetic signatures reconstruct to their actual hash and signer, and 172 are Anvil synthetic fixture transactions with r=s=1. Within those captures, 155 originally retained raw signed records and four offline deterministic acquisition reconstructions are separately reconciled. Those subsets are not additional transactions, and reconstructed signatures are not original captures. This commit lane did not recapture or reclassify them. The fresh raw HTTP file is 8608048 bytes, SHA-256 `f2e69c864b25f41bc15d49a66d3ef8530543430b3480e56f4e1709d375414be8`. No transaction was sent by this commit lane.

All five donor operations are impersonated local fixtures. E-P and W-P release requires the existing external EOA collector owner and a personal donation on a disposable fork. That proves no donor-key control, public consent, claimant authority, Migration-owner privilege, or production operator method. Donated holdings are not historical allocations. Synthetic original ETH/DTF components remain disclosed code-proof inputs.

All 30 original producer prepared-input captures are lossless and retained. The producer sealed a zero-drift observation; this lane did not rewrite it. Required independent compilation changed three raw interface top-level source-unit IDs only: Allocation and Migration 758 to 534, package 760 to 536. A structural comparison finds only those `$.id` differences. Thirty-six repeated producer-manifest references use the exact original captures. The fresh run has zero prepared-input drift, and its current raw inputs are separately captured under `verification/fresh-captured-inputs/`. No artifact was restored, normalized, or presented as an original capture. Earlier ED 48-entry drift and ER ABI reconstruction qualifications remain historical.

| Current ABI file | Bytes | Original capture SHA-256 | Current SHA-256 | Only structural difference |
| --- | ---: | --- | --- | --- |
| `out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json` | 103627 | `c93ee1f607d3f95d0c28d9ce559467f11df286556574aa575781f29399d6feee` | `9d5db7a8a1feababc1c418dbe1c9e6b1ee06b6cd009f292023fb65515bb4f2a6` | `$.id` 758 to 534 |
| `out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json` | 304055 | `ca8565803eadc70c6c93a892617869dba1417c1654466e34a9d4e6a12a7ef443` | `2390044653174e85ad007efd22b68821f7b1e831b7cfd20b63896dc65a04677f` | `$.id` 758 to 534 |
| `out/IUniswapV4DetfMigrationDFPkg.sol/IUniswapV4DetfMigrationDFPkg.json` | 98419 | `3da38597a23ed9d460c132a971a30e3831c14ca70b7e7be2d49d50a63117dbbc` | `0c5586a948c974a672d5260a5c24b478c660cdfaf04de720fd43147fcfa690ce` | `$.id` 760 to 536 |

The independent empty-array display conversion failure in the first owned audit remains recorded in `verification/failed-attempts.md`. Only the owned probe changed to byte-exact ABI comparison. No required suite was replayed to repair that evidence-only bug. Final strict typechecks passed. Audit TypeScript LSP reported no errors; raw-checks LSP freshness timed out. Bash and JSON LSP are unavailable. Those tooling gaps are not claimed as passes. Forge compiler and lint warnings remain visible in the retained logs.

The fresh actual registration uses **45,116,678 gas**, above the retained 32-million limit. Prior parent gas 44,863,086 remains the earlier open observation. Neither figure was rerun or relabeled as target-gas acceptance. Actual sizes principal 24408, Allocation 24100, Recovery 22704, ClaimVaultAllocation 11221, and package 16714 satisfy EIP-170. Local gas ceilings remain rehearsal settings.

The three genuine independent mined-before-checkpoint resumes remain funding `0xe3c3d25c6f654d2d43049103959540c01a923e257a59549871d0a02bf1558f22`, independent issuance `0x5635828beb4c23bee076f05f0a116a4bda678e760a2df1cb269112835da0b7b1`, and paid owner-first bond `0xee8b7bb0308538c1a9846ea8c353b998f5e6d0769affd30aa6b4bde8ace99833`. The producer's three original resume witnesses are separate and were not substituted for these. They were not replayed.

E-S, all three blocked conversions, operational original datasets, opaque-origin reconciliation, raw TokenStaking, native/WETH exposure, source-match and optional-facet qualifications, archive/host portability, full hermetic/full-plan acceptance, and target gas remain open. The source20 `stopRecorded=false` summary discrepancy was not rewritten; its actual stop RPC and stopped node control. Root 93 purchaser-balance reads were all zero and are not a census. The read-only E-S mint attempt's VaultDisabled is not a funded positive fixture. Positive inherited ER/WS nonrepresentable residue is recorded state, not a pending operation.

Phase20 admissions were rehashed and still match: `source/contract.md` `330c2ce3f77ad20976c27377aec832d375d7f5c615a00d16cdab66946f660df3`, `source-verification/report.md` `c1d452153e3c1483e9ed862ce8a46e55aad2cdfbaef15b94d20f15f24fddcb45`, `owner-funding/contract.md` `436baf660e440d1c12a66bc6912565f3ef7905183fc87f816959b5c4b8af7184`, `owner-funding-verification/report.md` `a8526fb709fd37c163e04a03885c601f423976c9d3baa7acdcfb413a295e2fb3`. They were not deleted, relocated, or rewritten. `lib/crane` remains a symlink to `/Users/cyotee/Projects/indexedex/lib/crane`, inode `19607440`, mode `0755`. `node_modules` remains a symlink to `/Users/cyotee/Projects/indexedex/node_modules`, inode `19607441`, mode `0755`.

## Preservation

Precommit inventories were captured before any `commit/` file existed and are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`, SHA-256 `973c763f3dfef88926f39c10208ef1ec61acbe602c5a47195e4989bb24e05484`. The git-mode serialization is UTF-8 JSON Lines, one object per line, keys `path`, `kind`, `mode`, `size`, `sha256`, `target`, sorted by POSIX path. That git-mode field collapses non-executable regular files to `100644` and is not a read-only-mode proof. The permission inventory `docs-incidents-perms.jsonl` records `perm` as `oct(st_mode & 0o777)` and is the encoding for sealed read-only modes. Host rows include `role`. Six paths are both authority and immutable; path is not a unique key, and reproduction compared every row.

- All **1268 pre-commit `docs/incidents` git-mode entries** retain identical path/kind/mode/size/SHA-256/target inventories. Inventory hash `363d87323065b135d9b58c0fd4bfc3cf7f539bd781d0d3284162bfac4bf96a99`. Post-commit rewalk, before this receipt and `source-manifest.json`: 0 missing, 0 changed, 16 new paths, all under excluded `commit/precommit/`. This receipt, `source-manifest.json`, and `preservation-compare.json` were written after that rewalk and are also excluded.
- All **1339 pre-commit permission entries** retain identical path/kind/perm/size/SHA-256 except the directory-size change caused by creating `commit/`: `docs/incidents/2026-09-16-dtf-recovery/migration/held-se-lp` 128 to 160. Inventory hash `5fbb993da1344951dad811dda4db01dedd908ae6bcd4a70399be728519b9391e`. Post-commit rewalk: 0 missing, 0 file changes, 18 new paths. Those new paths are the excluded `commit` directory, `commit/precommit`, and the precommit files. Sealed file modes and hashes are unchanged. No historical report, binding, snapshot, witness, log, journal, or seal was rewritten or chmodded.
- All **7353 `out/` entries** retain inventory hash `a8ee22bfe6a9dc2a8b3d7945fce853250695ab1a2845752016b9f9c8c5a0a3b4`. Post-commit rewalk: 0 missing, 0 changed, 0 new. No build, deletion, or artifact restoration was performed.
- All **607 `cache_forge/` entries** retain inventory hash `c47eb850636d9345741cd480f3ead9a10505941e7cc7c2b94e1e31e5ff9c6388`. Post-commit rewalk: 0 missing, 0 changed, 0 new.
- All refs other than `work/dtf-migration-phase-21-held-se-lp` remain identical. The only ref movement is this branch from `3ec0912bafebf9c0aa66770a72f04501e5c11865` to `4eaa7decab80d24cf37cb3781eff5ffaf9362942`. `show-ref` baseline SHA-256 `eea60689ef187361a0e74c6679a0bf5148a636e8a88e3c970a32ea32dbf2eb5a`. No held phase09 candidate was read, imported, tested, or committed.
- undefined foreign worktree indexes are unchanged. This worktree index changed from `c7826a05a19e32d5027007602a91cac4941d7409cfde62502cd9923efb9ad6f8` to `3062b9c9b66505c209450f11a7da5b25fc61de9a0f094722993631b7cca19286`. The index matches the new commit: staged diff empty and `git write-tree` equals `97240957d250487230589e445797e2d6610ceccf`.
- All **2621 bound external host-input rows** — 11 authority, 1224 external immutable, and 1386 parent-preserved phase18 producer rows, 2615 unique paths — retain identical size, mode, permission, and SHA-256. Inventory hash `1fec2ce75aeb420b3269ea9ded81b88312d0b2061fcfd5ea4f01b379691337f4`. The 78 earlier-liquid source-only files are inside the external immutable set. The 13 in-worktree immutable files are covered by the docs/incidents walks and were unchanged. They were not deleted, relocated, or rewritten.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the 35 accepted paths. No merge, cherry-pick, rebase, or index lock is present.
- Port 18571 listener check exit 1 with empty output. The checkpoint and runtime parent are absent. Commit and inspection processes completed. **No pending operation.**
