# Verified portable operator bundle relocation

Date: 2026-11-12. Status: **complete for this local source delivery only**.

## Exact local commit

- Commit: `0856a5c56e5d09b81c669f59b613efef79133e19`
- Subject: `Add verified bounded portable operator bundle relocation`
- Parent: `137fa0c8749165087c7d1d0156788f58a1dbf1b8`
- Tree: `128c9c1fc2248574d30e23b760179fcba1b6a355`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-12T17:27:42-08:00`
- Committer: `Cyotee Doge <not_cyotee@proton.me>`
- Committer date: `2026-11-12T17:27:42-08:00`
- Branch: `work/dtf-migration-phase-26-portable-operator`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-26-portable-operator`
- Exactly **24 paths**: 19 modifications and 5 additions, 817 insertions and 93 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once and no other trailer.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. `git -c gpg.program=/usr/local/bin/gpg verify-commit` exit 0. `%G?` is `U` because ownertrust is unknown; that is not a bad signature. Stored `gpg.program` remains unset. The commit invocation used the same one-shot `-c gpg.program=/usr/local/bin/gpg` override and did not write git config.
- Exactly one commit after the required parent. `git rev-list --parents -n 1 HEAD` is `0856a5c56e5d09b81c669f59b613efef79133e19 137fa0c8749165087c7d1d0156788f58a1dbf1b8`. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{{upstream}}` exit 128). No fetch or push was attempted.
- The source commit excludes this manifest, this receipt, the precommit inventories, and all other evidence. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `0b6c15079a43b31db33fdee413cf8666660b2d1be6df4c8433c1d942459b512c`, 30351 bytes. This receipt does not claim its own raw digest. `preservation-compare.json` raw SHA-256: `020e32b8d50333450e8aac0262a0f638262d51e76f5c575984be420a8aeb2137`, 7397 bytes. That compare file also does not claim its own digest inside itself; the hash here is of the file as written before this receipt.
- Raw commit content from `git cat-file commit`: 1204 bytes, SHA-256 `f6e79169250c625e90317d240b20f1d6ac7d7248e5d9f2ae9d8fbeccde56d067`. The loose object is 905 compressed bytes and is not that identity.

## Source provenance

The 24 accepted paths and hashes come from `phase26-portable-operator-commit-source.json`, not from a directory listing. Current, staged, and committed bytes match those tested hashes. Every path is full mode 33188 / permission `0o644` / decimal permissionMode 420 / Git mode `100644`. PermissionMode 420 is `st_mode & 0o777`. It is not full lstat mode 33188. Those encodings agree.

Producer `implementation/source-manifest-stopped.json` is 24917 bytes, SHA-256 `6e481524649151fb16b21c5a933494ffdb757da9679f282d7b176d3a7e9a0b6d`. It binds 60 frozen operator, stage-helper, and runbook files, each recorded with mode 420. All 24 committed paths match that frozen SHA-256 and byte length. The other 36 remain frozen and were not staged. Their paths are in `source-manifest.json` under `unchangedFrozenNotCommitted`.

The tracked diff of the 19 modifications is 60829 bytes, SHA-256 `193352dc21b6dec54a33d578e75cedc1ab8a9366a2131d7f7c3e65c76e795c40`, byte-identical to the verification-r2 candidate diff. The five new bodies were read in full: `bundle-files.ts`, `bundle.ts`, `bundle-materialize.ts`, `bundle.test.ts`, and `rehearsal-portable.ts`.

`core.autocrlf` is unset (exit 1). `git check-attr filter` is unspecified for all 24 paths. No newline conversion was observed. No source byte was edited.

Before the commit, after staging only those 24 paths, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check 137fa0c8749165087c7d1d0156788f58a1dbf1b8
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
```

After the commit, `git diff --ignore-submodules=all --check 137fa0c8749165087c7d1d0156788f58a1dbf1b8 HEAD` and `git show --check --format=` exited 0 with empty output.

## Verification performed here

- Read the commit brief, source JSON, phase26 brief, implementation report and seal, the original failed `verification/` report, proof, and seal, and `verification-r2` report, proof, seal, and cleanup. No runtime, test, or build was replayed.
- Independent `verification-r2/report.md` raw SHA-256 is `6a412318e5c876845290eb28d8fbf21b705a789981174ca08f7ae9d2c85cd17c`, 18050 bytes, matching the commit brief. Implementation seal is 4324168 bytes, SHA-256 `4078009ee51764d30f198fd51b90a7133376f2e75365036efa304d62186de218`. The r2 report's bounded confirmation is cited, not re-executed: 109 operator tests, strict types, stage and artifact builds, the sandboxed 18575 workflow, payload/configuration/quote equality, three genuine recoveries, 14 administration cuts, canonical no-duplicate economics, and prior absolute-input/domain hash compatibility.
- The original `verification/` needs-fix intake at 2026-11-13T00:34:59.880Z remains unchanged. It is an intake failure, not a runtime verdict, and this commit does not relabel it.
- Staged blob bytes and mode matched the worktree and the tested SHA-256 before the commit. After the commit, sole parent, subject, exactly one coauthor trailer, `diff-tree` path set, and committed/current/tested SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the commit tree `128c9c1fc2248574d30e23b760179fcba1b6a355`.

## Qualifications that remain explicit

This is a local delivery of the verified portable operator increment, not operational approval, live-journal migration, cold dependency reconstruction, cross-platform proof, archive equivalence, unsupported-source or conversion success, or target-gas acceptance.

P1 remains exactly two unrecovered historical raw JSON versions: `MigrationSnapshotConsumer.json` and `MigrationNativeHandler.json`. This commit does not recover those versions and does not claim all-history preservation. Current `out/` and `cache_forge/` rows are the current baselines only.

Operational original datasets, unsupported E-S/raw/direct or partial/prior-delivered/native/WETH paths, disabled conversions, and source/archive equivalence remain open. Actual registration remains 45116678 gas, above 32000000. That figure was not rerun. No held09 candidate file was opened. The phase09 foreign index was hashed only as raw git index bytes and was unchanged.

The proof is same-host data relocation with installed source, dependencies, warm artifacts, and macOS sandbox. Changed-domain journals remain rejected. Old input slots were not removed from hashes.

## Preservation

Precommit inventories were captured before any `commit/` file existed and before staging. They are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`. Aggregates below are SHA-256 of the inventory bytes and are not substitutes for the rows. No absolute host path was opened under the phase09 worktree.

Mode distinction: Git mode `100644` covers both permission `0o644` / full mode 33188 and permission `0o600` / full mode 33152. The comparison used perm and full `st_mode`, not Git mode alone. `modeCollapsedWouldHide` is empty. The baseline contains 31313 regular files at `0o644` / 33188, 695 regular files at `0o600` / 33152 (615 under `docs/incidents`, 80 under `cache_forge`), 12617 directories at `0o755` / 16877, and 4 symlinks at `0o755` / 41453. Those four symlinks are negative-bundle fixture links inside portable-operator evidence. Their targets were recorded and not opened.

- All **18134 `docs/incidents` content rows** retain identical path, kind, gitMode, perm, st_mode, size, SHA-256, and symlink target. Inventory `8e5cb757310062d9318f7d752b324f12992f2087359ffa542f3d6d47e0741b0b`, 6157123 bytes. Post-commit rehash, before any `commit/` file existed: 0 missing, 0 changed.
- All **18405 docs permission rows** and **271 directory bookkeeping rows** matched, including kind, perm, st_mode, size, nlink, childCount, and childrenSha256. Permission inventory `49a29b8c40182327f1a14c5dc0cf5ba94ff4c6b6fd7ce80ba5cd0ae8e3156e72`, 5875795 bytes. Directory inventory `1f923f3e8c14aec62f54d41ac373f08389f7691bca6df53bcf253e63776e41b6`, 85443 bytes.
- All **7376 `out/` content rows** retain inventory `6673598e3a68c4b3dd7d747ffea0027f9c55f566c259faff4453b299a9db1771`, 1960530 bytes. Post-commit rehash: 0 missing, 0 changed. No build, deletion, restoration, or relocation was performed.
- All **13856 `out/` permission rows** and **6480 directory rows** matched. Permission inventory `6c69936bfe945823dca2d1b60a81897870c422a976d4b8a9d638e4c2c9dfb72a`, 2721030 bytes. Directory inventory `6d3cb6c807e097df44c60d87327a2c24d2dcda0544f89c64b54111f2ef5b6e9a`, 1425573 bytes.
- All **6502 `cache_forge/` content rows** retain inventory `167a70ddc88be51f57510a8ed99510b778850e635a26f64009b0c64c73750744`, 2297269 bytes. Post-commit rehash: 0 missing, 0 changed.
- All **12368 `cache_forge/` permission rows** and **5866 directory rows** matched. Permission inventory `ad05142c9779921a1abba60f51f25985a4caf985568a18a64702422e24237e4c`, 3518453 bytes. Directory inventory `446bc614ef6c7e6007e7ecbcc99ba3dbc94ffb9c2a9f429347cfa0da974b0a21`, 1819894 bytes.
- All **27 foreign Git indexes** are unchanged. This worktree index changed from `ec3e978204abc33ed9bf0d127c15567447d174ec901eb3d1efc836c31872fadc`, 2076067 bytes, to `14fdc2ddcb7521f5a10f4789fc8d7caca905ea9a78ecbbd5655938b46d076053`, 2076635 bytes, mode still 33188 / `0o644`. The index matches the commit: staged diff empty and `git write-tree` equals `128c9c1fc2248574d30e23b760179fcba1b6a355`. The baseline records 28 indexes: 27 foreign and 1 own.
- All **52 ref rows** remain except `.git/refs/heads/work/dtf-migration-phase-26-portable-operator`, which moved from `9f631241fe1d82ef6d8e279442be85e640fd477ee94da3690c0ef01ba31e76c4` to `6074490d00a3f530e8e310d74b23232e632f0f4d581b5191e3ec790b661fc401`, both 41 bytes, mode 33188. `show-ref` changed only that one line, from the parent to this commit. Baseline `show-ref` SHA-256 `b2f616e678112a9d184dacc323f9422e4b2e6d0ca596ba89613b9e5c502e8a5a`, 6386 bytes, 66 lines. After the commit it is `fa6329f8f5ce4060bcaf865788a547632997599008574c4e2e5004b7e0093331`, also 6386 bytes and 66 lines. Reflogs were not in the preservation set.
- Both host dependency symlinks are unchanged: `lib/crane` target `/Users/cyotee/Projects/indexedex/lib/crane`, mode 41453; `node_modules` target `/Users/cyotee/Projects/indexedex/node_modules`, mode 41453. Targets were not opened. The `lib/crane` gitlink remains `160000 fc0618bf5c34d0564f4367130feff443bd4efc89`. `node_modules` remains ignored by `.gitignore:3`.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the 24 accepted paths. No merge, cherry-pick, rebase, or index lock is present.

## Additive evidence-directory growth

The full rehash above was taken before `portable-operator/commit/` existed. At that point every original content, permission, and directory row matched, and additive counts were 0. The support files were written after that proof. They are excluded evidence, not a preservation failure of an original row.

After the inventories, recipe, capture script, compare script, and manifest were written, and before `preservation-compare.json` and this receipt, the directory rewalk found 26 additive `docs/incidents` paths: the new `commit` directory, `commit/precommit/`, its inventory files, and `source-manifest.json`. The `commit` directory is that additive root, not an unexpected path. Unexpected additive paths: none. `out/` additive 0. `cache_forge/` additive 0. `preservation-compare.json` and this receipt are two later additive files and are not in those 26.

Original directory rows whose bookkeeping changed because of that added child: 1.
- `docs/incidents/2026-09-16-dtf-recovery/migration/portable-operator` fields size, nlink, childCount, childrenSha256. Size 160 to 192, nlink 5 to 6, childCount 3 to 4, childrenSha256 `c6d953efa82909fc8c1f85763ab42362fb5810d3d1484806c6893c28b5c905a0` to `2d7b720f4d081179a4e9f5176aa8de88a417d7b93bacc2c4644339ac2e5bc6e0`. Permission and full mode did not change.

`out/` and `cache_forge/` original directory rows did not change in that post-support rewalk. `preservation-compare.json` and this receipt are the two later additive files under the same `commit/` directory. Neither is a member of the 26-path additive list.

Port 18575 listener check exit 1 with empty output before the commit. The owned checkpoint was absent. No forge, anvil, or solar process was started. Commit and inspection processes completed. **No pending operation.**

