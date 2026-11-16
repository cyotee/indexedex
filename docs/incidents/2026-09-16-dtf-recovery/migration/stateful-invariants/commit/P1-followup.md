# Independent P1 qualified immutable-delivery follow-up

Date: 2026-11-12.

**Verdict: the corrected qualified claim accurately accounts for P1.
Current bounded commit/source/r2 identity is confirmed WITH P1 remaining
an unresolved historical raw-preservation limitation. Complete preservation
of every first-producer raw JSON version is not established.**

No separate current-source or evidence-integrity blocker was found in this
focused follow-up. This does not close P1, replace the original needs-fix
audit, or grant operational, public, target-gas or full-plan acceptance.

## 1. Exact correction and actual added evidence

The reviewed correction is the complete
`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase24-P1-qualified-followup.md`.
All relative paths below are under this worktree's
`docs/incidents/2026-09-16-dtf-recovery/migration/stateful-invariants/`.

The actual recovery directory is `historical-raw-recovery/`, alongside
`commit/`, not inside it. Its complete membership is three files:

| Added record | Raw bytes | SHA-256 |
| --- | ---: | --- |
| `historical-raw-recovery/P1-preservation-clarification.md` | 2705 | `4923d7a047bd20a98cddb6719a265665f768d22353e09a97db9bef361973a1de` |
| `historical-raw-recovery/root-search.json` | 9432 | `12095771998ee1d8e70c7388a121f28984d0f4d8a5d3dbd24ea45f5549bafcae` |
| `historical-raw-recovery/recovery-outcome.json` | 1634 | `4bfad25406a91ca20178fffae894b0a05800a1b6e8797f86fc65bf01e6edc616` |

All three have full mode 33188. They supply a scope correction and bounded
negative recovery records, not recovered payloads or a replacement baseline.
The clarification and root search retain their earlier pending-worker
language. The later `recovery-outcome.json` explicitly records completion
of both lookups without authentic retained bytes. Reading the earlier
pending language as the final state would ignore that additive outcome.
The earlier records should remain unchanged.

The peer-search record contains exactly 24 locations across 12 known
non-held worktrees: 12 consumer artifacts have the wrong length (466842),
and 12 handler locations report ENOENT. No location length-matched;
`exactMatches` is zero. This is not a universal absence proof.

The outcome records the original producer's result as "not retained in
the checked scope" and the original verifier's result as neither payload
retained in its available kernel or 13 inspected evidence files, with
original variables unavailable. Both record `newFile: false`.
These are the supplied completed worker-result records; this follow-up
did not revisit their kernels, re-search peers or recover bytes itself.

The correction withdraws only the broad all-historical-versions lossless
claim. It does not change a current source, artifact, runtime or test
requirement, or reclassify a failing current gate as passing.

## 2. P1 remains factual and unresolved

The complete original `commit/verification.md`, structured P1 in
`commit/audit-evidence.json`, and its five historical-producer
qualifications agree on these two missing first-producer raw identities:

| Missing first-producer version | Required raw bytes | Required SHA-256 |
| --- | ---: | --- |
| `out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json` | 466441 | `e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf` |
| `out/MigrationNativeHandler.sol/MigrationNativeHandler.json` | 266621 | `3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013` |

Their different post-first-verifier carriers remain respectively 466419
bytes / `787f14521060c4394778f1ad52181f1c2d0d0f6baef4fb1f1105e4e8b69733a7`
and 266602 bytes /
`10d277caa09ec26a32e7422db71544c4be13bca085aec8f94d4fcaef9751a3ba`.

The 179-path post-first-verifier baseline is intact, but path membership
does not retain every earlier raw version. Five first-producer versions
differ from those carriers. The original audit locates three exact versions
in `implementation-r2/candidate-artifacts-07.json`; the two above have no
matching admitted carrier, and the subsequent bounded searches recovered
neither.

Matching creation-object text, runtime-object text and raw-metadata
fingerprints support only those narrower identities. They neither recover
the missing raw JSON nor establish its exact historical field differences.
The six current-versus-stopped-candidate artifact diffs in the original
audit are a different comparison and cannot be assigned to these missing
historical versions. No reconstruction, serialization, recompilation or
retrospective baseline is used here.

Accordingly, `commit/verification.md` remains accurate history:
needs-fix for complete historical raw preservation, while current stopped
source/r2 runtime identity passes. This follow-up qualifies delivery; it
does not convert that historical needs-fix into an all-versions pass.

## 3. Independently checked unchanged current subject

All Git commands used `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0` from the required
worktree. Status and diff commands used `--ignore-submodules=all`.
Every invoked Git command exited 0 with empty stderr.

| Subject | Independently observed |
| --- | --- |
| Worktree | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-24-stateful-invariants` |
| Branch | `work/dtf-migration-phase-24-stateful-invariants` |
| HEAD | `8db3f5ee6310e8a700dad2d6a33e21d0955e63ca` |
| Sole parent | `15fd629375edeb361f6a39262795bdc66723ca3a` |
| Tree | `464742d40290a5a11686afe75f5ee061f56a4677` |
| Subject | `Add verified bounded Migration stateful invariant tests` |
| Raw commit content | 1203 bytes; SHA-256 `7d8f0206d5ef6df58117d8e62ca652ab39762f671e6349c9217ebd1635d1e402` |

`rev-list --parents -n 1 HEAD`, `branch --show-current`,
`rev-parse --git-dir --git-common-dir HEAD^{tree}`, and
`cat-file commit HEAD` establish these values directly, matching the
original audit. `diff-tree --no-commit-id --name-status -r HEAD` contains
exactly the 14 additions independently derived from
`verification-r2/source-locators.json` candidate entries, with no extra
path. Current raw SHA-256, length and full mode 33188 match every one of
those 14 accepted source entries.

Both `diff --cached --ignore-submodules=all --exit-code` and
`diff --ignore-submodules=all --exit-code` have empty stdout.
Incoming status contains 112 untracked files, all within the incident
stateful-invariants evidence directory, and no tracked change.

Raw own Git metadata independently matches the original audit's postcommit
identities, not a newly invented clean-index baseline:

| Metadata | Bytes | SHA-256 |
| --- | ---: | --- |
| Own index | 2076067 | `82128293dce6005c647d33617c5c14ebfecfea73588ada9f915bff82cd7166a7` |
| Own HEAD file | 64 | `55eb467bf493d97b2f10565b49be43816ab9dbabf035325d891b0b22a0dd23fe` |
| Owned branch ref | 41 | `bbad16e5c6ca428ad8c6deeb8792560a9e2bf7c70aeb20c9b87b35f6fa3fb30c` |

Each has full mode 33188. No index or ref was written.

## 4. Original proof integrity and deliberate reuse

Exact original directory memberships still match the original audit:
22 implementation, 13 verification, 72 implementation-r2 and
17 verification-r2 files. Every recorded member's raw hash, length and full
mode matches; all four seal digests match; no member is missing or extra.
The recovery evidence is outside those sealed directories.

The original audit supports retain their published raw identities:

| Support | Bytes | SHA-256 |
| --- | ---: | --- |
| `commit/audit-evidence.json` | 3297465 | `46dfd8a96fa0acc55bea66aecde9a47d8df2dac703174884e685a8fcb34f1eb2` |
| `commit/audit-inventories.json` | 6620525 | `7a89b03847fe4741829af01660fe2bf44d3d8c5b5936440ecde787e7facae55f` |
| `commit/audit-method.md` | 10543 | `2d49181913f7fb80ce5299f4a845e8289b9de6eb64589851e6192caa0bba23c5` |

The original audit report itself is 20329 bytes, SHA-256
`8382fc37a73b283e8b534bde0ae862ab5e8357fc3971d09afcc484d59d3178d0`.
All four have full mode 33188.

The structured audit and inventory support were parsed completely; the
complete method and report were read. Their already completed proofs are
reused, not replayed: current 189-artifact binding, 979 compiler sources,
13 deployment subjects, 1127 captures, 66 distinct runtime templates,
171 specification / 147 pinned fork / 58 focused ordinary passes,
four invariants at 32 runs and depth 16, all twelve accepted property rows,
immutable whitespace, and original per-entry precommit preservation.
The historical binding-reconstructibility failure remains explicitly false
in the original audit; it is not hidden by the passing current checks.

No build, test, runtime runner, CLI/resume, RPC or signature verification
was replayed. Current artifact/runtime and full historical-inventory
comparisons are reused completed proofs, not newly executed checks.
Existing qualifications remain, including in-process rather than mined
deployment evidence, ED remaining held, claimed-origin admission limits,
historical failure logs, unavailable JSON Biome and registration gas
45116678 exceeding 32000000. No target or operational acceptance follows.

## 5. Ownership and stopped cleanup

The only owned write is this new `commit/P1-followup.md`; no additional
support file is required. Existing evidence was captured as 147 incoming
file identities for before/after preservation checking, not as a substitute
for any historical baseline.

The final comparison found all 147 incoming files unchanged in raw hash,
length and full mode, with only this report added (148 files total).
Final status adds exactly this report to the incoming 112 untracked paths.
Both final tracked diffs again exited 0 with empty output; HEAD and its
sole parent remained exact. Own raw index, HEAD file and branch-ref
hashes, lengths and modes remained unchanged. Own `index.lock`,
`MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REBASE_HEAD`, `rebase-apply` and
`rebase-merge` were absent.

No source, out, cache, dependency, ref, index, earlier report, seal or
baseline was edited. No held09 candidate was accessed, no commit was made,
and no external operation occurred. All short read-only Git subprocesses
completed; no background task, monitor, node or subscription was started.
No owned operation remains pending.

**Qualified conclusion: current bounded immutable delivery is confirmed;
P1 remains the two specified unrecovered historical raw JSON versions.
There is no unqualified all-historical-versions preservation pass.**
