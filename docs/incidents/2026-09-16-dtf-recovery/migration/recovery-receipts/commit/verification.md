# Phase 30 immutable local delivery audit

Date: November 13, 2026.

**Verdict: confirmed for the bounded eight-file local delivery.** No needs-fix source-byte, commit-topology, evidence-integrity, or original-content-preservation defect was established. This is authentication of completed delivery and its stopped, recorded checks, not a fresh execution gate or financial, source-admission, operational, full Task 9, or full-plan approval.

Subject: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts`, branch `work/dtf-migration-phase-30-recovery-receipts`.

## Immutable commit and source identity

Independently read the complete commit brief, accepted source JSON, original phase brief, repository router, actual delivery receipt/source manifest, both complete implementation and independent reports, original evidence/source manifests, command receipts and complete streams, proof documents, cleanup records, and seals. Original baseline inventories were read and reproduced row by row, not replaced by a newer inventory.

The actual commit is `1694e68a4bd66dd67d3b5e3f145f1da23074ff48`, subject `Add verified bounded conversion and recovery receipt collection`. `rev-list --parents -n 1 HEAD` reports exactly one parent, `07d54b9a3d20d98aee24e75235bbf16b650a8028`. Tree: `9bfb1e7290913fbbe75541983d895636bb79bafd`. The raw commit object is 1,211 bytes, SHA-256 `f538afdbea0f7defc3c7eb7749c773466be2617e657414e01b10f8e588bd94ea`, matching the receipt.

`diff-tree --no-commit-id --name-status -r HEAD` reports exactly the eight accepted paths, all `M`, with no additions, deletions, or extra paths. Numstat totals 206 insertions and 17 deletions. The message contains exactly one `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>` trailer. The signature header is not a trailer. The stored invocation records `--trailer` and `trailer.ifexists=addIfDifferent`.

Every row below has identical current filesystem, index-blob, committed-blob, accepted-manifest, producer-final, and independent-final byte length/SHA-256. Full source bodies were read. Current filesystem mode is `33188`, permission `0o644`, and index/commit Git mode `100644` throughout.

| Path, relative to subject | Bytes | SHA-256 |
| --- | ---: | --- |
| `scripts/recovery/dtf-migration/cli.ts` | 13484 | `9c1f4bd76f904ff178e0620357d37ce4cc0a06db105480a9b168b406e530c437` |
| `scripts/recovery/dtf-migration/receipt-input.ts` | 5724 | `f0734996602d546e7670e7902b286d68093a60a8d28bf779859e7254a9d0a323` |
| `scripts/recovery/dtf-migration/receipt-evidence.ts` | 8738 | `e82ae8ed232b4bbeb408c6f85a63647415edb5ac5508fe8e9b7467027503762e` |
| `scripts/recovery/dtf-migration/receipt-reconciliation.ts` | 10148 | `f6d0ab3d229e438d059843939b0632ea761d26f7761b9cbb54af84a90e1a4dc4` |
| `scripts/recovery/dtf-migration/receipt.fixture.ts` | 8477 | `d4db87127b8634c42ca0b12fd21ae4301e0dd8628472359449a7402b175cf472` |
| `scripts/recovery/dtf-migration/receipt.test.ts` | 9645 | `3566f180237b37baf14e0ae28fdd420e035beb82ffcd6ea42e81f6ccd44d4fa1` |
| `scripts/recovery/dtf-migration/receipt-reconciliation.test.ts` | 9271 | `ca8ada6cbe818ee436c1344ed660d504877f548d8b021cd946ad14ebc68767e4` |
| `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md` | 65301 | `65474dcf25df7a9c737fe4b7afb4e9833bf148594f979d794d6356d08a49da4a` |

All **70** frozen operator/runbook bindings also match current, index, and committed bytes, both tested source manifests, and their original precommit mode observations; zero mismatches. This includes the 62 bindings outside this commit. Historical tested manifests omit modes: the observed filesystem/Git modes cannot establish the unavailable historical tested modes. No such evidence was invented.

The entire immutable parent-to-commit whitespace check and `show --check --format= HEAD` each returned exit 0, empty stdout and stderr. These were unfiltered whole-commit checks, not selected-hunk checks. Cached and unstaged tracked raw diffs are empty with submodules ignored. Evidence is untracked and absent from the commit tree.

The fresh complete immutable patch is 28,723 bytes, SHA-256 `24489d1a61812c9d7b91d03bf874cffb85a36cb6d10821636fbb56ea80533829`, identical to original `support/tracked-diff.txt`. It is the exact suffix of sealed `implementation/source.diff` (29,288 bytes, SHA-256 `8d39259f16511b8e655c6d716a87ae948bb83e1a0f936739fbde999a661f10ac`). Its additional prefix is the original status/HEAD output, including the then-present temporary `?? out` link. This is not a changed source hunk; the link is absent now.

## Authentication of completed checks and actual evidence

The accepted independent report is still 13,625 bytes, SHA-256 `b6fd48a199b7a577eaa4007741264d99e7b21d700a147e979c6e3f47b6077b50`. All **8 producer** and **12 verifier** direct seal/manifest bindings authenticate. Every original evidence-manifest member authenticates: **2,922 producer** and **2,916 verifier** rows. The original verifier intake's **2,930 producer-artifact checks** and original input identities also reproduce against actual bodies. There were no hash/length mismatches.

Authenticated all **18 recorded command receipts** and their complete stdout/stderr byte identities. The boundary receipt's stdout is `source.diff`, not a nonexistent `boundary.stdout`. The raw receipts retain argv, CWD, start, stop, exit, streams, and available source snapshots; none was replayed.

| Lane | Recorded command | Exit | Interpretation |
| --- | --- | ---: | --- |
| Producer | `types01` | 0 | Earlier snapshot; receipt-evidence differs from the later final body |
| Producer | `focused01` | 0 | 44 pass; same pre-freeze distinction |
| Producer | `mutation01` | 1 | Deliberate guard mutation: 41 pass, 3 fail; mutated reconciliation body is not final |
| Producer | `types-final` | 0 | Frozen production strict types |
| Producer | `operator-tests-final` | 1 | Missing warm ABI: 87 pass, 85 fail |
| Producer | `operator-tests-complete` | 0 | Complete unchanged suite: 172 pass, 0 fail, 15 files |
| Producer | `collect` | 0 | Sole actual producer collection, stopped |
| Producer | `support-types` | 0 | Final support strict types |
| Producer | `reconcile` | 0 | Completed producer raw reconciliation |
| Producer | `boundary` | 0 | Retained full source/status capture |
| Verifier | `types` | 0 | Frozen production strict types |
| Verifier | `suite` | 1 | 171 pass, 1 fail: relative CLI path absent from owned runtime |
| Verifier | `suite-final` | 0 | Complete suite after owned scripts read-link: 172 pass, 0 fail, 15 files |
| Verifier | `collect` | 0 | Sole actual independent collection, stopped |
| Verifier | `support-types` | 2 | Original TS2345 support flatMap inference failure |
| Verifier | `support-types-final` | 0 | Final owned support strict types |
| Verifier | `oracle` | 1 | Raw historical policy field versus parsed projection |
| Verifier | `oracle-final` | 0 | Completed two-archive proof with explicit projection qualification |

All 276 operator snapshots in the four passing producer final gates and all 552 in the eight verifier commands match the delivered operator bytes. Earlier producer snapshots and the deliberate mutation were compared separately and are not mislabeled as final-source proof. The initial TS2322 fixture diagnostic survives as a summary in `implementation/attempts.md`, not an invented original compiler stream.

The recorded strict gates use strict, noUncheckedIndexedAccess, exactOptionalPropertyTypes, and verbatimModuleSyntax. Final complete suite streams independently substantiate **172 pass / 0 fail / 15 files** in each lane. Missing/timed-out LSP and missing Biome are not passing diagnostics. Automatic diagnostics on this audit's JSON likewise reported Biome unavailable; no installation or configuration workaround was attempted.

Each actual archive authenticates **319 references, 319 distinct transaction results/canonical associations, 319 exact output rows, 319 saved Transfer locators, 2,228 receipt logs, and 1,278 requests**. The independent proof's complete reviews equal each saved reconciliation; its complete raw-capture rows equal each HTTP manifest. Every saved request/response envelope, length, SHA-256, ID, method/params, raw flag, received length, successful HTTP status and non-null result was authenticated from the existing bodies. All 2,556 response envelopes across both lanes passed. Empty failure/unavailable/redacted/conflict lists remain explicit.

Per archive, methods are one eth_chainId, 319 eth_getTransactionByHash, 319 eth_getTransactionReceipt, 319 eth_getBlockByHash, and 320 eth_getBlockByNumber. The original independent raw algorithm and its final command are retained, sealed and authenticated, not rerun here. Its canonical/log/order/output assertions are authenticated historical execution proof, not a claim of a new live observation or trustless chain proof.

The original population remains 250 conversions (7 bond_to_sdetf, 18 legacy_weight_to_sy, 138 detf_to_sdetf, 87 sdetf_to_detf), plus 69 recoveries. The retained proof establishes overlap 20 with the old 77 archive and 299 previously missing named transactions. The old collector was not replayed. All 36 input declarations and 28 input identities were independently rehashed. These are recovered authenticated historical bodies, not newly located original captures.

## Raw order, projection, and economic qualifications

Exactly **1,277 of 1,278** corresponding raw responses are byte-identical. Response **482**, eth_getBlockByNumber for `0x3da6876`, has 2,169 bytes in both lanes but different JSON-RPC property order:

- Producer: `jsonrpc,result,id`, SHA-256 `e598a900892bdaa06ab60cc2d685bf0323dc30f9233be37cbde61e6a13885797`.
- Verifier: `jsonrpc,id,result`, SHA-256 `3e05c0703fdd051d5b525bdf97883e57cddfe9762141c4c3bca17abad0f7f9c3`.

Parsed envelopes are deeply equal. Complete normalized results are equal. The only parsed archive difference is `http.sha256`. Reconciliation is byte-identical: 841,408 bytes, SHA-256 `7b900c143f64446301f8385f81eaa0daaada81a06d4dd0468de4b38dcd5d90d2`. Producer archive: 5,917,231 bytes, SHA-256 `6f3d656a88b325503f4cddd23cab96e582e171ce1f40e632eb065f4ad24fe9f2`; verifier archive: 5,917,231 bytes, SHA-256 `67a8cd97a26d0bfe4fc118469db605a9b0424e7b40c17fb977f6bd6990dfefc0`. HTTP-manifest hashes remain different: producer `aafc37d15f223382c84679188a8b5a2f125d4d5c1b645dddfbb1941ab87e151f`, verifier `dc93956548bb279085571472b19cc87d9e62e257ea90c76559ce8d7be46e8290`. No universal raw-byte identity is claimed.

Both parsed input metadata documents omit historical `sources.policyRevision` and otherwise equal the raw document's projection. The raw original equals the full document preserved in independent proof, including `held-assets-no-upfront-credit-20261108`; all raw-body bindings match. That historical field is not current policy authority. The initial failed raw-versus-parsed comparison and final passing qualified proof remain intact.

All 250 conversion flags remain `is_external_recovery=false`. Every recovery retains `classification=detf_exchange_output`, native18 DTF, `deduct_from_R=false`, and blank `R_eth`. All 319 rows retain reviewed-observations-only status and null priorCompensation, compensationDeduction, and currentCustody. Native9 conversion units remain separate. No credit, deduction, net contribution, original eligibility, current control, full W0/Q0 exposure, or source admission follows from matching a gross output. Principal/rewards and shared-transaction attribution are not replaced by totals. The existing default purchase/claim path and operational schemas are outside the changed schema surface; operational rejection is the authenticated sealed result, not a new loader run. Archives remain `NON-ISSUABLE-RECEIPT-OBSERVATIONS`; old 1,240 candidate unknowns remain separate.

## Original per-entry preservation reproduced

`audit-support/evidence-*.jsonl`, `evidence-perms-*.jsonl`, `evidence-dirs-01.jsonl`, `input-01.jsonl`, `input-perms-01.jsonl`, `input-dirs-01.jsonl`, and `refs-01.jsonl` contain **every original row**, its original expected fields, freshly observed actual fields, and exact differing field names. The expected rows come directly from original `commit/support/` baselines. Aggregate digests authenticate those baseline files but do not replace their rows. File SHA-256 is over raw bytes; symlink SHA-256 is over the UTF-8 target string, without dereferencing; permission and full lstat mode are separate from Git mode.

| Original baseline | Rows reproduced | Result |
| --- | ---: | --- |
| Owned evidence content | 5842 | All raw bytes, lengths, modes and targets match |
| Owned evidence permission | 5849 | All permissions/full modes match; one directory size bookkeeping change |
| Owned evidence directory | 7 | One additive-child bookkeeping change, detailed below |
| Recovered input content | 30 | All fields match |
| Recovered input permission | 35 | All fields match |
| Recovered input directory | 5 | All fields match |
| Original raw ref-file baseline | 60 | 26 loose files absent and packed-refs changed, explicitly retained |
| Original index baseline | 32 | All 31 foreign indexes match; own expected commit change retained |
| Original frozen source modes | 70 | Current modes and bytes match original observations |

The original owned root changed from size 128 to 160, nlink 4 to 5, childCount 2 to 3. Kind, full mode 16877, and permission `0o755` are unchanged. Children digest changes from `6427893862c3486e1889c0f3958e78f4e1423eaf68bdb0c670238d58b2430259` to `c7fc894590f20266a5c6109144443da05e87deae03aa23b777e5132c15e9af1d` because `commit` was added. This reproduces the receipt's qualification, not universal directory preservation. There were 31 original additive commit-delivery files at audit intake: the previously enumerated 29, plus the later preservation comparison and receipt. This audit adds only its owned verification file and audit-support directory.

All original indexes were hashed as binary bytes, not decoded text. Own index changed from precommit SHA-256 `32cba2775feb98fee6b8ea2e4cad7e5ca913a70f1f4b3bc326da5f78b2d5533b` to observed committed SHA-256 `8e55be0964db3e0446ca4664d70e67c4391a5962887cd0651c72ee6f9503b42f`; size remains 2,078,515, full mode 33188. This is the expected commit change, not a preservation failure or an audit Git write.

Logical show-ref comparison changes only the subject branch from the required parent to the delivered commit. The 26 original loose ref files remain absent; packed-refs remains 6,754 bytes, SHA-256 `d4eaea5282d2f7e72f8eedd07e617823fb095218f60756366b17a7eccdaf4711`, versus original 4,291 bytes, SHA-256 `c9b82b77265bae5c48a14f51d7f5f2e00a223688b420889aee5b79a98bf6771d`. Logical values and raw-file preservation are distinct. The prior delivery recorded concurrent ref packing; this audit verifies the state without attributing who packed it or inventing preserved loose bytes. Reflogs were outside the original baseline.

`original-baselines-and-links.json` retains every original index, dependency/artifact/pointer/scope observation and actual comparison. `node_modules` remains a mode-41453 symlink to phase28/node_modules, itself a symlink to primary node_modules. Targets were not traversed. `lib/crane` remains an empty directory, mode 16877, and gitlink `160000 fc0618bf5c34d0564f4367130feff443bd4efc89`; it is not a symlink. `out`, `cache`, and `cache_forge` remain absent. The sole actually used phase28 Migration facet artifact remains 394,495 bytes, SHA-256 `b623239c02a6c647a9160b6e6f1c0b1108f082e41f4c4d40a6b2866e8e0dc15b`, mode 33188. No artifact/cache tree was invented or copied. Both review pointers and all five original scope-file identities/modes match. No held09 or phase09 worktree was opened; their administrative Git metadata is distinct.

## Audit method, limits, and stopped state

Proof is under `audit-support/`. `commit-and-sources.json` retains raw read-only Git command outputs and all 70 current/index/committed/tested comparisons. `command-receipts-and-streams.json` retains the complete original 18 command receipts/streams and per-snapshot comparisons. `manifest-and-seal-checks.json` contains every manifest/seal/intake result. `raw-capture-checks.json` contains every captured request/response identity check, the archive comparisons, original input checks, and raw-order/projection qualifications. `provenance-and-qualifications.json` binds the task inputs and records all original preservation differences. The support seal binds this report and every new support artifact, excluding itself.

Every audit Git invocation used `GIT_MASTER=1`, `GIT_OPTIONAL_LOCKS=0`, `GIT_PAGER=cat`, `PAGER=cat`, and `git --no-pager`; applicable diff/status commands ignored submodules. No Git write, write-tree, staging, commit, configuration write, source/evidence edit, installation, type/test/build/Forge execution, collector/oracle/secret/network replay, or phase29 retry occurred.

The original commit invocation receipt explicitly lacks separately captured stderr, and its serialized command omits `--no-pager`; these archival limits are not silently repaired or treated as a fresh compliant invocation. Its actual commit object, path set, trailer, source identities, and immutable whitespace were independently checked. Original signature verification was reported good with unknown ownertrust; this audit binds the original signed object but did not rerun GPG or establish new trust. Credential absence is the sealed prior scan, not a new secret scan.

Original cleanup records authenticate actual stopped exits, producer removal of 84 selected empty fixture directories, and verifier removal of owned read-links/runtime. Current verifier runtime and subject out link are absent. The audit launched only bounded read-only Git processes, all returned; it started no service, test, collector, oracle, background child, monitor or external operation. No pending audit operation remains. Automatic unavailable LSP is not success.

The row proofs and final boundary capture document the bounded observation interval, not a promise about future concurrent activity or universal preservation of all docs, dependencies, out/cache, refs or historical build pedigree. P1's two missing historical raw artifact versions and broader source/data/current-control/funding/gas limits remain unresolved and separate. No deployment, signing, funding, activation, allocation, held09/gas action, financial/source approval or full-plan acceptance follows this confirmed immutable local delivery.
