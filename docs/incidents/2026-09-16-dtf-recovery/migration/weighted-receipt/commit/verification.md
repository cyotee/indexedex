# Independent weighted-receipt local commit audit

Date: 2026-11-12. **Disposition: confirmed for bounded immutable local delivery only.**

The actual complete final `receipt.md` and `source-manifest.json` exist, are not pending, and describe the actual commit. No blocking delivery discrepancy was found. This verdict does not accept the full Migration plan, operational allocations, portable/full-hermetic execution, target deployment feasibility, or a public operation.

## Actual delivery and admission

| Identity | Independently observed value |
| --- | --- |
| Worktree | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-17-weighted-receipt` |
| Branch | `work/dtf-migration-phase-17-weighted-receipt` |
| Commit | `acdbe319f3a20c3af6bea594c62461b6c7988717` |
| Sole parent | `a96f0fd26c1a1fdba35750cff74d866afa3a9796` |
| Tree | `5c876ffe15dc89e8a47ceb84b7b3e81676a73dd7` |
| Subject | `Add verified bounded weighted receipt surrender and recovery` |
| Author and committer | `Cyotee Doge <not_cyotee@proton.me>` |
| Author and committer date | `2026-11-11T22:11:26-08:00` |
| Complete source delta | 36 paths: 29 modifications, 7 additions; 1537 insertions, 56 deletions |
| Final manifest SHA-256 | `c773d0b76c8fbbaf308b8d9e303cd5c30090147457d5b6980327c3b548f8f753` |
| Final receipt SHA-256 | `6beb85a062839fdc23e3e286a68af64afd444779eeeea5a43fc7efdc20406716` |
| Accepted runtime report SHA-256 | `65108f5890f7c7371f1d8a7c2752e35a6a61705adc7ca70fd9c724ed445e9490` |
| Producer seal SHA-256 | `082357f4df799ddd70380f872d6f323e7ab1ce2e5b9865fa9a3e42d75716ce16` |
| Verifier seal SHA-256 | `649efd9d3dce87c49db691ec6dd3937294156d121490aca8159090bda86b1f9a` |

Read the complete commit brief, original phase17 brief, implementation brief, producer report, final receipt, and admitted independent runtime report. Parsed the complete actual manifest, source bindings, seals, retained preservation recipes and original per-entry baselines. The admitted report's raw hash was recomputed and matches the root-supplied identity.

Raw `cat-file commit HEAD` is 1208 bytes, SHA-256 `cfb164f023e4fc7f68ec505f761ba2072214514e1b8e38a4eea428f859bcebf4`; independently recomputing its Git object framing reproduces the commit ID above. Raw tree content is 2202 bytes, SHA-256 `a7f36f5eb095e2df790680587478eeac107dc0594f040f8def0fce894756ecb8`; its framed Git hash reproduces the tree ID above.

The message contains exactly one `Co-authored-by:` line, in its final trailer paragraph, exactly `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. Its subject follows the observed parent history convention. Cryptographic signature verification exits 0 using the existing `/usr/local/bin/gpg`, key `55EB42889513051267BC55A395206404A78FB7F3`. GPG reports unknown local certification/owner trust; a good cryptographic signature is not represented as independently certified human identity. There is no configured upstream; the lookup exits 128 as recorded. No fetch or push occurred.

## Independent path, blob, mode and exclusion audit

Derived the 36-path set from `verification/seal.json:candidateSources`, independently cross-checked against `verification/bindings.json:preserved`, producer `implementation/seal.json:finalSources`, and `implementation/audit-02/source-bindings.json:sourcePaths`. The final receipt and status listing were not used to choose the accepted set.

For every accepted path, compared the complete current raw bytes and length, actual committed blob bytes obtained with `cat-file blob`, accepted SHA-256, producer final SHA-256, producer audit SHA-256, retained source snapshot, manifest fields, parent blob, and actual raw delta modes. All 36 agree. Accepted decimal mode 420 is actual permission `0644`; all committed modes are `100644`. All 29 existing parent modes are `100644`; all seven additions have no parent blob. There are no duplicate, omitted or extra paths.

The complete parent-to-HEAD raw delta equals that independently derived set. Production edits are the nine Migration-specific interface/storage/allocation/recovery/legacy paths; remaining paths are the adjacent specs/forks, existing operator/stage home and runbook. No ordinary/common/Crane production, dependency, configuration, evidence, held09 or other excluded path is committed. The complete current status contains only untracked weighted-receipt evidence; staged and unstaged tracked source diffs both exit 0 with empty output. Evidence remains local and uncommitted.

The actual full immutable delta, including all seven formerly untracked additions, passes:

```text
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git diff --ignore-submodules=all --check HEAD^ HEAD
```

Exit 0, empty stdout and stderr. This is not an empty-index substitute or a hash-based whitespace waiver. `rev-list --count HEAD^..HEAD` returns 1, and raw commit content has exactly the required parent. No audit commit, source edit, history rewrite or whitespace correction was made.

## Original-baseline preservation

Reproduced the retained `precommit/recipe.txt`, SHA-256 `ebf55ae45f4fd64639e308b23cc74169785434b8ae261de2bcd2f1e9451f4d56`, against every original record. Walks use `lstat`, do not follow symlink directories, hash raw file bytes or raw UTF-8 link targets, retain original key order and POSIX sorting, and serialize compact UTF-8 JSONL with a newline per record. Each original row was compared with its current counterpart; aggregate identities are additional checks, not substitutes for missing historical rows.

| Original retained inventory | Entries | Independent result |
| --- | ---: | --- |
| `precommit/docs-incidents.jsonl` | 1561 | No missing or changed original entries; retained-current hash `ca8f3c6e3486279d045c1d63723aa654f4d4acbc5074d5df521524c55f40bbce` |
| `precommit/docs-incidents-perms.jsonl` | 1750 | No missing entries or changed file permissions/hashes; only the documented enclosing directory size change below |
| `precommit/out.jsonl` | 7337 | No missing, changed or added entries; hash `644ac1053a1dafa8f35323ea8778068cf3e190d80db7e61c7a1371c35d01aebe` |
| `precommit/cache_forge.jsonl` | 599 | No missing, changed or added entries; hash `fac4556af9b93fad665070e677840c1802c5e89998fc12b078bf6c0d3d8f880f` |

The permission baseline raw hash is `b46be8e2a0de767b2000b3573d8789d14244930ea65b39c22c75e0e4504f1522`. Its only changed original row is directory `migration/weighted-receipt`, size 192 -> 224 after creation of excluded `commit/`; kind, `0755` permission and null directory hash are unchanged. The retained-current permission hash is therefore honestly different: `86b4ca58d7925fc9d428b089f5574aa16603d96eda76135a5eef95538f877cbb`. This is not claimed as exact aggregate equality.

Before audit files were added, the independent walk found 20 new git-mode entries and 23 new permission entries, all the new `commit/` directory or its descendants. Audit evidence and this report are likewise explicitly excluded new evidence, not historically baselined preservation members. The failed serialization-attempt-01 files remain retained; their malformed serialization is not substituted for the corrected pre-staging original baselines. Git-mode serialization alone is not a read-only-permission proof: actual sealed permissions were checked against the distinct permission baseline and available producer/verifier mode records.

All 17 foreign worktree index files match their original per-entry size, permission and SHA-256 baselines. The current worktree index changed only as expected from `c97896e1ec5399cb1654f31b8707ad3d90433fca0112a977cd5d35cacadd4c83` to `ca6c853db62e934f402e816ff23702ca8fffba7f74923e4fb4e97ae770c83f6e`; staged and unstaged comparisons prove the current tracked index/worktree agree with HEAD. No index write was performed by the audit. Only the phase17 ref moved, from the required parent to the audited commit. Every other ref matches the original `show-ref.txt` baseline, SHA-256 `c2ea68c17d7b3b1c9520e37cc267e034847dbd8542816f714487f8945cc6cde1`. Held09 preservation was limited to its required foreign index hash and ref identity; its candidate source was not inspected.

Rehashed all 958 producer evidence entries, all 450 verifier evidence entries, all 994 accepted preserved entries, all 236 original immutable references, all 137 admitted source/admission members, and 13 authority bindings. All expected lengths, hashes and available original modes match. Exact memberships are unchanged: source 104, source-verification 33, implementation 959 including its self-excluded seal, verification 451 including its self-excluded seal. No historical report, failure, snapshot, seal, journal or witness was replaced.

The two prescribed links retain target, inode, permission and length: `lib/crane` -> `/Users/cyotee/Projects/indexedex/lib/crane`, inode 19240329, mode `0755`, 42 bytes; `node_modules` -> `/Users/cyotee/Projects/indexedex/node_modules`, inode 19240330, mode `0755`, 45 bytes. The phase15 W-SD archive remains at `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se/docs/incidents/2026-09-16-dtf-recovery/migration/dtf-custody-se/implementation/source-archive.json`, 1,047,506 bytes, `0644`, SHA-256 `600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`. No relocation, chmod, artifact rebuild or cleanup was performed.

## Binding to actual executed runtime proof

This audit did not replay unchanged tests, builds, CLI or runtime auditors. It rehashed all six original check logs against sealed `checks.json` exit codes, raw lengths and SHA-256; read the retained exact commands, coverage and final auditor/cleanup results; and preserved every sealed raw witness. The actual commit/current/accepted equality above binds immutable delivery to that already executed proof:

- 134 complete Migration specs and 92 pinned forks, zero failed/skipped; both operator-stage builds; strict operator types; all 68 operator tests in one invocation.
- Actual fixed18567 CLI, 25 actual deployed bindings, 675 compiler source bindings and five static stage/ABI bindings.
- 49 signed operator completions, 13 additional WS signed operations, and all 15 actual raw receipt fields for each of three real mined-before-checkpoint interruptions and fresh-process resumes.
- Independently executed binding, signed-receipt and economic audits. Their initial failed auditor attempts remain failures; corrected final exits are 0 and the final strict verifier-probe typecheck is retained.

Runtime quantities and economic boundaries remain exactly those in the admitted report, including the positive nonrepresentable Q/C residual, separate genuinely divisible terminal fork, synthetic code-proof originals rather than operational allocations, and prior archived-source equivalence limits.

## Qualifications, evidence and final cleanup

Solidity LSP was clean only for the inspected Recovery target. TypeScript LSP freshness was unreliable; retained final strict typechecks supply type evidence, not a retroactive clean-LSP claim. JSON LSP remains unavailable because Biome is absent; the audit JSON was constructed and parsed directly, with no dependency or configuration installation. The audit's initial schema/helper inspection errors were corrected before comparisons completed and are recorded in supporting evidence; no source or historical evidence changed.

Actual signed parent deployment gas remains **44,353,454**, above the historical **32,000,000** transaction limit. A permissive local node does not prove target feasibility. Operational original-wallet/origin/Q0/component datasets, opaque-origin reconciliation, other source categories, native/WETH exposure and raw TokenStaking limits, host/archive portability, and full hermetic/full-plan acceptance remain open. The phase15 archive dependency must remain at its bound path until explicitly relocated.

Supporting `audit-evidence.json` is 395563 raw bytes, SHA-256 `a9f49a53bed347f732674591570c0f6c2670f0fdf639bfcb351fb913ec2fb82a`. It retains every 36-path comparison, actual Git commands/exits, raw identities, per-inventory comparisons and exceptions, all foreign index comparisons, ref changes, dependency identities, seal/membership results and prior executed-proof bindings. This report and that new audit evidence are the only audit-owned files.

Independent cleanup probes find no listener on port 18567 and neither prior PID 40856 nor 29538: both commands exit 1 with empty output. The fixed checkpoint is absent. No merge, cherry-pick, revert, rebase, bisect or index lock is present. No runtime or background operation was started or adopted. **No owned operation is pending.**
