# Verified bounded stateful-invariant local source delivery

Date: 2026-11-12. Status: **complete for this bounded local source delivery only**.

## Exact local commit

- Commit: `8db3f5ee6310e8a700dad2d6a33e21d0955e63ca`
- Subject: `Add verified bounded Migration stateful invariant tests`
- Parent: `15fd629375edeb361f6a39262795bdc66723ca3a`
- Tree: `464742d40290a5a11686afe75f5ee061f56a4677`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-12T11:35:13-08:00`
- Committer: `Cyotee Doge <not_cyotee@proton.me>`
- Committer date: `2026-11-12T11:35:13-08:00`
- Branch: `work/dtf-migration-phase-24-stateful-invariants`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-24-stateful-invariants`
- Exactly **14 new test, handler, and infrastructure paths**, all additions, 2496 insertions and 0 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once and no other trailer.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. `git -c gpg.program=/usr/local/bin/gpg verify-commit` exit 0. GnuPG also prints unknown ownertrust; that is not a bad signature. Stored `gpg.program` remains unset. PATH `gpg` is `/opt/homebrew/bin/gpg` and was not the signer. The commit invocation used the same one-shot `-c gpg.program=/usr/local/bin/gpg` override and did not write git config.
- Exactly one commit after the required parent. `git rev-list --parents -n 1 HEAD` is `8db3f5ee6310e8a700dad2d6a33e21d0955e63ca 15fd629375edeb361f6a39262795bdc66723ca3a`. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{upstream}` exit 128). No fetch or push was attempted.
- The source commit excludes this manifest, this receipt, the precommit inventories, and all other evidence. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `c353db56d49b22dbde4cb7f71e3791d82d23dcb018624336a1f7b05ee2190807`, 15607 bytes. This receipt does not claim its own raw digest. `preservation-compare.json` raw SHA-256: `c7fbb23a66363772973e8e4bdbc08ec1d1398c1f81a2db84a6d2cab803fbc81d`, 1598 bytes. That compare file also does not claim its own digest inside itself; the hash here is of the file as written before this receipt.

## Source provenance

The accepted set was derived from `verification-r2/source-locators.json` `candidate`, which has 14 paths, and cross-checked to `implementation-r2/candidate-r2-01.json` `files`, also 14 paths. It was not taken from a directory listing. All 14 current bytes match the verifier accepted SHA-256 and the producer candidate SHA-256. All 14 parent blobs are absent. All 14 were staged as `100644` and the staged blob SHA-256 matched the worktree bytes before the commit. After the commit, `git diff-tree` names exactly those 14 paths, each as an addition, and each committed blob SHA-256 still matches.

Eight producer entries have a first-pass `previousSha256`. Six have `previousSha256` null. `MigrationStatefulBindings.sol` is one of the eight and its previous SHA-256 equals its current SHA-256. The other seven evolved files differ from their first-pass hashes. All fourteen are still additions relative to the required parent. No production contract, existing non-owned test, operator, configuration, dependency, or held09 candidate path is in the commit.

`source-manifest.json` binds every candidate path, mode, accepted SHA-256, producer SHA-256, current SHA-256, committed SHA-256, Git blob, and absent parent blob. Producer mode 33188 is `0o100644`. Permission `0o644` is `st_mode & 0o777`. Committed mode is `100644`. `core.autocrlf` is unset (exit 1). No newline conversion was observed.

No clean/smudge filter is set on the 14 paths (`git check-attr filter` is unspecified). Historical compiler-log spaces were not part of the source-whitespace gate and were not normalized.

Before the commit, after staging only the 14 paths, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check 15fd629375edeb361f6a39262795bdc66723ca3a
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
```

After the commit, `git diff --ignore-submodules=all --check 15fd629375edeb361f6a39262795bdc66723ca3a HEAD` exited 0 with empty output. Accepted hashes were not a waiver. No source byte was edited to satisfy whitespace.

Independent acceptance is the complete `verification-r2/report.md`, raw SHA-256 `fd9aaa6531a1a3fddcd5fb7084c533a80588eddeee3ef72c269125d0f0654e60`, 30734 bytes, disposition confirmed for the complete bounded twelve-property / admitted-supported-unit stateful gate. That hash was recomputed before the commit and the file is among the unchanged docs baseline. Producer report remains `bbb1dd84921fb8bf98f7b158b0e58cb560017f84cf303203a838ea7d4f7c18d4`. Producer seal remains `4a03fe2325aed85208ce9ec418d194e1cd44fa220fb63180176cdcb5466a86e1`. Candidate manifest `candidate-r2-01.json` remains `2767c82ada1049bfaa988407146f20a57a0441bf5f740ce4c2793949ed58862d`. Verifier seal remains `c830c13d4585bcf99e838fb04da35f4d208b5f7638ebf7e1b42b77e778eebad7`.

## Verification performed here

- Read the complete commit brief, closure brief, original phase24 brief, property-acceptance rows, original implementation report, original verification report, complete r2 producer report, and complete independent r2 report. Verified the r2 report hash, branch, sole required parent `15fd629375edeb361f6a39262795bdc66723ca3a`, empty incoming staged set, and recent subject-only commit convention.
- Inspected all 14 complete new Solidity bodies. They stay inside the three permitted invariant directories. They do not subclass, etch, or storage-inject the production parent. Ordinary-SY callback coverage is not claimed-origin direct-EOA proof. ER `vm.load` in `MigrationSourceUnitsLedger.sol` is a read-only diagnostic of the admitted internal-share layout.
- `MigrationSourceUnitsRecoveryHandler.recover` selects indices `0`, `2`, `4`, and `5` only. Those are weighted liquid, weighted receipt, claim vault, and DTF-custody SE. Index `1` is earlier DETF and is not selected. `sellEarlier` may add earlier-DETF rewards to that row's inventory and may book separate external earlier-receipt shares. ED remains held. The E-L table phrase about admitted recovery is not an ED conversion.
- Staged blob hashes and modes matched worktree bytes and the accepted SHA-256 set before the commit. After the commit, sole parent, subject, exactly one coauthor trailer, `diff-tree` path set, and each committed mode/blob plus committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the new commit tree `464742d40290a5a11686afe75f5ee061f56a4677`.
- Prior independent runtime evidence was corroborated from the sealed r2 report, not rerun: 171 specifications, 147 pinned forks, and 58 focused ordinary regressions, with 0 failed and 0 skipped. Four invariants each ran 32 runs at depth 16 with 512 selected calls, 2048 selected calls total, fail-on-unexpected-revert. Seeds are `0x24d1`, `0x24d2`, and `0x24d3`. Selected calls are not aggregate positive-operation counts. No unchanged suite was replayed.

## Qualifications that remain explicit

This is a bounded local delivery of the stopped test candidate, not full-plan acceptance, target-gas acceptance, operational allocation approval, portability or archive equivalence, full-repository hermetic closure, or a public operation. Unsupported, partial, prior-delivered, native, and WETH categories remain open. E-S, raw TokenStaking approved pull, and disabled conversions are not admitted by this commit.

The first-pass increment remains a separate bounded result: 169 specifications, 144 forks, 58 ordinary regressions, and two 16-run/depth-8 machines. It did not close the twelve-property supported-unit gate. Its zero-action discovery failure and donation-model correction remain in the unchanged `implementation/failed-attempts.md`. Spendable protocol residual stays distinct from the protected 1 DTF donation recorded by the legacy handler. This commit does not relabel those failures as passes.

The original verifier's Git-index digest was made over a decoded string, not raw index bytes. That qualification stays. The fresh r2 raw index/HEAD/ref baseline was byte-correct before this commit. This commit then moved only this worktree index and this branch ref. That movement is not a retrospective raw-byte proof of the first decoded-string digest.

Current artifact proof remains the sealed r2 binding: 189 artifacts, 979 compiler-source units, 13 subject records, 1127 emitted runtime records, 66 distinct address/code pairs, and 4 submitted native package tuples. This lane reconfirmed that the 179 original artifact carriers and the 189 stopped-candidate carriers still decode to their declared SHA-256, length, and mode. Exactly 6 current `out/` files differ from the stopped-candidate carriers, and those 6 paths are the paths recorded in `verification-r2/preservation-final.json`. The other 183 current artifacts match those carriers. `changed-artifact-bytes.json` remains `0e7b97324e449efb09aeed18eacfec2c14c8efada53562f6d3928a99d0ba8f9f`, 2847097 bytes, mode 33188. The sealed record says creation object, runtime object, and compiler metadata stayed equal for those 6 files while compiler graph, source, or reference identifiers changed. This lane did not recompute those object equalities and did not restore or relocate any artifact. The binding is in-process Foundry deployment proof, not a signed mined constructor receipt.

Actual registration gas **45116678** exceeds **32000000**. Neither figure was rerun or relabeled as target-gas acceptance. No held09 candidate file was opened. The phase09 foreign index was hashed only as raw git index bytes and was unchanged.

Foundry warnings remain in the retained logs. JSON Biome remains unavailable. Those tooling gaps are not claimed as passes. No dependency was installed or cleaned. No operator, CLI, or resume was replayed.

## Preservation

Precommit inventories were captured before any `commit/` file existed and before staging. They are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`. The git-mode serialization is UTF-8 JSON Lines, one object per line. That git-mode field collapses non-executable regular files to `100644` and is not a read-only-mode proof. The permission inventory records `perm` as `oct(st_mode & 0o777)`. Index identity is the SHA-256 of the raw index file, not `git ls-files` and not a decoded string. No absolute host path was opened under the phase09 worktree.

- All **138 pre-commit `docs/incidents` git-mode entries** retain identical path/kind/mode/size/SHA-256/target inventories. Inventory hash `153beb0e0d596529504170a3a2aa9fb30c5d9c3299472b485427c5474c9d8951`, 34216 bytes. Post-commit rewalk, before this receipt, `source-manifest.json`, and `preservation-compare.json`: 0 missing, 0 changed, 13 new paths, all under `commit/precommit/`.
- All **147 pre-commit permission entries** retain identical path/kind/perm/size/SHA-256 except the directory-size change caused by creating `commit/`: `docs/incidents/2026-09-16-dtf-recovery/migration/stateful-invariants` 192 to 224, permission still `0o755`. Inventory hash `77eedebd746123f66121d96fefd6517d3ec820a72fdeb63634fd3d94ab7796ef`, 33274 bytes. Post-commit rewalk: 0 missing, 0 file changes, 15 new paths. Those new paths are the `commit` directory, `commit/precommit`, and the 13 precommit files. This receipt, `source-manifest.json`, and `preservation-compare.json` were written after that rewalk and are also excluded.
- All **7369 `out/` entries** retain inventory hash `9b38e534f50f9ad6b61beeb0b70265e85760ea9c78872ce567be8088e293e152`, 1708376 bytes. Post-commit rewalk: 0 missing, 0 changed, 0 new. No build, deletion, restoration, or relocation was performed.
- All **550 `cache_forge/` entries** retain inventory hash `d38e68c20fc40f6790a322b0b3405babd8442dd4aa417eb9b27cbd0661f4423d`, 149958 bytes. Post-commit rewalk: 0 missing, 0 changed, 0 new.
- All **148 sealed preservation rows** were re-read. **146** still match raw SHA-256, length, and mode. The only mismatches are the two rows this commit must move: the own index and `refs/heads/work/dtf-migration-phase-24-stateful-invariants`. The own HEAD file still matches the sealed raw baseline. No authority, evidence, carrier, source, or host-input row in that set changed.
- All **64 `show-ref` lines** remain except the one branch movement from `15fd629375edeb361f6a39262795bdc66723ca3a` to `8db3f5ee6310e8a700dad2d6a33e21d0955e63ca`. Baseline `show-ref` SHA-256 `f88527425af7df7cedcc0404e581fa1f360e9b33dfb5f124a1c58f7a3f7c6aba`, 6194 bytes. No other loose ref file changed. No held phase09 candidate was read, imported, tested, or committed.
- All **25 foreign worktree indexes** are unchanged. This worktree index changed from `0aac78e6504612422343709283b720e3628f7e43a04df63575f91130d58000b0`, 2073604 bytes, to `82128293dce6005c647d33617c5c14ebfecfea73588ada9f915bff82cd7166a7`, 2076067 bytes, mode still 33188. The index matches the new commit: staged diff empty and `git write-tree` equals `464742d40290a5a11686afe75f5ee061f56a4677`. The baseline records 26 indexes: 25 foreign and 1 own.
- Both dependency symlinks are unchanged: `lib/crane` target `/Users/cyotee/Projects/indexedex/lib/crane`, mode 41453, inode 19989693; `node_modules` target `/Users/cyotee/Projects/indexedex/node_modules`, mode 41453, inode 19989694.
- Original evidence membership remains 22 implementation files, 13 verification files, 72 implementation-r2 files, and 17 verification-r2 files, including both old seals and the fresh changed-artifact carrier. The post-commit docs rewalk found none of those files changed.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the 14 accepted paths. No merge, cherry-pick, rebase, or index lock is present.
- Port 18574 listener check exit 1 with empty output, both before staging and after the commit. No forge, solar, or anvil process was present in the pre-commit process check. Commit and inspection processes completed. **No pending operation.**
