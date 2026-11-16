# Verified full-hermetic metadata correction local source delivery

Date: 2026-11-12. Status: **complete for this one-file local source delivery only**.

## Exact local commit

- Commit: `137fa0c8749165087c7d1d0156788f58a1dbf1b8`
- Subject: `Fix frozen quote interface metadata expectations`
- Parent: `8db3f5ee6310e8a700dad2d6a33e21d0955e63ca`
- Tree: `aa68a333c11d70e4c1952b5c095f046ad26cbf34`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-12T15:01:42-08:00`
- Committer: `Cyotee Doge <not_cyotee@proton.me>`
- Committer date: `2026-11-12T15:01:42-08:00`
- Branch: `work/dtf-migration-phase-25-full-hermetic`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic`
- Exactly **one modified test path**, 3 insertions and 1 deletion.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once and no other trailer.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. `git -c gpg.program=/usr/local/bin/gpg verify-commit` exit 0. GnuPG also prints unknown ownertrust; that is not a bad signature. Stored `gpg.program` remains unset. The commit invocation used the same one-shot `-c gpg.program=/usr/local/bin/gpg` override and did not write git config.
- Exactly one commit after the required parent. `git rev-list --parents -n 1 HEAD` is `137fa0c8749165087c7d1d0156788f58a1dbf1b8 8db3f5ee6310e8a700dad2d6a33e21d0955e63ca`. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{upstream}` exit 128). No fetch or push was attempted.
- The source commit excludes this manifest, this receipt, the precommit inventories, and all other evidence. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `e5292ee44478fa64ce972ebbe9592709c8296a480e78e070b4bc47f1314fd9f4`, 3388 bytes. This receipt does not claim its own raw digest. `preservation-compare.json` raw SHA-256: `44c6fedc9a8fb78137efec3f1cb95f8757a1121f11de9d59681294882997663b`, 2452 bytes. That compare file also does not claim its own digest inside itself; the hash here is of the file as written before this receipt.
- Raw commit object: 1196 bytes, SHA-256 `6a9f24d68555d1384ce2bbbbdef0555d5558696a5d8888408de6eaacceb8449f`.

## Source provenance

The accepted path and hash come from `full-hermetic/seal.json` `source`, not from a directory listing. Current, staged, and committed bytes are 17776, mode 33188 / `100644`, SHA-256 `e8869bc93a199c7c35c97612b804cbb5fde94ef4df1c5661463670e0e0954fc1`. Parent blob `2a806b5a411e61dade8b08dd2183e442a2c0ac8e`. Committed blob `075c1444c757188cd187fe8d63df947422bbaf8c`.

The complete diff adds the import of `IStandardExchangeFrozenQuoteInputs`, changes the interface-count expectation from 15 to 16, and asserts `interfaces[15]` equals `type(IStandardExchangeFrozenQuoteInputs).interfaceId`. `facets.length` remains 15. No existing facet address assertion was edited, removed, or skipped. No production file is in the commit.

`core.autocrlf` is unset (exit 1). `git check-attr filter` is unspecified. No newline conversion was observed.

Before the commit, after staging only that path, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check 8db3f5ee6310e8a700dad2d6a33e21d0955e63ca
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
```

After the commit, `git diff --ignore-submodules=all --check 8db3f5ee6310e8a700dad2d6a33e21d0955e63ca HEAD` and `git show --check --format=` exited 0 with empty output. No source byte was edited to satisfy whitespace.

## Verification performed here

- Read the complete commit brief, `report.md`, `seal.json`, `RUN.md`, both runners and launch commands, the initial failure record, initial-run seal, diagnosis, pager incident, metadata history, sealed diff, and forge version log. Rehashed every seal member before staging: 21 members, 0 mismatches. Seal raw SHA-256 `30e624d82df639fc1fc55bd862c9de12365d3c98090ec57a35539a15f16c927e`, 4627 bytes.
- The sealed logs contain the forge summaries. `focused-r2.log` is 1 passed, 0 failed, 0 skipped. `tests-r2.log` is 2687 suites, 28576 passed, 0 failed, 0 skipped. `tests.log` is 28575 passed, 1 failed, 0 skipped, failure `interface count: 16 != 15`. The post-tee `HERMETIC_*_EXIT` lines are not inside those tee files. They were read from the executing session transcript: initial build/artifacts exit 0 and test exit 1; r2 build, artifacts, focused, and full test each exit 0 with capture exit 0; `FULL_HERMETIC_R2_GATE_COMPLETE`; bash_112 watcher exit 0. Those exits were not rerun.
- Staged blob bytes and mode matched the worktree and the accepted SHA-256 before the commit. After the commit, sole parent, subject, exactly one coauthor trailer, `diff-tree` path set, and committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the commit tree `aa68a333c11d70e4c1952b5c095f046ad26cbf34`.
- Prior runtime evidence was corroborated from the sealed logs and report, not rerun. No unchanged suite was replayed. No build, install, provider change, or CLI replay occurred.

## Qualifications that remain explicit

This is a local delivery of the one tested metadata correction, not operational approval, portability or cold reconstruction, archive equivalence, unsupported-source or conversion success, or target-gas acceptance. The repository CI fork exclusions in `run-gate-r2.sh` are the existing default hermetic exclusions, not new hidden tests.

The initial 28575-pass/1-fail logs, diagnosis, and pager incident remain sealed and unchanged. Evidence hashes do not turn that failure into a pass. The r2 terminal prompt remains the recorded incident: the runner blocked at Press RETURN, one Enter resumed the same bash_112 session, and no duplicate gate was started.

The base `8db3f5ee` remains qualified. Phase 24 `commit/P1-followup.md` still records two unrecovered first-pass historical raw JSON versions: `out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json` at 466441 bytes / `e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf`, and `out/MigrationNativeHandler.sol/MigrationNativeHandler.json` at 266621 bytes / `3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013`. This commit does not recover those versions and does not claim all-history preservation. Current `out/` and `cache_forge/` rows are the current baselines only.

Operational original datasets, unsupported E-S/raw/direct or partial/prior-delivered/native/WETH paths, disabled conversions, and source/archive equivalence remain open. Default-profile `foundry.toml` `gas_limit` is 30000000000. That is not the target 32000000 cap. Retained registration gas 45116678 still exceeds it. Neither figure was rerun. No held09 candidate file was opened. The phase09 foreign index was hashed only as raw git index bytes and was unchanged.

Foundry warnings remain in the retained logs. They were not suppressed. No dependency was installed or cleaned.

## Preservation

Precommit inventories were captured before any `commit/` file existed and before staging. They are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`. Aggregates below are SHA-256 of the inventory bytes and are not substitutes for the rows. No absolute host path was opened under the phase09 worktree.

- All **36 pre-commit `docs/incidents` content rows** retain identical path, kind, gitMode, perm, st_mode, size, and SHA-256. Inventory `49eedd39a62f21abfa54692df130bbfccb6aa2426d82dda3e161208e7c24a50f`, 9062 bytes. Post-commit rehash, before this receipt and the support files: 0 missing, 0 changed.
- All **41 pre-commit docs permission rows** retain kind, perm, st_mode, and size. The 5 directory rows matched directly. The 36 file rows matched through the content rehash. Inventory `6f39b68c246bcc52a8c830746e8f38274dbb23ccc9cb6408e4171b641cafa6d6`, 9055 bytes.
- All **7376 `out/` content rows** retain inventory `6c47c43084026944ce83b3e3833aa46c66e1a14c23688c3946cade49efb1416e`, 1960532 bytes. Post-commit rehash: 0 missing, 0 changed. No build, deletion, restoration, or relocation was performed.
- All **13856 `out/` permission rows** retain kind, perm, st_mode, and size. File bytes are the content-row proof. Inventory `82548427c9c8bd9c48a4ee74add3824e4ab8f7cbd7ea3dff6202c8d2f1c80aaf`, 2721032 bytes.
- All **6498 `cache_forge/` content rows** retain inventory `6216f75223e10225e58061fce95581cda3c072a57237e397bb5d6accb78429b2`, 2296222 bytes. Post-commit rehash: 0 missing, 0 changed.
- All **12364 `cache_forge/` permission rows** retain kind, perm, st_mode, and size. Inventory `d7801b1c4ad0c9a73f764fe51f8b660226dabb09bfe88cabed2de5a507a27199`, 3517482 bytes.
- All **26 foreign Git indexes** are unchanged. This worktree index changed from `d43d7e1a878ed266e0805f2502061ba52b0511f1704db2eddab86b70aa14d6ad`, 2076067 bytes, to `71bf551379036296f359bc66b9eaadfee6ded0c7574612847ddfeb107b75e771`, 2076067 bytes, mode still 33188. The index matches the commit: staged diff empty and `git write-tree` equals `aa68a333c11d70e4c1952b5c095f046ad26cbf34`. The baseline records 27 indexes: 26 foreign and 1 own.
- All **52 ref rows** remain except `.git/refs/heads/work/dtf-migration-phase-25-full-hermetic`, which moved from `bbad16e5c6ca428ad8c6deeb8792560a9e2bf7c70aeb20c9b87b35f6fa3fb30c` to `9f631241fe1d82ef6d8e279442be85e640fd477ee94da3690c0ef01ba31e76c4`, both 41 bytes, mode 33188. `show-ref` changed only that one line, from the parent to this commit. Baseline `show-ref` SHA-256 `cfdc34bd4eb32ef2698809eb3d8a92eca7ddf6600ff612f20e837786ed65bb2a`, 6288 bytes, 65 lines. Reflogs were not in the preservation set.
- Both host dependency symlinks are unchanged: `lib/crane` target `/Users/cyotee/Projects/indexedex/lib/crane`, mode 41453, inode 20147219; `node_modules` target `/Users/cyotee/Projects/indexedex/node_modules`, mode 41453, inode 20147220. Targets were not opened. The `lib/crane` gitlink remains `160000 fc0618bf5c34d0564f4367130feff443bd4efc89`. `node_modules` remains ignored by `.gitignore:3`.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the accepted path. No merge, cherry-pick, rebase, or index lock is present.
- Port 18574 listener check exit 1 with empty output after the commit. No forge, anvil, or solar process was present. Commit and inspection processes completed. **No pending operation.**
