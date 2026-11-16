# Verified offline historical review candidate local source delivery

Date of the commit: 2026-11-12 20:14:52 -0800. Status: **complete for this ten-file local source delivery only**.

## Exact local commit

- Commit: `789fced820ed494d9651c598fb8f75c646d727a7`
- Subject: `Add verified bounded historical review candidate derivation`
- Parent: `0856a5c56e5d09b81c669f59b613efef79133e19`
- Tree: `cbdb3081d1264ba05c3b9f1345aaff3c66cacf2e`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-12T20:14:52-0800`
- Committer: `Cyotee Doge <not_cyotee@proton.me>`
- Committer date: `2026-11-12T20:14:52-0800`
- Branch: `work/dtf-migration-phase-27-data-candidates`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates`
- Exactly **ten paths**: two modifications and eight additions. Numstat is 955 insertions and 0 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The raw commit object contains that trailer once and no other trailer.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. `git -c gpg.program=/usr/local/bin/gpg verify-commit HEAD` exit 0. GnuPG also prints unknown ownertrust; that is not a bad signature. Stored `gpg.program` remains unset. The commit invocation used the same one-shot `-c gpg.program=/usr/local/bin/gpg` override and did not write git config.
- Exactly one commit after the required parent. `git rev-list --parents -n 1 HEAD` is `789fced820ed494d9651c598fb8f75c646d727a7 0856a5c56e5d09b81c669f59b613efef79133e19`. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{upstream}` exit 128). No fetch or push was attempted.
- The source commit excludes this manifest, this receipt, the precommit inventories, and all other evidence. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `5cb5eed809e86eed79bb80a98805ba288330d3183c7eca234fee56c36d2180be`, 6135 bytes. This receipt does not claim its own raw digest. `preservation-compare.json` raw SHA-256: `8a43f9ec79b8650c8baeed5ac7133498150e75d92c0304c63245f102d8cbf687`, 2043 bytes. That compare file does not claim its own digest inside itself; the hash here is of the file as written before this receipt.
- Raw commit object: 1207 bytes, SHA-256 `6ecdf3c0e26a92d950e27b08430ef9ed99fcced205dbaa0b85f16291a9d06217`.

## Source provenance

Accepted paths and hashes come from `phase27-data-candidates-commit-source.json` and the independently accepted verifier report, not from a directory listing. The verifier report was rehashed before staging: 25267 bytes, SHA-256 `75f5b24fb6f84e873ea348eb9a774ed9006e3f4aa84f835354f73f67a61dfaa5`. That matches the accepted report binding and `verification-r2/seal.json`.

Current, staged, and committed bytes match the accepted SHA-256 and length for all ten paths. Git mode is `100644` for every committed path. Filesystem `lstat` mode captured before staging is 33188 / `0o644` for every accepted path. Parent blobs are `9202bed8ea7d8ade48c95f38a81b07ea46daffe7` for the runbook and `28784724aa049e128b70f693081f04418d18af9c` for `cli.ts`. The eight additions have no parent blob.

Tested `verification-r2/source-manifest.json` and `implementation-r2/source-manifest.json` record bytes and SHA-256 only. They omit filesystem modes, Git modes, and permission bits. This delivery does not invent historical tested mode evidence. The modes above are current filesystem and Git observations. Predicted Git mode from the non-executable filesystem bit matched the staged and committed `100644` mode.

All 62 tested source/runbook identities were rehashed after the commit and before this receipt. Zero mismatches. Fifty-two of those identities are not in this commit. The full tracked diff against the parent, inspected before staging, is 89 insertions and 0 deletions in the runbook and `cli.ts`. The eight new bodies were read in full. They implement offline binding authentication, weighted and earlier-CP observations, inventory links, historical proofs, reconciliation, the non-issuable candidate document, and boundary tests. No evidence or candidate JSON is in the commit.

`core.autocrlf` is unset (`git config --get` exit 1). `git check-attr -a` on the ten paths produced empty output. No newline conversion was observed.

Before the commit, after staging only those ten paths, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check 0856a5c56e5d09b81c669f59b613efef79133e19
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
```

After the commit, `git diff --ignore-submodules=all --check 0856a5c56e5d09b81c669f59b613efef79133e19 HEAD` and `git show --check --format=` exited 0 with empty output. No source byte was edited to satisfy whitespace. The index tree equals the commit tree. Staged and unstaged tracked diffs are empty.

## Verification performed here

- Read the commit brief, accepted source bindings, original phase27 brief, r2 workflow, original blocked implementation and verification reports, recovery.json, validation.json, and the complete implementation-r2 and verification-r2 reports, seals, cleanup, and source manifests. No types, tests, derivation, oracle, build, or Forge command was rerun.
- Seal member hashes were recomputed before staging. verification-r2, implementation-r2, original verification, and original implementation seal members matched. Zero mismatches.
- Staged blob bytes and mode matched the worktree and the accepted SHA-256 before the commit. After the commit, sole parent, subject, exactly one coauthor trailer, `diff-tree` path set, and committed/current/accepted SHA-256 all match.
- The existing LFS post-commit hook ran as part of `git commit`. It did not dirty tracked source. No held09 worktree path was opened. The phase09 foreign index, when present, was hashed only as raw bytes under `.git/worktrees`.
- An initial capture launch mistakenly used the OmO binary and was killed (exit 137) before writing inventories. The retained inventories come from the later `/opt/homebrew/bin/bun` run, which printed `CAPTURE_COMPLETE` and exit 0. That failed launch is not a source change and is not a second baseline.

## Qualifications that remain explicit

This is a local delivery of the tested offline candidate pipeline, not operational approval, historical eligibility, an approved loader dataset, full Task 9, or Migration completion. Candidate status remains `NON-ISSUABLE-REVIEW-CANDIDATES`. Existing prepare, validate, and execution intake reject that document. Those loader rejections were not rerun here; they remain the sealed verification-r2 results.

The accepted independent gate, not rerun here, is strict types exit 0 and one complete operator-test invocation: **128 pass, 0 fail, 13 files**. Repeated, different-CWD, and relocated canonical candidates are each 16570240 bytes, SHA-256 `76f56c067084e04931a335ceef45ee5725153db9a39fb1619c9eab78f46ed278`. Those candidate files are evidence and are not in this commit. Independent reconciliation of 18044 records, 39507 quantity fields, and 1240 unresolved records remains the sealed verification result, not a new run.

The optional producer AST audit exited 2. Its retained stderr says `cannot resolve "typescript" from the caller project`. A deeper cause is not established. This delivery does not call that audit clean. Biome and basedpyright were unavailable in the verifier environment and are not relabeled clean.

Original `implementation/` and `verification/` remain the blocked binding-failure histories. The annotated primary tree still fails its declared Markdown bindings. Two November 10 annotations were reversed only in isolated copies. Those recovered bodies are hash-authenticated historical bodies, not located original captures, not P1 recovery, and not current policy. Current plan/PRD govern. ETH/WETH remain contribution/recovery provenance, not invented standalone compensated surrender requirements.

E-S, broader eligible T claim conservation, disabled downstream conversion, reviewed operational originals, selected real composition, and target deployment gas remain open. The retained registration measurement is **45116678 > 32000000**. P1 remains two missing historical raw artifact versions:

| Historical artifact | Bytes | Required SHA-256 |
| --- | ---: | --- |
| `out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json` | 466441 | `e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf` |
| `out/MigrationNativeHandler.sol/MigrationNativeHandler.json` | 266621 | `3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013` |

This commit does not reconstruct or erase those versions. Exact universal historic build pedigree is not claimed. Used deployed identity, routing, and units remain required and unresolved by this delivery.

## Preservation

Precommit inventories were captured before any `commit/` file existed and before staging. They are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`. Aggregates below are SHA-256 of the inventory bytes and are not substitutes for the rows. Symlink targets were not opened. `cache/` does not exist; Foundry `cache_path` is `cache_forge`. That absence is recorded in `cache-absent.json`, not filled with an invented tree.

A complete rehash before any `commit/` file existed compared **14293** content rows and **26682** permission rows with **0** mismatches. That result is `commit/precommit/preservation-compare-before-support.json`. A second rehash after the inventories and source manifest were copied, and before this receipt existed, found the same content rows unchanged. One permission row changed, and only in directory size:

| Path | Kind | Mode | Before size | After size |
| --- | --- | --- | ---: | ---: |
| `docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates` | dir | 16877 / `0o755` | 192 | 224 |

That directory gained the additive `commit/` child. Its kind, permission, and `st_mode` did not change. Directory SHA-256 remains null. No file, symlink, `out/` row, `cache_forge/` row, original input row, or recovered input row changed.

- All **348** `docs/incidents` content rows match. Content inventory `c53b6a14a58564f8254508490a35ff5d2300ba12cb8deecfbf9da1fa60d02a2d`, 101196 bytes. Permission inventory `eb2e996d05c5ab9433cc30039f61c2babe7b62220c3f75111f28b729d8ef21a9`, 101235 bytes. The one directory-size exception above is the only permission difference, and it is additive growth, not a content change.
- All **7376** `out/` content rows and **13856** permission rows match. Content inventory `6673598e3a68c4b3dd7d747ffea0027f9c55f566c259faff4453b299a9db1771`, 1960530 bytes. Permission inventory `6c69936bfe945823dca2d1b60a81897870c422a976d4b8a9d638e4c2c9dfb72a`, 2721030 bytes. No build, deletion, restoration, or relocation was performed.
- All **6502** `cache_forge/` content rows and **12368** permission rows match. Content inventory `167a70ddc88be51f57510a8ed99510b778850e635a26f64009b0c64c73750744`, 2297269 bytes. Permission inventory `ad05142c9779921a1abba60f51f25985a4caf985568a18a64702422e24237e4c`, 3518453 bytes.
- All **25** original recovery content rows and **27** permission rows match. Content inventory `a29c461c60b788748e935c485444eec646d677becabf9f967752f8bceada12de`, 5668 bytes.
- All **12** original pre-exploit content rows and **13** permission rows match. Content inventory `236335672b9491a04f5eef60bf3542e49bef7cbf145a1aea918d36aea36acf3f`, 2692 bytes.
- All **30** recovered-input content rows and **35** permission rows match, including `recovery.json`, `validation.json`, and the recovered historical bodies. Content inventory `a28a29eb85372bf3c41c3f4d461475b7b0aaba7d9bfbdb8ead12b2f222c44800`, 7898 bytes.
- All **28** foreign Git indexes are unchanged. This worktree index changed from `3f65220769feadf707b9ddfa503bb70d78d9520666fe414f7220e51c47814937`, 2076635 bytes, to `6a2e636d68083c83d543b6518661ad323f07faa728dcdcb9f58f9717302d543b`, 2077579 bytes, mode still 33188. The index matches the commit: staged diff empty and `git write-tree` equals `cbdb3081d1264ba05c3b9f1345aaff3c66cacf2e`. The baseline records 29 indexes: 28 foreign and 1 own.
- All **54** ref rows remain except `.git/refs/heads/work/dtf-migration-phase-27-data-candidates`, which moved from the parent line to `789fced820ed494d9651c598fb8f75c646d727a7`, both 41 bytes, mode 33188. `show-ref` changed only that one line. Both `show-ref` captures are 6482 bytes. Reflogs were not in the preservation set.
- Both host dependency symlinks are unchanged: `lib/crane` target `/Users/cyotee/Projects/indexedex/lib/crane`, mode 41453, inode 20382958; `node_modules` target `/Users/cyotee/Projects/indexedex/node_modules`, mode 41453, inode 20382959. Targets were not opened. The `lib/crane` gitlink remains `160000 fc0618bf5c34d0564f4367130feff443bd4efc89`. `node_modules` remains ignored.
- Four named authority files match their precommit hashes and modes. They are regular files, not symlink targets.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the ten accepted paths. No merge, cherry-pick, rebase, or index lock is present.
- Additive growth after the baseline is the new `commit/` directory, plus the one parent-directory size change above. This receipt is the last file written in that directory. It is not a baseline row.

**No pending operation.**
