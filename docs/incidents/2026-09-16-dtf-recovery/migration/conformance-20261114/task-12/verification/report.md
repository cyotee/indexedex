# Task 12 independent verification

Verdict: **needs-fix**. Failure class: **harness**. Task 12 is incomplete.

The supported relocation and rejection work is real. The remaining acceptance gaps are the already-known task 10 current-chain portable proof and its real owner-purchase/donation reconciliation. A partial claim cannot confirm plan task 12. No evidence was found that the producer skipped relocation work supported by the available fixture.

Verification date: 2026-11-15. Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`. Acceptance source: task 12 in `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md`.

The untrusted claim `.omo/ulw-execute/dtf-conformance/task-12-done.json` was read completely, then read completely again at the evidence boundary. It remained 8,489 bytes, SHA-256 `1fe73c59140cd288a6b08241a4622765515fa597e329b99dceb0772e78616216`, with `status: partial`, `complete: false`, nine qualified met entries and two unmet entries.

## Acceptance and raw evidence

All task-12-relative evidence paths below are relative to this report's parent directory's parent, `conformance-20261114/task-12/`.

| Obligation | Result and evidence |
| --- | --- |
| Exact happy-QA command and actual outcome | Supported. `final.log:1-4` contains `ARGV=["bun","test","--timeout","15000","./scripts/recovery/dtf-migration/bundle.test.ts","./scripts/recovery/dtf-migration/preparation.test.ts","./scripts/recovery/dtf-migration/execution.test.ts"]`, `EXIT=0`, `SIGNAL=none`, then the Bun runtime banner. `final.log:108-110` records 91 pass, 0 fail, 91 tests across three files in 66.99 seconds. This conclusion uses raw output, recorder source and the producer's exit notification, not a summary JSON alone. |
| Two fresh locations, equal books/inputs, complete bytes | Supported for the explicitly synthetic wire fixture. The happy log names `relocation-mixed/materialized-a/execution.json` and `relocation-mixed/materialized-b/execution.json`, and their separate `location-a`/`location-b` bundles. `portable-integrity.json` archives the original template and 27 raw files, including both books and both input documents, plus 27 comparison rows for each location. Both locations have distinct fresh domain hashes and identical historical facts. |
| Exact B configuration and immutable A issuance | Supported within that fixture. `bundle.test.ts:189-267` compares complete payloads, books and issuance history against the fixture's original accepted facts, rejects new issuance selection and requires no configure operation. It moves owned original files out of reach before materialization. The retained SY uses A, the independent recipient's current configuration uses B, and its issuance history uses A. |
| Original configure/issuance domains and transitive closure | Supported. Independent in-memory SHA-256 checks decoded all 27 archived files and the template, checked sizes and hashes, and recursively checked every reference with active-path cycle detection: no missing reference, bad hash or cycle. This verifier made 1,081 reference visits because it revisited shared subgraphs; the producer's cached walker reports 228. Independently reconstructed `{manifest, preparedHash, payloadHash}` for the four historical contexts equals each archived journal and signed domain hash. A's domain is `45fb6a6734725eb0ef03914033729ba036f734697b1742beb6bfc4787d9d1469`; B's is `94a273c010142759b3f1d642d7cef6a7880cd14ad903ecb76a1f624a76c98771`. Completion intent hashes also agree for the current accepted rows and issuance. |
| Default read-only validation/verification without repricing | Supported by raw passing cases and `bundle.test.ts:269-284`. Both commands run after fixture setup makes potential `previewOriginalCredit` replies undecodable (`mixed-fixture.ts:238-242`). Assertions reject nonce queries, submissions and new checkpoint creation. This is a synthetic transport observation. |
| Required rejection cases and accepted-file preservation | Supported as detailed below. The raw log contains exactly 23 distinct rejection labels, and the final suite has their passing cases. No bundle-equality relaxation was found in the task-owned edits. |
| Allowed task writes and protected files | Supported by local producer action provenance. Only `bundle.test.ts`, `rehearsal-portable.ts`, task-12 evidence and the requested claim were written. `preparation.test.ts`, `execution.test.ts`, `rehearsal-proof.ts` and witness pins were not written by task 12. Shared prior changes remain distinguishable from task authorship. |
| Real portable current-chain proof | Unmet: task 10 did not run the required successful real portable rehearsal. Synthetic signed bytes and supplied wire receipts do not establish it. |
| Real current-owner purchase and donation checkpoint reconciliation | Unmet: task 10's real lifecycle/resume witnesses, including `donation-identity-resume.json`, do not exist for this run. The passing durable-intent tests do not supply these receipts. |

## Rejections

`tamper-rejections.log` contains these 23 labels, once each:

1. `contained-length` (line 1).
2. `contained-traversal` (line 2).
3. `contained-duplicate` (line 14).
4. `contained-missing-reference` (line 15).
5. `contained-extra` (line 16).
6. `contained-data-link` (line 17).
7. `a-book` (line 18).
8. `b-input` (line 19).
9. `a-issuance-intent` (line 20).
10. `receipt` (line 21).
11. `original-execution` (line 22).
12. `original-journal` (line 23).
13. `historical-domainHash-with-rehashed-FileRefs` (line 24).
14. `omitted-old-SY-row` (line 25).
15. `cyclic-reference` (line 26).
16. `copy-active-checkpoint` (line 27).
17. `move-active-checkpoint` (line 28).
18. `relocated-network` (line 29).
19. `relocated-purpose` (line 30).
20. `relocated-facet` (line 31).
21. `relocated-v1` (line 32).
22. `missing-historical-executionManifest` (line 43).
23. `missing-historical-journalDomain` (line 461).

`bundle.test.ts:287-316` flips exactly one byte independently in A's book, B's input, A's issuance intent and the selected completion. The same loop removes original execution/journal bundle membership. It asserts rejection, no published replacement execution, unchanged original target bytes, no nonce query and no submission. Lines 319-346 rebuild surrounding references after forging a historical domain hash and require domain rejection while preserving the original intent. Lines 348-366 prove the omitted old SY fails the complete census. Lines 368-378 test the real reference walker's active-path guard through one valid edge; this is not a fabricated cryptographic self-referencing bundle.

Lines 380-398 copy and move an active signed checkpoint, require the location-reservation rejection and compare original domain/intent bytes afterward. Lines 401-450 cover identity and omitted-field rejection with original evidence preservation and no nonce/submission. Contained-file cases at lines 123-142 only mutate isolated fixture bundles. None of these negative paths replaces an accepted economic row. Fixed offline signing in fixture construction is separate from the rejected action; no rejection case submits a transaction.

## Hashes and stale-state checks

Independently computed raw SHA-256 values match every claim hash:

| File | SHA-256 |
| --- | --- |
| `portable-integrity.json` | `4d00449771af2ba9d6c05b898aa6b0ed641877145158eecb6f439368cfc632bc` |
| `final.log` | `e919860e3d55a7eccc4fb993d8ea450e7e7ec2d8c1e56b0514ca83b1ab7958dd` |
| `tamper-rejections.log` | `e60db2c53dd950e41197a70bf931d8775ef1481a9004bc93ca277036a9362228` |

All ten current source hashes in `final.argv.json` match the files independently read by this verifier, including the protected files and `claimed-sy-witness.ts`. All six archived `out/` artifacts match their current raw bytes. These checks establish evidence-byte consistency, not a fresh compilation or independent runtime attestation.

## Authorship and command provenance

The producer transcript was read as raw JSONL:

`/Users/cyotee/.omo/agent/projects/indexedex-5248cf3d3615/senpi-task/children/st_01a1de29/sessions/st_01a1de29/2026-11-15T07-43-44.702Z_6d5c3bd8-b031-4b61-935d-88cca1a2fd6a.jsonl`

Binding: 2,068,547 bytes, 342 records, SHA-256 `6d4bf6d80d7b8a8a5a2e65667501a7a4ec86e56b681f5bd740e639c7e43db4fe`.

All producer patch paths and process-starting eval calls were inspected. Patches affect exactly the two allowed source files, task-12 evidence and the requested claim. No producer delegation, public transaction command, witness-pin retune, task-10 rehearsal or invented current-chain lifecycle record was found. The final QA starts at transcript line 217; its monitor records `EXIT=0` and watcher exit code 0 at line 248. The raw final log carries the full test count. `run-qa.ts` captures the actual child exit and output, uses exclusive evidence writes and checks source hashes across the run.

Read-only `GIT_MASTER=1 git -C <worktree> status --short --untracked-files=all`, `git diff --stat`, and the focused `git diff --name-only` show substantial shared dirt. In particular, `execution.test.ts` and `preparation.test.ts` differ from HEAD because they were already changed elsewhere in this execution; that is not evidence of task-12 authorship. `rehearsal-proof.ts` has no HEAD diff. The transcript's patch inventory and matching final source hashes support the narrower authorship conclusion. This is local execution provenance, not a global assertion that no other session ever touched those files.

## Missing artifacts and repair feasibility

H1: Missing successful task-10 portable rehearsal runtime, returned `rehearsal-location.json`, and real portable current-chain proof for the required mixed A/B and B-configuration/A-issuance lifecycle.

H2: Missing real owner-purchase/donation lifecycle reconciliation, including `donation-identity-resume.json` and canonical mined intent/completion/resume records demonstrating no repeat send.

Both gaps have the same known upstream harness cause. `task-10/funding-blocker.json` records a 10,000 DTF setup budget, zero eligible covering donors in the fixed authority bundle, and exclusion of the two covering admitted source contracts. It explicitly records a genuinely funded holder in retained task-2 transfer CSV evidence outside the fixed bundle. Therefore the finding is not that no donor exists. The task-10 round-two verdict also explicitly preserves an incomplete lifecycle.

A future repair can transport authenticated retained transfer/holdings evidence through the owning bundle contract without inventing a donor or spending NFT 3. It cannot produce the missing actual receipts merely by repairing JSON, moving files or reusing synthetic wire responses. With the rehearsal forbidden in this assignment, **another repair cannot produce the required proof under the present constraints**. Resolving provenance is a prerequisite; a separately permitted real rehearsal is still necessary. No product change or such rehearsal is authorized by this verification.

## Adversarial disposition and limits

- `misleading_success_output`: checked the exact argv before helper output, actual captured exit, raw 91/0 summary, recorder implementation and producer monitor completion. The fixture's success is never promoted to full task acceptance.
- `stale_state`: complete claim reread retained 8,489 bytes; claim/evidence/source hashes match. Historical domains were reconstructed from archived originals, not today's paths or book.
- `dirty_worktree`: shared dirt observed and preserved; task attribution uses raw producer actions rather than assuming the HEAD diff belongs to task 12.
- `generated_or_cached_artifacts`: archived bytes, all transitive references and current artifact hashes match. Warm ABIs and synthetic wire receipts remain qualified; they cannot replace task 10's current-chain proof.
- `hung/flaky/cancel/interruptions`: not applicable to this verifier because no commands were rerun. No fresh resilience claim is made.

This verifier ran no Bun CLI, Forge, RPC, installation, commit, public transaction or rehearsal, and delegated nothing. Verification used filesystem reads, hashes, JSON decoding and read-only Git commands. No product file or done claim was edited. The only verifier outputs are this report and the final verdict JSON, written last.
