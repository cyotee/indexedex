# Verified conversion and recovery receipt collector local source delivery

Date of the commit: 2026-11-13 01:00:38 -0800. Status: **complete for this eight-file local source delivery only**.

## Exact local commit

- Commit: `1694e68a4bd66dd67d3b5e3f145f1da23074ff48`
- Subject: `Add verified bounded conversion and recovery receipt collection`
- Parent: `07d54b9a3d20d98aee24e75235bbf16b650a8028`
- Tree: `9bfb1e7290913fbbe75541983d895636bb79bafd`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-13T01:00:38-0800`
- Committer: `Cyotee Doge <not_cyotee@proton.me>`
- Committer date: `2026-11-13T01:00:38-0800`
- Branch: `work/dtf-migration-phase-30-recovery-receipts`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts`
- Exactly **eight modified paths**. Numstat is 206 insertions and 17 deletions. No additions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once and no other trailer.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. `git -c gpg.program=/usr/local/bin/gpg verify-commit HEAD` exit 0. `%G?` is `U` because ownertrust is unknown; that is not a bad signature. Stored `gpg.program` remains unset. The commit invocation used the same one-shot `-c gpg.program=/usr/local/bin/gpg` override and did not write git config.
- Exactly one commit after the required parent. `git rev-list --parents -n 1 HEAD` is `1694e68a4bd66dd67d3b5e3f145f1da23074ff48 07d54b9a3d20d98aee24e75235bbf16b650a8028`. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{upstream}` exit 128). No fetch or push was attempted.
- `core.hooksPath` is `.husky/_`. That directory does not exist in this worktree. The commit tool result contained only the success summary and no hook output. No hook output was observed.
- The source commit excludes this manifest, this receipt, `commit/support/`, and all evidence. Evidence remains local and uncommitted. `git ls-tree -r HEAD -- docs/incidents/2026-09-16-dtf-recovery/migration/recovery-receipts` is empty.
- `source-manifest.json` raw SHA-256: `4fae94bf90323ae2e738e0e4c8092da607594d708a31f093a76ae9250e53d28a`, 34431 bytes. This receipt does not claim its own raw digest. `support/preservation-compare.json` raw SHA-256: `bd04bc75f34af1fa3cb61463fd07686f7a09a4a4fc3571af48bf319d78e19374`, 9310 bytes. That compare file does not claim its own digest inside itself; the hash here is of the file as written before this receipt.
- Raw commit object: 1211 bytes, SHA-256 `f538afdbea0f7defc3c7eb7749c773466be2617e657414e01b10f8e588bd94ea`. The `gpgsig` header is a signature header, not a second trailer.

## Source provenance

Accepted paths and hashes come from `phase30-recovery-receipts-commit-source.json` and the independently accepted verifier report, not from a directory listing. The verifier report was rehashed before staging: 13625 bytes, SHA-256 `b6fd48a199b7a577eaa4007741264d99e7b21d700a147e979c6e3f47b6077b50`. That matches the accepted report binding and `verification/seal.json`.

Current, staged, and committed bytes match the accepted SHA-256 and length for all eight paths. `git cat-file blob HEAD:path` equals the worktree bytes for every accepted path. Git mode is `100644` for every committed path. Filesystem `lstat` mode captured before staging is 33188 / `0o644` for every accepted path. Parent and committed blob ids are in `source-manifest.json`.

Tested `implementation/source-manifest.json` and `verification/source-manifest.json` record bytes and SHA-256 only. The accepted verifier report and seal do the same. They omit filesystem modes, Git modes, and permission bits. This delivery does not invent historical tested mode evidence. The modes above are current filesystem and Git observations. Predicted Git mode from the non-executable filesystem bit matched the staged and committed `100644` mode.

All 70 tested operator/runbook identities were rehashed after the commit and before this receipt. Zero mismatches. Sixty-two of those identities are not in this commit. Their paths and hashes are `unchangedFrozenNotCommitted` in `source-manifest.json`. The full tracked diff against the parent, inspected before staging, is the eight modified paths only: 206 insertions and 17 deletions. The eight bodies were read. They add an explicit `conversions-and-recoveries` selection, keep the purchase/claim default, match native conversion and recovery outputs without inferring credits or deductions, and document that limit in the runbook. No evidence or archive JSON is in the commit.

`core.autocrlf` is unset (`git config --get` exit 1). `git check-attr -a` on the eight paths produced empty output. No newline conversion was observed. Staged blob bytes equaled worktree bytes before the commit.

Before the commit, after staging only those eight paths, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check 07d54b9a3d20d98aee24e75235bbf16b650a8028
```

After the commit, `git diff --ignore-submodules=all --check 07d54b9a3d20d98aee24e75235bbf16b650a8028 HEAD`, `git show --check --format=`, `git diff --cached --ignore-submodules=all --check`, and `git diff --ignore-submodules=all --check` exited 0 with empty output. No source byte was edited to satisfy whitespace. The index tree equals the commit tree `9bfb1e7290913fbbe75541983d895636bb79bafd`. Staged and unstaged tracked diffs are empty.

The sealed `implementation/source.diff` matches its manifest: 29288 bytes, SHA-256 `8d39259f16511b8e655c6d716a87ae948bb83e1a0f936739fbde999a661f10ac`. A fresh `git diff` is not byte-identical. Every fresh diff line is present in that sealed file. The sealed-only lines are the producer status header, including `?? out`, captured while a temporary read link existed. That link is absent now. The header is not a source hunk. It was not edited.

## Verification performed here

- Read the commit brief, accepted source bindings, the phase30 brief, and the complete implementation and verification reports, seals, cleanup records, cross-checks, and command proofs. No types, tests, collector, oracle, build, Forge, secret scan, or network command was rerun.
- Seal member hashes were recomputed before staging. All 8 implementation and 12 verification seal members matched, including both manifests, both actual archives, both HTTP manifests, and the shared reconciliation file. Zero mismatches.
- Producer command exits read from the recorded command files, not rerun: `types01` exit 0, `focused01` exit 0, deliberate `mutation01` exit 1, `types-final` exit 0, `operator-tests-final` exit 1, `operator-tests-complete` exit 0, `collect` exit 0, `support-types` exit 0, and `reconcile` exit 0. Independent command exits read the same way: `types` exit 0, initial `suite` exit 1, `collect` exit 0, initial `support-types` exit 2, initial `oracle` exit 1, and `suite-final`, `support-types-final`, and `oracle-final` exit 0.
- Staged blob bytes and mode matched the worktree and the accepted SHA-256 before the commit. After the commit, sole parent, subject, exactly one coauthor trailer, `diff-tree` path set, and committed/current/tested SHA-256 all match.
- Fresh LSP diagnostics were already recorded unavailable by both producer and verifier. Biome is not installed. Neither is called a passing check. No install or configuration change was made.

## Qualifications that remain explicit

This is a local delivery of the tested conversion/recovery receipt collector, not operational approval, compensation, source admission, current control, eligibility, full Task 9, or Migration completion. Archive status remains `NON-ISSUABLE-RECEIPT-OBSERVATIONS`. Existing prepare, prepared-envelope, and execution loaders reject that document. Those loader rejections were not rerun here; they remain the sealed verification results.

The accepted independent gate, not rerun here, is strict types exit 0 and one complete operator-test invocation: **172 pass, 0 fail, 15 files**. One producer collection and one independent collection each authenticated 319 references, 1278 requests, 2228 logs, and 319 saved Transfer locators. All 319 known transactions are covered, including 299 absent from the old 77 archive. Overlap with that archive is 20: 18 raw claims and two detf_to_sdetf conversions. The old 77 collector was not replayed.

Of 1278 corresponding raw responses, 1277 are byte-identical. Response 482, `eth_getBlockByNumber` for `0x3da6876`, differs only in JSON-RPC object property order. Producer raw SHA-256 `e598a900892bdaa06ab60cc2d685bf0323dc30f9233be37cbde61e6a13885797`. Verifier raw SHA-256 `3e05c0703fdd051d5b525bdf97883e57cddfe9762141c4c3bca17abad0f7f9c3`. Parsed envelopes are deeply equal. Both raw hashes remain. That difference changes the HTTP-manifest hash and the archive HTTP binding. It is not byte identity of all responses.

Producer `actual/archive.json` is 5917231 bytes, SHA-256 `6f3d656a88b325503f4cddd23cab96e582e171ce1f40e632eb065f4ad24fe9f2`. Verifier `actual/archive.json` is 5917231 bytes, SHA-256 `67a8cd97a26d0bfe4fc118469db605a9b0424e7b40c17fb977f6bd6990dfefc0`. `actual/reconciliation.json` is byte-identical in both archives: 841408 bytes, SHA-256 `7b900c143f64446301f8385f81eaa0daaada81a06d4dd0468de4b38dcd5d90d2`. Those files are evidence and are not in this commit.

All 250 conversion rows retain `is_external_recovery=false`. All 69 recovery rows retain `classification=detf_exchange_output`, native18 DTF, `deduct_from_R=false`, and blank `R_eth`. No credit, deduction, net contribution, current control, eligibility, or source admission was inferred. The existing input loader projects `sources.policyRevision` out of parsed archive metadata. The raw body remains hash-bound. Independent proof retains the full historical value `held-assets-no-upfront-credit-20261108` and rejects that stale field as current authority. That qualification was not rewritten.

Retained initial verifier failures, not rerun and not relabeled as passes: relative CLI runtime link, support TS2345, and raw-versus-parsed policy projection. Final checks after those owned verifier fixes passed. The producer `operator-tests-final` exit 1 remains the missing warm ABI failure, 87 pass and 85 fail, before a read link to the existing phase28 artifact. `mutation01` remains the recorded deliberate broken-guard failure. Unavailable or timed-out LSP is not success.

The recorded credential scans found 0 matches. They were not rerun for this delivery. New commit outputs contain public identities, source diffs, and hashes. They do not contain a provider credential or a wallet key.

No deployment, funding, activation, real allocation, held09, or gas work follows this commit. P1 remains the two missing historical raw artifact versions recorded by the parent delivery. This commit does not reconstruct or erase them. Worktree `out/` is absent, so those paths are absent here. Exact universal historic build pedigree is not claimed.

## Preservation

Precommit inventories were captured before any `commit/` file existed and before staging. They are retained under `commit/support/`. Recipe: `commit/support/recipe.txt`. Aggregates below are SHA-256 of the inventory bytes and are not substitutes for the rows. Symlink targets were not opened. `out/`, `cache/`, and `cache_forge/` do not exist. Foundry was not run. That absence is recorded in `support/links.json`, not filled with an invented tree. This delivery does not claim a universal `docs/incidents`, `out`, or `cache_forge` walk.

Git mode `100644` is not the permission proof. The comparison used `perm` and full `st_mode`.

A complete rehash before any `commit/` file existed compared every owned-evidence and input content, permission, and directory row with **0** mismatches. That result is `commit/support/preservation-compare-before-support.json`.

- All **5842** owned-evidence content rows match. Content inventory `69535830f7d81b086ed57d6e222df9738010f66e596941edc501eca886b7b20f`, 1710196 bytes. Permission inventory `7bc075805c7f55be5f186a1c66e81cd5eb9e95074e237032ce5fe935ee9ed1fc`, 1600457 bytes, 5849 rows. Directory inventory `b9f01ec959d98138ca979e9f900e947cb09ac162d50c4e03e15bb037ac3989db`, 2046 bytes, 7 rows. The root is `docs/incidents/2026-09-16-dtf-recovery/migration/recovery-receipts`.
- All **30** recovered-input content rows and **35** permission rows match. Content inventory `a28a29eb85372bf3c41c3f4d461475b7b0aaba7d9bfbdb8ead12b2f222c44800`, 7898 bytes. This is the collector input root `phase27-frozen-input-recovery`. The same content-inventory digest was recorded by the phase28 delivery; that is corroboration, not a substitute for these rows. Permission rows were compared to this capture, not to the older permission file.
- Two review pointer files were hashed and not used as economic authority: `receipt-review-index-20261113.json`, 112345 bytes, SHA-256 `b3f3f710dd22c6f61dcd45c9f3bf74f5541ec32a9ffe33dbfeef93376c14b3a3`; `conversion-recovery-review-20261113.json`, 341774 bytes, SHA-256 `c1f8b1a70ecfd7f739a1a9238d6dbc0970c4f6d64d93de6e9ddc3e063c7654dc`.
- The used artifact is only `phase28` `out/UniswapV4DetfMigrationFacet.sol/UniswapV4DetfMigrationFacet.json`: 394495 bytes, SHA-256 `b623239c02a6c647a9160b6e6f1c0b1108f082e41f4c4d40a6b2866e8e0dc15b`, mode 33188. It was not copied. The temporary worktree `out` link named in the sealed status header is absent. No phase28 `out` tree was walked.
- `node_modules` is a symlink to `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence/node_modules`, mode 41453, which is itself a symlink to `/Users/cyotee/Projects/indexedex/node_modules`. Targets were not opened.
- `lib/crane` is an empty directory, mode 16877, childCount 0, plus gitlink `160000 fc0618bf5c34d0564f4367130feff443bd4efc89`. It is not a symlink in this worktree. The submodule was not checked out or updated.
- All **31** foreign Git indexes are unchanged. This worktree index changed from `32cba2775feb98fee6b8ea2e4cad7e5ca913a70f1f4b3bc326da5f78b2d5533b`, 2078515 bytes, to `8e55be0964db3e0446ca4664d70e67c4391a5962887cd0651c72ee6f9503b42f`, 2078515 bytes, mode still 33188. The index matches the commit: staged diff empty and `git write-tree` equals `9bfb1e7290913fbbe75541983d895636bb79bafd`. The baseline records 32 indexes: 31 foreign and 1 own.
- `show-ref` changed only `refs/heads/work/dtf-migration-phase-30-recovery-receipts`, from `07d54b9a3d20d98aee24e75235bbf16b650a8028` to `1694e68a4bd66dd67d3b5e3f145f1da23074ff48`. Other show-ref lines are unchanged. Between the pre-stage ref capture and the post-commit read, 26 loose ref files, including this branch, were absent and `.git/packed-refs` changed from SHA-256 `c9b82b77265bae5c48a14f51d7f5f2e00a223688b420889aee5b79a98bf6771d` to `d4eaea5282d2f7e72f8eedd07e617823fb095218f60756366b17a7eccdaf4711`. This delivery did not run `pack-refs`, `gc`, or update those branches. Loose-file bytes are not claimed preserved. The paths are `support/ref-bookkeeping.json`. Reflogs were not in the preservation set.
- Five verifier scope files, including foundry.toml, package.json, the current plan, the current PRD, and the phase30 brief, match their precommit hashes and modes. No phase09 worktree path or held09 worktree path was opened. The phase09 foreign index, when present, was hashed only as raw bytes under `.git/worktrees`.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the eight accepted paths. No merge, cherry-pick, rebase, or index lock is present.

## Additive evidence-directory growth

The full rehash above was taken before `recovery-receipts/commit/` existed. At that point every original owned-evidence and input content, permission, and directory row matched. The support files and `source-manifest.json` were written after that proof. They are excluded evidence, not a preservation failure of an original row.

After those files were written, and before `support/preservation-compare.json` and this receipt, the owned-evidence rewalk found 29 additive content paths, 31 additive permission paths, and 2 additive directory paths. All of them are under `recovery-receipts/commit/`. Unexpected additive paths: none. Original content rows changed: 0. Input rows were rehashed again and were unchanged.

Original directory and permission rows whose bookkeeping changed because of that added child: 1.

| Path | Kind | Mode | Before size | After size | nlink | childCount |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `docs/incidents/2026-09-16-dtf-recovery/migration/recovery-receipts` | dir | 16877 / `0o755` | 128 | 160 | 4 to 5 | 2 to 3 |

Kind, permission, and `st_mode` did not change. The permission row changed only in `size`, from 128 to 160. Directory SHA-256 remains null. `childrenSha256` moved from `6427893862c3486e1889c0f3958e78f4e1423eaf68bdb0c670238d58b2430259` to `c7fc894590f20266a5c6109144443da05e87deae03aa23b777e5132c15e9af1d` because the child set gained `commit`.

`support/preservation-compare.json` and this receipt are two later additive files under the same `commit/` directory. Neither is a member of the 29-path additive list. This receipt is the last file written in that directory.

**No pending operation.**
