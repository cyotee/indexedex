# Independent bounded W-SD local delivery audit

Date: 2026-11-12.

**Verdict: confirmed.** The actual local commit delivers exactly the 34
runtime-accepted final source files, with no source-byte exception or extra
committed path. Parent, branch, current blobs, modes, attribution, exclusions,
retained per-entry preservation baselines and sealed evidence checks agree.
Historical metadata limits below remain qualifications, not invented equality.
No fix or new commit is requested.

This is a delivery audit, not another runtime execution or a new source review
acceptance. No unchanged suite, build, CLI transaction or gas experiment was
replayed. Only this report and `commit/audit-evidence.json` were authored.

## 1. Actual delivery and acceptance authority

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se`.

| Independently observed fact | Value |
| --- | --- |
| Branch | `work/dtf-migration-phase-15-dtf-custody-se` |
| Commit | `4a53299b490343ed904d70c92ecbc7360fcb7659` |
| Required and actual sole parent | `2baab6e58dafcc3fe5f9a94570d99987d58bf42b` |
| Commit tree and current index tree | `318cdbf5e6af7c1ebd00d51d164edf7dade3255b` |
| Commits after required parent | 1 |
| Subject | Add verified bounded DTF-custody SE surrender and recovery |
| Paths | 34: 27 modifications, 7 additions |
| Diff totals | 1575 insertions, 55 deletions |
| Coauthor trailer count | Exactly 1 |

The sole trailer is
`Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`.
The actual commit object, rather than the receipt's claimed hash, was examined.
The delivery receipt and source manifest agree with these observations.

The complete delivery brief, retained complete phase15 brief, actual producer
report, actual independent runtime report, complete verifier bindings,
source-authority and artifact-reconciliation manifests were read. Current
plan r5 and PRD r22 were read from their expressly referenced authoritative
paths because those files are absent from this worktree; no writes were made
there. Their raw hashes match the accepted authority bindings:

| Input | Recomputed raw SHA-256 |
| --- | --- |
| Independent runtime report | `77e67678c3180b4ef487fb40567131e9aea0e6c03f7f0f0f1f66003d1226669e` |
| Delivery source manifest | `c9c1c35eb5ee37e5f635116afb27975ba8939d9c87cdcc5c8072c2bb89c0b010` |
| Plan r5 | `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d` |
| PRD r22 | `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed` |

The runtime report's confirmed disposition covers 122 Migration specs, 71
pinned forks, 62 operator tests, strict types, artifact preparation, both
operator stages and the actual fixed18565 CLI. It separately establishes
signed controlled-wallet acquisition and all three mined-before-checkpoint
resumes. These are the prior independent verifier's executions, not executions
performed by this audit or producer counts adopted without their actual report.
All 385 verifier evidence entries were independently rehashed without mismatch.

## 2. Independently derived accepted set and full delta

The accepted set was derived from `verification/bindings.json:sourceFiles`
and cross-checked against all 34 `verification/source-authority.json`
source snapshots and the complete embedded
`implementation/source-snapshots-final.json` bytes. It was then compared with
the actual commit's `diff-tree` set, not derived from the delivery manifest's
pass flags. The sets are identical, with no duplicate, missing or extra path.

For every path, the verifier expected and actual SHA-256, independently
rehashed snapshot contents, committed blob bytes and current raw bytes are
identical. Actual Git blob identifiers, parent blobs, byte lengths and current
modes also match the producer's manifest. The independently computed full
per-path result is retained in `audit-evidence.json:sources`; that is the
exact accepted path/hash/mode set for this audit.

All 34 current and committed modes are `100644`. All 27 parent-tracked modes
are also `100644`; the seven additions are regular non-executable files.
**Historical runtime evidence attests bytes, not modes.** These mode conclusions
come from the actual parent/current filesystem/commit, not a nonexistent
runtime mode inventory.

The complete committed diff was inspected, including all seven additions,
and every complete candidate file was read for exclusions and signing material.
The full diff produced by
`GIT_MASTER=1 git diff --ignore-submodules=all --no-ext-diff --no-color --binary HEAD^ HEAD --`
is 158092 bytes, SHA-256
`08364611e031e46b7d37ae4777abb7162a4e8d2b2c549a39d624ca74c80755e9`.
This includes additions, unlike the receipt's 82185-byte precommit
tracked-only diff; those are different scopes, not contradictory hashes.

The delta is restricted to nine Migration-specific production files,
neighboring Migration tests, the existing recovery operator/rehearsal,
corresponding execution stage and operator runbook. No evidence, snapshot,
journal, probe, broadcast, generated artifact/cache, dependency link,
configuration, root control file or requirements archive is committed.
The actual parent-to-commit path set also excludes ordinary/common/Crane
production. Staged and unstaged tracked diffs are empty.
`GIT_MASTER=1 git diff --ignore-submodules=all --check HEAD^ HEAD` exited 0.

Complete-file signing/endpoint inspection found only the public local Anvil
mnemonic and derivation index 104, the Foundry test holder seed, a loopback
listener template and `https://example.invalid`. The acquisition helper checks
`127.0.0.1:18565`; the existing runbook names an RPC alias without resolving
its credential. The Forge environment deletes `PRIVATE_KEY`. No resolved
secret endpoint, PEM private-key block or production signing material was
observed. Local fixture material was retained as accepted, not rewritten.
Exact locations and inspected lines are in `audit-evidence.json:secretScan`.

## 3. Retained per-entry preservation and protected state

Each retained JSONL inventory was parsed, its serialization reproduced, its
aggregate rehashed, and every entry independently compared with current
`lstat` kind, normalized mode, size, SHA-256 and symlink target. A separate
non-symlink-descending walk checked additions. All comparisons passed:

| Retained inventory | Entries | Recomputed inventory SHA-256 | Missing/changed |
| --- | ---: | --- | --- |
| `precommit/docs-incidents.jsonl` | 802 | `976afcfeaea79c66ae6488482c4f0810c0bbd5ff3899860cfd7875a08ef40204` | 0 / 0 |
| `precommit/out.jsonl` | 7321 | `90924744f2003f47870fc12db271363666e233e85ccb40b63482bceb390179ad` | 0 / 0 |
| `precommit/cache_forge.jsonl` | 592 | `82dfe6b7ace19101efbfff4201c5279630510a9b5766489956cbc29b03b08077` | 0 / 0 |

The retained recipe hash is
`44543685c7fe131d468744a8427a7ebae25b57f988ba65b870c12121d23278e9`.
Its recipe is reproducible: POSIX path sort; fixed key order
`path,kind,mode,size,sha256,target`; compact UTF-8 JSON Lines; one newline per
entry. Regular files hash raw bytes; symlinks hash their UTF-8 target string
and are not descended. The audit recomputed this serialization, not only the
producer's aggregate strings.

There are no added `out/` or `cache_forge/` entries. Before this audit's writes,
the only eight added incident paths were the excluded delivery manifest,
receipt and six retained precommit evidence files. This audit adds only its
two owned evidence paths. Existing reports, seals, bindings, raw witnesses,
logs and snapshots in the 802-entry baseline remain unchanged.

All 398 producer evidence entries and all 23 entries across producer/verifier
seal files were independently rehashed and match. Thus the historical
attempts and final acceptance remain sealed as supplied; neither was rewritten
to hide the artifact qualification.

The actual retained `precommit/status-before.txt` contains 707 entries:
27 unstaged tracked modifications, seven untracked accepted source additions
and 673 other untracked evidence paths. There are no staged entries.
All 673 foreign untracked status entries remain present, with their contents
covered by the incident inventory. The current index equals the committed
tree; there are no foreign staged paths to remove or restore.

The retained `precommit/show-ref.txt` hashes to
`dc6dcb977584cbe39951d1cecb7fcd7a08e4a7a29bf8d5394f386d417690d098`.
Comparison of every retained/current ref finds only the expected movement of
this branch from the required parent to the delivery commit. Main,
origin/main, other work branches, stash and the held phase09 ref remain
unchanged relative to that retained baseline. Only ref identities were
compared; no held09 content was inspected, imported or replayed.

Both prescribed links are present and match the receipt's current
observations: `lib/crane` targets
`/Users/cyotee/Projects/indexedex/lib/crane`, inode 18688325; `node_modules`
targets `/Users/cyotee/Projects/indexedex/node_modules`, inode 18688326.
Both have permissions `755`. This audit did not replace or traverse them for
dependency setup.

### Historical evidence limits

These inventories prove present equality to the retained per-entry baselines.
They do not independently prove the original capture time, absence of an
intermediate change later restored, or earlier phase14 history. No stronger
historical claim is made.

The retained precommit status supports an empty staged set, but no raw
precommit index serialization was retained. The receipt's historical
`write-tree` observation is not independently reconstructed as raw index-file
equality. Likewise the inventories omit timestamps and inode/link history;
current link inode observations are not a retained precommit inode baseline.
The earlier phase14 audit's unavailable aggregate-input qualification remains
historical and is not silently upgraded by this phase's new inventories.

## 4. Single regenerated test artifact reconciliation

The sole recorded rebuild is excluded from the source commit:
`out/MigrationNftConfiguration.t.sol/MigrationNftConfigurationTest.json`.

| Raw JSON identity | SHA-256 |
| --- | --- |
| Producer/admission | `a333899524467f478b78168fa79bb29600066910cb652eceec20f60bfe0d9e3c` |
| Independent verifier final and current | `99ce5bd22525c8acad1b84c632a7bc50e7bb958a3d8d5b212a421dce27a9a2e5` |

The current artifact is 997658 bytes and matches the retained precommit
inventory and independent final reconciliation. All 120 final artifact hashes
were independently recomputed and match their pre-CLI/after-CLI accepted
identities. The reconciliation lists exactly this one admitted-to-rebuilt
raw difference; it is not an unchanged-artifact claim.

The actual artifact's raw and parsed metadata both identify
`MigrationNftConfigurationTest` at the accepted
`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftConfiguration.t.sol`,
whose current/committed/accepted SHA-256 is
`ebda069c51e0e9658ccfb7cae7f0f3d67dd5dc95f7ec9cac5eeb2c59075a4e86`.
Both give compiler version `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`;
raw metadata additionally names Solar. All 550 source keccak256 entries in
each metadata representation independently match actual source bytes.
All 706 distinct source-authority compiled-source entries independently match
both their accepted keccak256 and SHA-256 values.

Raw and parsed metadata are not asserted structurally equal: the raw form
retains compiler name, a userdoc notice and ten empty ABI output arrays omitted
by the parsed form; 550 missing raw license fields become null in the parsed
form. These are observations within the current artifact, not an explanation
of the unavailable old JSON. The complete old raw artifact was not retained,
so field-level old/new equality, old metadata equivalence and the cause of
the raw regeneration cannot be independently established. Accepted final
source/target/metadata identities are established without inventing that claim
or replaying the unchanged test.

## 5. Cleanup, limits and final disposition

Independent audit cleanup probes found no listener on port 18565
(`lsof` exit 1, empty output), no verifier Anvil PID 2461 (`ps` exit 1, empty
output), and no fixed checkpoint directory (absence test exit 0).
No merge, cherry-pick, rebase or index-lock state is present.
This audit started no runtime, subscription or background operation.

Supporting `commit/audit-evidence.json` retains the computed source identities,
inventory results, ref delta, seals, exclusions and artifact qualification.
Its raw SHA-256 is
`afff09d95c9a823c09129c705435375637f8201d388767ec1f2753297d8b11dc`.
JSON was serialized directly; Biome LSP is not installed, so JSON LSP
diagnostics could not run. No dependency/configuration installation was made.

The independent runtime report records local parent deployment gas
**43,770,976**, above the retained historical **32,000,000** transaction limit.
That is an observation on its permissive local node, not deployment-gas
acceptance. No full-category, original operational allocation, full hermetic,
full-plan or public-execution acceptance follows. W-SW, earlier SE,
owner-restricted LP, raw weight/receipt support and actual approved
original-wallet/origin/Q0/component records remain open as documented.

**Final bounded local-delivery disposition: confirmed, with the explicit
historical metadata limits above. No source modification, new commit or public
action was performed or requested. No owned pending operation remains.**
