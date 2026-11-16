# Verified finite named receipt evidence local source delivery

Date of the commit: 2026-11-12 21:59:13 -0800. Status: **complete for this ten-file local source delivery only**.

## Exact local commit

- Commit: `07d54b9a3d20d98aee24e75235bbf16b650a8028`
- Subject: `Add verified bounded finite receipt evidence collector`
- Parent: `789fced820ed494d9651c598fb8f75c646d727a7`
- Tree: `edac46fc0506fc522a9409adc2b4917214544398`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-12T21:59:13-0800`
- Committer: `Cyotee Doge <not_cyotee@proton.me>`
- Committer date: `2026-11-12T21:59:13-0800`
- Branch: `work/dtf-migration-phase-28-receipt-evidence`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence`
- Exactly **ten paths**: two modifications and eight additions. Numstat is 860 insertions and 0 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once and no other trailer.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. `git -c gpg.program=/usr/local/bin/gpg verify-commit HEAD` exit 0. `%G?` is `U` because ownertrust is unknown; that is not a bad signature. Stored `gpg.program` remains unset. The commit invocation used the same one-shot `-c gpg.program=/usr/local/bin/gpg` override and did not write git config.
- Exactly one commit after the required parent. `git rev-list --parents -n 1 HEAD` is `07d54b9a3d20d98aee24e75235bbf16b650a8028 789fced820ed494d9651c598fb8f75c646d727a7`. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{upstream}` exit 128). No fetch or push was attempted.
- `core.hooksPath` is `.husky/_`. That directory does not exist in this worktree. Commit stderr was empty. The common `.git/hooks/post-commit` Git LFS hook was not on the configured hooks path and did not run. No hook output was observed.
- The source commit excludes this manifest, this receipt, the precommit inventories, and all other evidence. Evidence remains local and uncommitted. `git ls-tree -r HEAD -- docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence` is empty.
- `source-manifest.json` raw SHA-256: `2a40960a0832506b208483bebae00e9433ab874461d94c10b362812550a91f2f`, 26806 bytes. This receipt does not claim its own raw digest. `preservation-compare.json` raw SHA-256: `f5628b2bb96850aea229c8cf1fd5fa67d9fbac3563ff476a6379e86d0be0bb10`, 4171 bytes. That compare file does not claim its own digest inside itself; the hash here is of the file as written before this receipt.
- Raw commit object: 1202 bytes, SHA-256 `2647508e86a5a742aece5b7aff0e5dc23731122ad6cae1149e9d52a254acb686`. The `gpgsig` header is a signature header, not a second trailer.

## Source provenance

Accepted paths and hashes come from `phase28-receipt-evidence-commit-source.json` and the independently accepted verifier report, not from a directory listing. The verifier report was rehashed before staging: 20647 bytes, SHA-256 `77bb12de3b210f0091d4f7409fdb52eff81b1fec5d8cc11dce0db38897bfa5aa`. That matches the accepted report binding and `verification/seal.json`.

Current, staged, and committed bytes match the accepted SHA-256 and length for all ten paths. `git cat-file blob HEAD:path` equals the worktree bytes for every accepted path. Git mode is `100644` for every committed path. Filesystem `lstat` mode captured before staging is 33188 / `0o644` for every accepted path. Parent blobs are `0e2ab13e25ab39ab5156d498aefd2e82317a86ac` for the runbook and `0e8a31cf01b19b101c632cf6e642c48f11f70875` for `cli.ts`. The eight additions have no parent blob. Committed blob ids are in `source-manifest.json`.

Tested `implementation/source-manifest.json` records bytes and SHA-256 only. The accepted verifier report and seal do the same. They omit filesystem modes, Git modes, and permission bits. This delivery does not invent historical tested mode evidence. The modes above are current filesystem and Git observations. Predicted Git mode from the non-executable filesystem bit matched the staged and committed `100644` mode.

All 70 tested operator/runbook identities were rehashed after the commit and before this receipt. Zero mismatches. Sixty of those identities are not in this commit. Their paths and hashes are `unchangedFrozenNotCommitted` in `source-manifest.json`. The full tracked diff against the parent, inspected before staging, is 65 insertions and 0 deletions in the runbook and 14 insertions and 0 deletions in `cli.ts`. The eight new bodies were read in full. They separate recovered-input references, finite existing-alias RPC capture, canonical association, purchase/claim reconciliation, collection, wire fixtures, and two behavioral test modules. The CLI addition is an import, a help line, and one narrow command case. The runbook addition is the finite receipt section. No evidence or archive JSON is in the commit.

`core.autocrlf` is unset (`git config --get` exit 1). `git check-attr -a` on the ten paths produced empty output. No newline conversion was observed. Staged blob bytes equaled worktree bytes before the commit.

Before the commit, after staging only those ten paths, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check 789fced820ed494d9651c598fb8f75c646d727a7
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
```

After the commit, `git diff --ignore-submodules=all --check 789fced820ed494d9651c598fb8f75c646d727a7 HEAD`, `git show --check --format=`, `git diff --cached --ignore-submodules=all --check`, and `git diff --ignore-submodules=all --check` exited 0 with empty output. No source byte was edited to satisfy whitespace. The index tree equals the commit tree `edac46fc0506fc522a9409adc2b4917214544398`. Staged and unstaged tracked diffs are empty.

## Verification performed here

- Read the commit brief, accepted source bindings, the phase28 brief, and the complete implementation and verification reports, seals, cleanup records, and command proofs. No types, tests, collector, oracle, build, or Forge command was rerun.
- Seal member hashes were recomputed before staging. All 17 implementation and verification seal members matched, including both actual archives. Zero mismatches.
- Producer command exits read from the recorded command files, not rerun: `types01` exit 2, `mutation01` exit 1, `focused01` exit 0, and `types-final`, `operator-tests-final`, `collect`, and `independent` exit 0. Independent command exits read the same way: types, tests, collect, oracle, boundary, and scan all exit 0. The first compiler event remains a summary with a session locator, not retained raw compiler output. `mutation01` is the recorded deliberate broken-guard failure, not a current source defect.
- Staged blob bytes and mode matched the worktree and the accepted SHA-256 before the commit. After the commit, sole parent, subject, exactly one coauthor trailer, `diff-tree` path set, and committed/current/tested SHA-256 all match.
- Biome is not installed in this worktree. Its language server is unavailable. That is not a passing diagnostic. No install or configuration change was made. Basedpyright was already recorded unavailable by the verifier and was not relabeled clean.

## Qualifications that remain explicit

This is a local delivery of the tested finite named-receipt collector, not operational approval, historical eligibility, an approved loader dataset, full Task 9, or Migration completion. Archive status remains `NON-ISSUABLE-RECEIPT-OBSERVATIONS`. Existing prepare, prepared-envelope, and execution loaders reject that document. Those loader rejections were not rerun here; they remain the sealed verification results.

The accepted independent gate, not rerun here, is strict types exit 0 and one complete operator-test invocation: **159 pass, 0 fail, 15 files**. One producer collection and one independent collection each authenticated 77 references, 310 responses, 2368 logs, and 568 saved Transfer locators. The main outputs are byte-identical across those two actual calls through the same existing provider. That is not independent-provider consensus. `actual/archive.json` is 3848804 bytes, SHA-256 `e390e13162b566cd4c138a4342e4e1186dc3053526e9743454db3d92d637839b`. `actual/reconciliation.json` is 251139 bytes, SHA-256 `c1717f1e35984ff03aeddd16c6a7571439e8066f4160fdeec2f7f844ced1577e`. Those files are evidence and are not in this commit.

All **20** conservative routing/caller flags remain. Fifteen earlier `routed-dtf` flags are comparison-scope differences between the saved SE-routed component and a separate LP-address inflow, not false historical errors and not new contributions. Weighted IDs 19, 20, 23, and 42 retain `indirect-purchase-or-different-caller`. `conversions.csv#row=21` retains `indirect-or-unexpected-claim-call`. Its source event names `0x2c0400cf47e5ea01364e44c237aed22d7ae86199`, but `decodedDirectWeight` stays null. The current direct-EOA claimed-SY validator does not thereby admit it. No source-policy change and no unsupported outercall decoding were made. Observations are not eligibility or direct-call proof.

The recorded credential scan found 0 matches. It was not rerun for this delivery. New commit outputs contain public identities, source diffs, and hashes. They do not contain a provider credential or a wallet key.

E-S, broader eligible T claim conservation, disabled downstream conversion, current control, recovery coverage, reviewed operational originals, selected real composition, and target deployment gas remain open. The retained registration measurement is **45116678 > 32000000**. ETH/WETH remain provenance, funding, and recovery, not invented standalone compensated surrender requirements.

P1 remains two missing historical raw artifact versions:

| Historical artifact | Bytes | Required SHA-256 |
| --- | ---: | --- |
| `out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json` | 466441 | `e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf` |
| `out/MigrationNativeHandler.sol/MigrationNativeHandler.json` | 266621 | `3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013` |

This commit does not reconstruct or erase those versions. Exact universal historic build pedigree is not claimed.

## Preservation

Precommit inventories were captured before any `commit/` file existed and before staging. They are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`. Aggregates below are SHA-256 of the inventory bytes and are not substitutes for the rows. Symlink targets were not opened. `cache/` does not exist; Foundry `cache_path` is `cache_forge`. That absence is recorded in `cache-absent.json`, not filled with an invented tree.

Git mode `100644` is not the permission proof. The comparison used `perm` and full `st_mode`. The baseline contains 80 `cache_forge` regular files at `0o600` / 33152. Those rows were unchanged in the full pre-support permission compare. Every other walked regular file in these roots was `0o644` / 33188. Directories were `0o755` / 16877. No symlink was inside the walked evidence, artifact, or input roots. The two host dependency symlinks are recorded separately.

A complete rehash before any `commit/` file existed compared every content, permission, and directory row with **0** mismatches. That result is `commit/precommit/preservation-compare-before-support.json`. It includes the expected own-index and branch-ref changes and no foreign-index or unexpected ref change.

- All **1482** `docs/incidents` content rows match. Content inventory `cb93f97f44428468317387be06cf720bee4b84a717c93b37830290be50cc8268`, 430767 bytes. Permission inventory `36c901dadbd694556a72fcdebc888aa811860de98cce44292dad97bc33b852d5`, 404379 bytes, 1493 rows. Directory inventory `462c6b87eecde3ce6d5916c31e237ea5882d73a00160bf23412fd02bca1e7074`, 2987 bytes, 11 rows.
- All **7376** `out/` content rows and **13856** permission rows match. Content inventory `6673598e3a68c4b3dd7d747ffea0027f9c55f566c259faff4453b299a9db1771`, 1960530 bytes. Permission inventory `6c69936bfe945823dca2d1b60a81897870c422a976d4b8a9d638e4c2c9dfb72a`, 2721030 bytes. Directory inventory `d03b074d76065dcf7f1220e0768c576178d43e5e4a4e35d432482a12f3822b2b`, 1607013 bytes, 6480 rows. No build, deletion, restoration, or relocation was performed.
- All **6502** `cache_forge/` content rows and **12368** permission rows match. Content inventory `167a70ddc88be51f57510a8ed99510b778850e635a26f64009b0c64c73750744`, 2297269 bytes. Permission inventory `ad05142c9779921a1abba60f51f25985a4caf985568a18a64702422e24237e4c`, 3518453 bytes. Directory inventory `63191ac7ad8bbb9de239a5d82ea4fba393ab8d55564110f21ae5b159cd15a39f`, 1984142 bytes, 5866 rows.
- All **30** recovered-input content rows and **35** permission rows match. Content inventory `a28a29eb85372bf3c41c3f4d461475b7b0aaba7d9bfbdb8ead12b2f222c44800`, 7898 bytes. This is the collector input root `phase27-frozen-input-recovery`, including `recovery.json`, `validation.json`, and the recovered historical bodies.
- All **25** original incident content rows and **27** permission rows match. Content inventory `a29c461c60b788748e935c485444eec646d677becabf9f967752f8bceada12de`, 5668 bytes.
- All **29** foreign Git indexes are unchanged. This worktree index changed from `47760b282e13f83c77f8be9a22b49b06bb5f9fd92bf21239728341cbb6c8b570`, 2077579 bytes, to `64f80d782c15e24157675abb4b0057a32bd7e46001789077028743aa60ac391d`, 2078515 bytes, mode still 33188. The index matches the commit: staged diff empty and `git write-tree` equals `edac46fc0506fc522a9409adc2b4917214544398`. The baseline records 30 indexes: 29 foreign and 1 own.
- All **56** ref rows remain except `refs/heads/work/dtf-migration-phase-28-receipt-evidence`, which moved from the parent line to `07d54b9a3d20d98aee24e75235bbf16b650a8028`, both 41 bytes, mode 33188. `show-ref` changed only that one line. Both `show-ref` captures are 6579 bytes and 68 lines. Reflogs were not in the preservation set.
- Both host dependency symlinks are unchanged: `lib/crane` target `/Users/cyotee/Projects/indexedex/lib/crane`, mode 41453, inode 20472031; `node_modules` target `/Users/cyotee/Projects/indexedex/node_modules`, mode 41453, inode 20472032. Targets were not opened. The `lib/crane` gitlink remains `160000 fc0618bf5c34d0564f4367130feff443bd4efc89`. `node_modules` remains ignored.
- Ten named authority files match their precommit hashes and modes. They are regular files, not symlink targets. No path under the phase09 worktree or a held09 worktree was opened. The phase09 foreign index, when present, was hashed only as raw bytes under `.git/worktrees`.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the ten accepted paths. No merge, cherry-pick, rebase, or index lock is present.

## Additive evidence-directory growth

The full rehash above was taken before `receipt-evidence/commit/` existed. At that point every original content, permission, and directory row matched. The support files were written after that proof. They are excluded evidence, not a preservation failure of an original row.

After the inventories and `source-manifest.json` were written, and before `preservation-compare.json` and this receipt, the `docs/incidents` rewalk found 46 additive content paths, 48 additive permission paths, and 2 additive directory paths. All of them are under `receipt-evidence/commit/`. Unexpected additive paths: none. Original content rows changed: 0. Recovered-input and original-incident rows were rehashed again and were unchanged. `out/` and `cache_forge/` root directory bookkeeping was unchanged after the support write. Their full per-entry proof is the pre-support rehash, not a second full artifact walk. Support writes did not target those trees.

Original directory rows whose bookkeeping changed because of that added child: 1.

| Path | Kind | Mode | Before size | After size | nlink | childCount |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence` | dir | 16877 / `0o755` | 128 | 160 | 4 to 5 | 2 to 3 |

Kind, permission, and `st_mode` did not change. Directory SHA-256 remains null. `childrenSha256` moved from `6427893862c3486e1889c0f3958e78f4e1423eaf68bdb0c670238d58b2430259` to `c7fc894590f20266a5c6109144443da05e87deae03aa23b777e5132c15e9af1d` because the child set gained `commit`.

`preservation-compare.json` and this receipt are two later additive files under the same `commit/` directory. Neither is a member of the 46-path additive list. This receipt is the last file written in that directory.

**No pending operation.**
