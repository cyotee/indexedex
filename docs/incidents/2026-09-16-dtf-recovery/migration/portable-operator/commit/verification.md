# Independent immutable portable-operator delivery verification

Date: 2026-11-13. **Disposition: confirmed for this bounded local source delivery.**
Blocking delivery findings: none. P1 remains unresolved.

This audit read the complete commit brief and accepted source JSON, the phase26
brief, actual commit receipt and complete manifest, producer report/source
manifest/seal/cleanup, original failed verification report/proof/seal, and
independent r2 report/proof/seal/cleanup. It inspected the complete original
tracked diff and all five added source bodies. It reconciled actual independent
execution records without running the operator, tests, builds, or prior audit
programs again.

Paths below are relative to `portable-operator/` unless stated otherwise.
New audit output is only `commit/verification.md` and
`commit/verification-support/`. Existing evidence, source, indexes and refs
were not edited. No commit or other Git write was made by this audit.

## Immutable commit, source and index

Actual read-only `rev-list --parents -n 1 HEAD` returned exactly:

```text
0856a5c56e5d09b81c669f59b613efef79133e19 137fa0c8749165087c7d1d0156788f58a1dbf1b8
```

The sole parent is the required parent. Branch is
`work/dtf-migration-phase-26-portable-operator`; worktree is
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-26-portable-operator`.
The tree is `128c9c1fc2248574d30e23b760179fcba1b6a355`.
The actual subject is `Add verified bounded portable operator bundle relocation`.
The raw commit content is 1,204 bytes, SHA-256
`f6e79169250c625e90317d240b20f1d6ac7d7248e5d9f2ae9d8fbeccde56d067`.
This is the decoded Git commit object, not its compressed loose-object bytes.

The actual commit message contains exactly one coauthor line:

```text
Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
```

The retained receipt reports a good GPG signature with unknown ownertrust.
This audit checked the raw signed commit identity, not a new GPG trust verdict.

`diff-tree` gives exactly the 24 accepted paths: 19 modifications and five
additions. Actual shortstat is 817 insertions and 93 deletions. No evidence
file, production Solidity, dependency or configuration is in this increment.
For each accepted path, this audit read the current raw bytes, committed blob
and index blob and compared their lengths and SHA-256 to the accepted tested
JSON and frozen producer source manifest. All agree. Parent blob declarations
also agree with the actual parent tree.

All 24 current files have full lstat mode **33188**, permission bits **420**
(`0644`), and committed/index Git mode **100644**. These encodings were
checked separately. Git mode alone would not distinguish `0600` from `0644`.
All 60 frozen source files retain their tested bytes and permission modes;
the other 36 are unchanged and outside the commit delta.

The exact changed path set is below. Prefix `scripts/recovery/dtf-migration/`
applies to every basename except the runbook.

| Status | Path |
| --- | --- |
| M | `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md` |
| A | `bundle-files.ts` |
| A | `bundle-materialize.ts` |
| A | `bundle.test.ts` |
| A | `bundle.ts` |
| M | `cli.ts` |
| M | `execution-domain.ts` |
| M | `execution-schema.ts` |
| M | `preparation.ts` |
| M | `rehearsal-claim-vault-source.ts` |
| M | `rehearsal-claimed-sy-source.ts` |
| M | `rehearsal-data.ts` |
| M | `rehearsal-dtf-custody-source.ts` |
| M | `rehearsal-earlier-liquid.ts` |
| M | `rehearsal-earlier-receipt.ts` |
| M | `rehearsal-held-se-lp-source.ts` |
| M | `rehearsal-held-se-lp.ts` |
| A | `rehearsal-portable.ts` |
| M | `rehearsal-process.ts` |
| M | `rehearsal-recovery.ts` |
| M | `rehearsal-weighted-receipt-source.ts` |
| M | `rehearsal-weighted-sy.ts` |
| M | `rehearse.ts` |
| M | `schema.ts` |

The 60,829-byte diff of the 19 modifications has SHA-256
`193352dc21b6dec54a33d578e75cedc1ab8a9366a2131d7f7c3e65c76e795c40`,
identical to the original precommit diff and retained independent candidate
diff. The five added bodies were read separately in full, not inferred from
that tracked-only diff. Raw identities for every path and all 60 frozen
files are in `commit/verification-support/git-and-source.json`.

Every one of the 13,079 index entries matches the complete HEAD tree by path,
stage zero, blob and mode, with no missing or extra tree entry. This comparison
used `ls-files --stage -z` and `ls-tree -r -z HEAD`; it did not use `write-tree`.
Tracked staged and unstaged diffs are empty. Status reports only the existing
untracked `portable-operator/` evidence tree, not a clean-all-files claim.

Complete parent-to-HEAD whitespace, including all five additions, passed
`diff --ignore-submodules=all --check` and
`show --check --format= --ignore-submodules=all HEAD`, both exit 0 with empty
output. Current unstaged and cached whitespace checks also exited 0 empty.
No whitespace was rewritten. All 24 filter attributes are unspecified.

Every Git subprocess used `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat
PAGER=cat` and `git --no-pager`; diff/status ignored submodules.

## Actual report and seal identities

| Actual artifact | Bytes | Raw SHA-256 |
| --- | ---: | --- |
| `commit/receipt.md` | 12976 | `b8142a8295dcbd5347b603fc0c8d6e838192cb692ba3c778098523c1216744c0` |
| `commit/source-manifest.json` | 30351 | `0b6c15079a43b31db33fdee413cf8666660b2d1be6df4c8433c1d942459b512c` |
| `commit/preservation-compare.json` | 7397 | `020e32b8d50333450e8aac0262a0f638262d51e76f5c575984be420a8aeb2137` |
| `implementation/report.md` | 14971 | `bdaf47accd216719f1c57e60a3317fea207017f6a1d88076e5806422d7b03b86` |
| `implementation/source-manifest-stopped.json` | 24917 | `6e481524649151fb16b21c5a933494ffdb757da9679f282d7b176d3a7e9a0b6d` |
| `implementation/seal.json` | 4324168 | `4078009ee51764d30f198fd51b90a7133376f2e75365036efa304d62186de218` |
| `verification/report.md` | 4480 | `92e9c0d8a111d0b15bf77599cc74d54cc49d2c8df1e73890384a571bce326a84` |
| `verification-r2/report.md` | 18050 | `6a412318e5c876845290eb28d8fbf21b705a789981174ca08f7ae9d2c85cd17c` |
| `verification-r2/proof.json` | 433158 | `44a1712d5e1488e7a485ec462e32499682716c6126141d652bd3a6934425a819` |
| `verification-r2/seal.json` | 370760 | `bb255c9aa67b6fdd0eadade1bd770182e78648f1120f3a5730f736a3e3100db0` |
| `verification-r2/audit.json` | 14085625 | `b0273fc2fa2721b35d9fbd198b22f0b5d6d2397a8e9e0a899c35e4c30be93370` |
| `verification-r2/canonical-proof.json` | 345648 | `97f94c4d980a85d2aad47c799518006eab02a7b5746d6270dcc39f2160bd7d39` |

The independent report matches the commit brief's required raw hash.
All 16,770 producer sealed files/links and 179 declared directories match;
all 1,345 r2 files/links and 84 directories match. Exact file and directory
membership was walked without following symlinks. There are no missing,
changed or extra sealed members. Both original failed-intake sealed files
match as well. The seals themselves were hashed, not rewritten.

## Independent execution evidence read, not replayed

The actual `verification-r2/operator-tests.log` records **109 pass, 0 fail,
11 files** in one invocation on the frozen source. `gates.sh` and
`gate-session.log` retain strict type, artifact and stage exit-zero markers,
ending `VERIFIER_GATES_COMPLETE`; empty type logs alone were not treated as
exit proof. Stage output explicitly says compilation skipped because no files
changed. Artifact refresh preceded that stage gate. Existing Foundry warnings
remain, including the unknown `fmt.skip` key. No fresh build or test was run.

`runtime.sh`, `runtime-session.log` and `cli.log` record the actual sandboxed
18575 workflow ending `bounded-rehearsal-complete`, with `fullTask9: open`.
The independent runtime is `verification-r2/runtime/rehearsal-1794531335684/`,
not either failed producer runtime or the successful producer's runtime-r3.
Physical-access evidence records denied reads of all 22 original authority
inputs, authority-a and the producer implementation, while authority-b's
contained files were read under the inherited macOS sandbox.

For funding, configuration and replacement, the actual saved two-root
comparisons match the r2 proof. All 218 recorded contained-read entries
across the six materializations match actual raw bytes. Configuration and
replacement full payloads and frozen quote structures equal both each other
and the native saved preparations; configuration IDs are included in those
payloads. Their normalized location hashes differ intentionally. Funding is
preparation-free: its normalized hash and prepared payload/quote fields are
null; its evidence is the actual encoded funding operations and raw sources,
not an invented prepared-hash comparison.

All three actual killed command records have code null and signal SIGKILL.
Actual pre-resume records have no completion. This audit located the archived
journal intent and receipt files, rather than mistaking the small resumed
summary for a complete receipt. For each case, intent/signature/nonce remain
identical and the entire receipt, including nested logs and all 15 fields,
equals the pre-resume receipt and original canonical wire response:

| Operation | Nonce | Canonical transaction retained |
| --- | ---: | --- |
| Funding | 2139 | `0x07acba3c0fa9d22fa626a46dc6d110cd8b55f377664081bac42ec6ed63bbaec6` |
| Independent issuance | 2163 | `0xce0220825da9479f822e1d3e4b7a1741282fa34b01b486f2485fd7b5d813a03f` |
| Paid owner-first bond | 2215 | `0x6cb268e58b473c3f37530924452282f17e321d10a9da66f471080a479bb0f9e1` |

The canonical proof and log record exactly 1000e18 WETH and 1000e18 DTF
funding, three different independent recipients/bonds with 461 units each
(1383 total), and one paid first purchase. Six actual source-book transitions
include the one-weight, zero-output member. All 2,531 original HTTP-body
hashes/lengths and response IDs reproduce their canonical-proof entries.
There are 840 canonical transactions/receipts over 849 blocks.

Activation transaction
`0xb7168380fe1593da4eb8da5eb4e86c2c11ccd64f0396765a74e7e1618efcc027`
has its full raw canonical receipt in the retained evidence. Its 14
`DiamondFunctionRemoved` events name nonzero former facets and the complete
selector set:

```text
0x12076202 0x161d9afc 0x1ac7e79a 0x256c417b 0x516fc9a7 0x74d1295f
0x787642e8 0x92631220 0x9ade58a9 0xccff9894 0xe11315e2 0xe9dc9e6d
0xec55c474 0xf176a921
```

The r2 audit also retains actual routing checks and removed-loader failures,
no-send bundle/domain negatives, eight malformed claimed-certificate
rejections, and the separately qualified offline extra negatives. These are
read as historical execution evidence, not described as new executions here.

`native-compatibility.json` retains the actual prior absolute-input vector:
prepared hash `2db98d51c79ea0937fa1431f8b7612d8bbb10bb739bed744b50821d850432f04`
and signed configure-domain hash
`aabb19b60dd77e8859ecf31d371cd3f2c09acf6702bae78ff869f6dacbe7c446`
match; the latter binds 21 retained intents. Native normalization has no
bundle field. Locations were not removed from hashing. Both original-native
and first-location journal-domain mismatches still reject; this proves fresh
same-host relocation, not migration of a live signed journal.

The r2 proof binds 57 artifacts, 75 runtime captures, 301 compiler-source
identities, named library links, stage sources, actual constructor calldata,
22 package immutable values and 68 original preparation-input references.
The 184 original signed records and four explicitly offline reconstructed
records remain separate from 666 cryptographically recoverable canonical
signatures and 174 synthetic Anvil fixture signatures; these are overlapping
evidence classifications, not extra transactions.

Complete claimed originals retain Q0=18077396 and C0=466690583 each:
6025798 units deliver 155563510; the terminal 12051598 deliver 311127073.
Each has Q=C=0 afterward and separate 7776000-second funded cliff bonds.
Excluded 5416 SY and 7e18 unrelated raw weight remain excluded. Both actual
late-funding failures and their rollback qualifications remain intact.

## Every original preservation row

This audit independently rehashed every original precommit content row,
including full lstat modes, permission bits, byte lengths and symlink
targets. Every permission and directory bookkeeping row was also reproduced.
The nine `reproduced-*.jsonl` support files contain the actual observations
for **every original entry**, in original order and original field encoding.
They were generated from raw filesystem observations, not copied from the
old JSONL text or replaced by a newer inventory.

| Original inventory root | Content rows | Permission rows | Directory rows | Result |
| --- | ---: | ---: | ---: | --- |
| `docs/incidents` | 18134 | 18405 | 271 | All content/modes/targets match; one additive directory bookkeeping change |
| `out` | 7376 | 13856 | 6480 | Every original field matches |
| `cache_forge` | 6502 | 12368 | 5866 | Every original field matches |

All three reproduced content inventories and all six reproduced out/cache
inventory variants have their original raw inventory identities. Docs
permission/directory inventory digests differ only for the explicitly
identified directory below. `verification-support/preservation.json`
records each original inventory's actual raw identity, corresponding
reproduced identity and every differing field. The original precommit
inventory hashes also reproduce `precommit/summary.json`.

All 27 original foreign indexes match their actual original raw bytes,
lengths and full/permission modes. The own index is the already committed
2,076,635-byte index, SHA-256
`14fdc2ddcb7521f5a10f4789fc8d7caca905ea9a78ecbbd5655938b46d076053`,
mode 33188/0644. Its precommit identity was 2,076,067 bytes,
`ec3e978204abc33ed9bf0d127c15567447d174ec901eb3d1efc836c31872fadc`.
That authorized commit change is not attributed to this read-only audit;
the own raw index at audit intake and closure is unchanged.

Every one of the 52 original ref rows was reproduced. Only the authorized
phase26 branch ref differs from precommit: raw 41-byte content hash
`9f631241fe1d82ef6d8e279442be85e640fd477ee94da3690c0ef01ba31e76c4`
became
`6074490d00a3f530e8e310d74b23232e632f0f4d581b5191e3ec790b661fc401`.
Its mode remains 33188/0644. Actual `show-ref` differs only by that one
parent-to-commit line; both versions are 6,386 bytes and 66 lines. Reflogs
were not members of this original preservation set.

Both original host dependency symlinks match by actual target, SHA-256,
length, inode and full/permission mode. Their targets were not followed.
The Crane gitlink remains `160000 fc0618bf5c34d0564f4367130feff443bd4efc89`.
The phase09 worktree was not opened; its foreign index was hashed only at
the common Git metadata index path.

The earlier producer baseline was not substituted with the commit baseline.
All 13,989 earlier rows and their actual current/capture identities are
retained individually in `verification-support/producer-baseline.jsonl`.
Its 30 owned source/build/cache differences remain distinguished from
unchanged originals, including two compiler-pruned build-info files whose
original captured bytes remain available. Every referenced raw capture
matches its original byte length and SHA-256.

There is one copy-mode qualification: the content-deduplicated empty-byte
capture is full mode 33152/0600, while the original
`cache_forge/solidity-files-cache.json.abi.lock` is 33188/0644. The original
lock still matches its baseline bytes and mode. The capture preserves its
bytes and recorded original mode metadata, not the original filesystem
mode on that shared content-addressed copy. No chmod or restoration was
performed or claimed.

## Additive growth and preserved failures

At this audit's first full walk there were **28** additive docs paths,
all under `commit/`: the receipt's earlier 26-path observation plus its
two later files `preservation-compare.json` and `receipt.md`.
No additive out/cache paths were present. The complete 28-path list is
retained, not sampled, in `verification-support/preservation.json`.

The one changed original directory is
`docs/incidents/2026-09-16-dtf-recovery/migration/portable-operator`:
size 160 -> 192, nlink 5 -> 6, childCount 3 -> 4, and children SHA-256
`c6d953efa82909fc8c1f85763ab42362fb5810d3d1484806c6893c28b5c905a0`
->
`2d7b720f4d081179a4e9f5176aa8de88a417d7b93bacc2c4644339ac2e5bc6e0`.
Its permissions and full mode are unchanged. The added child is `commit/`.
Audit output adds only descendants of that existing child; those new files
are not members of the historical original inventory or prior seals.
`verification-support/closure.json` records the later output membership.

The first producer runtime's replacement-pointer failure, second runtime's
ordinary-SY/claimed-row selection failure, red noncanonical-envelope test,
earlier type/compiler/audit failures and exact raw captures remain sealed.
The verifier's original recorder failures and separate corrected fixtures
also remain. No failure was removed or relabeled.

The original `verification/` needs-fix result at
2026-11-13T00:34:59.880Z remains exactly a missing-handoff intake failure,
not a runtime verdict. Its report, proof and seal remain unchanged. The later
successful independent r2 is a separate record, not a rewrite of that intake.

## Limits and stopped closure

P1 remains exactly two unrecovered historical raw JSON versions,
`MigrationSnapshotConsumer.json` and `MigrationNativeHandler.json`.
Current builds/copies and preserved current baselines do not recover them
or prove all-history preservation.

This confirmation is only same-host saved-data relocation with installed
source/dependencies, warm artifacts, selected toolchain, existing archive
bootstrap and macOS sandbox. It is not full-plan, operational-originals,
archive-equivalence, cold-reconstruction, cross-platform, live-journal or
target-gas acceptance. Bundled review flags do not prove historical
eligibility, E0/D0/W0, original-wallet truth, known-zero prior delivery or
semantic alias disjointness. Unsupported E-S/raw/direct/partial/prior-delivered/
native/WETH sources, disabled conversions and approved actual datasets remain
open. Registration remains **45116678 > 32000000** gas; no held09 retry,
provider operation, public action or gas optimization occurred.

No runtime, build, tests, signer, observer, monitor or impersonation was
started by this audit. Read-only subprocesses completed. Actual listener
probe returned exit 1 with empty output for 18575; PID probes for producer
10877 and independent node 22503 also returned exit 1 empty. The live
checkpoint, owned temporary runtime parent and own index lock are absent.
Archived journals remain evidence, not pending work.

All generated JSON and every generated JSONL row were parsed and their raw
published lengths/hashes checked. Biome LSP is not installed; no installation
was attempted and no editor-clean claim is made. Source diagnostics/tests/
builds were deliberately not rerun; the immutable tested-source and actual
independent execution evidence above supply those results.

`verification-support/closure.json` binds this report and all new support,
records final Git/resource checks and qualifies additive output membership;
it makes no claim to its own digest. No existing seal is replaced.
**Confirmed at the stated scope. All owned operations are stopped; none is pending.**
