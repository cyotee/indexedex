# Independent F2-02 omission-lane verification

Date: 2026-11-15. Kind: AdversarialVerify. Verdict: **confirmed**.
Failure class: **none**. Confidence: **high** within the scope below.

This confirms the completed F2-02 omission-test repair in renewed task 7, in `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`. It does not certify F2-01, census logic, all of task 7, full operator integration, or contract execution. No required fix was found in this lane.

## Authority and root finding

Read `CLAUDE.md`, `.github/ASSISTANT_RULES.md`, its coding/deployment/testing documents, the plan's owner correction at lines 23-29 and task 7 at lines 445-460, and `final/F2-quality.md` F2-02. The owner correction supersedes the old finding's instruction to preserve the witness pin; this verification neither restores nor certifies that pin.

The original finding is valid: replacing a row with only `original` and `proof` dropped mandatory v2 `pricing`. A boolean `success:false` then passed even after the omitted original field was restored. The cause was stale negative-input construction after the schema contract changed, rather than a demonstrated production acceptance defect.

Actual `scripts/recovery/dtf-migration/schema.ts:91-102,156-160,179-184` requires the original fields and row pricing. Claim-vault, custody-SE and SY originals share the weighted-liquid original schema. `preparation.fixture.ts` constructs complete priced rows and parses the entire preparation input through the production schema. It labels its loopback transport synthetic and does not execute an EVM.

## Repair and preservation

Inspected all four owned files in full. Their omission blocks start at `claim-vault.test.ts:13`, `dtf-custody-se.test.ts:13`, `weighted-liquid.test.ts:13`, and `weighted-sy.test.ts:134`, all under `scripts/recovery/dtf-migration/`.

Each starts with the complete fixture row and a successful full-input control. Destructuring removes exactly one of `originalId`, `originalWallet`, `originalUnits`, `originalEth`, `originalDtf`, `source`, and `evidenceId`. Spreading the row retains pricing, proof and any other row properties. The assertion requires exactly one issue with path `<category>.0.original.<field>`, code `invalid_type`, and message `Required`. An unexpected success explicitly fails. Restoring that field in the same candidate must parse successfully. There are four valid controls and 28 restoration checks across 28 negatives.

This is a real production-parser boundary test, not a mocked validation response. Loosening a required field would cause either unexpected success or a different issue set, failing the repaired assertion. No production schema mutation was performed.

Preservation was checked beyond reviewing a diff: in memory, replacing only each repaired omission block with its HEAD counterpart reproduced all four recorded pre-lane SHA-256 values in `baseline-before.json`. The pre-lane `owned-diff-before.patch` already includes the book-ID ABI and claimed-SY updates. Therefore all bytes outside these four omission blocks remain unchanged from that pre-lane state, including zero-unit/wallet, contributions-known, unknown-credit, fixed-source, unit, overlap, missing-origin, provenance, certificate, complete-component and configuration-hash assertions.

The owned files have 88, 88, 88 and 204 nonblank/noncomment lines, respectively. The existing weighted-SY warning band is not a reason to restructure tests in this verification lane.

## Recorded commands and raw evidence

Accepted the settled focused result without rerunning it:

```text
bun test --timeout 15000 ./scripts/recovery/dtf-migration/claim-vault.test.ts ./scripts/recovery/dtf-migration/dtf-custody-se.test.ts ./scripts/recovery/dtf-migration/weighted-liquid.test.ts ./scripts/recovery/dtf-migration/weighted-sy.test.ts
```

`focused-test.command.json` records the exact argv above, the authorized worktree, Bun 1.4.2 revision 50a8a8387, exit 0, 15 passed and 0 failed. `focused-test.log` names the same four files, contains 15 passing test entries and the matching 15/0 summary. All four current test hashes match that sidecar and the DoneClaim.

The recorded manual argv is:

```text
bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-7/owner-correction-20261115/omissions/manual-omissions.ts
```

`manual-omissions.command.json` records that exact argv, worktree and exit 0. Its seven source hashes match the current four tests, manual script, production schema and actual fixture. Both retained manual logs begin with `status: completed exit_code: 0`; after removing that receipt header and the terminal `MANUAL_PASS`, their JSON bodies exactly match `manual-omissions.json`. The matching sidecars and receipt content bind the output; the child need not print its argv.

Independently checked every manual record, rather than trusting `pass:true`: exactly four successful priced controls with no issues; exactly the ordered four-by-seven category/field pairs; exactly one `invalid_type` / `Required` issue at each intended path; no pricing issue; and all 28 restorations successful. The manual script calls the actual schema and fixture. Its pass predicate checks intended-path presence and restoration, rather than the tests' stricter exact issue set; the saved JSON and the owned tests supply that stronger check. This distinction is not an unmet lane requirement.

`reproduce-before.json` binds its four test hashes to `baseline-before.json`. All 28 old-shape reconstructions report pricing failure, all 28 restored old shapes fail only at pricing, all isolated shapes identify the intended original field, and all complete restorations have no issues. Its `cleanup.fixtureClosed:false` is written before its `finally` closes the fixture; it is not proof of a leaked fixture or a completed-cleanup receipt.

These are schema-validation and synthetic transport results, not real contract execution or financial allocation evidence.

## Adversarial classes and independent probes

| Class | Result and reason |
| --- | --- |
| Stale source/fixture state | All seven manual receipt hashes and all four focused hashes match raw current bytes. In-memory one-byte extensions to each bound source reject its recorded digest. The old pricing-less shape is separately exposed by all 28 retained reproductions. |
| Dirty worktree | Read-only `GIT_MASTER=1 git -C <worktree> status --short`, diff and HEAD reads exited 0. Current status has 185 entries and exactly matches producer `git-status-after.log`; producer before/after logs are identical. This is not a clean-tree claim. Byte-level reconstruction confirms preservation of pre-existing owned-file edits. |
| Malformed input | Audited all 28 recorded single-key omissions against exact expected paths, codes, messages and successful restorations, with the production schema and fixture read in full. No shared integration rerun was needed. |
| Misleading success/output | Six memory-only corruptions retained `pass:true` but were rejected by independent complete evidence checks: pricing-only issue, wrong original field, failed restoration, zero negatives, failed valid control, and an unrelated extra issue. Focused output also has a nonzero actual selected-test count. These are verifier evidence probes, not rerun product tests. |
| Untrusted claims/text | DoneClaim was treated as a source lead; outcomes were checked against sources, receipts and raw output. External prompt-injection scenarios are inapplicable to these synthetic local schema inputs. |
| Generated/cached artifacts | Applicable limitation: the existing fixture reads warm ABI JSON. No freshness claim about compiled runtime or contract behavior is made; no artifacts were built, changed or deleted. Schema and fixture source freshness is bound separately. |
| Concurrent work | Applicable: sibling census edits are excluded from certification. No shared integration checks or census implementation changes were made. |
| Flakiness/order/environment | The changed checks synchronously parse deterministic fixture data; no retry, sleep or clock assertion was added. Existing fixture uses a fresh directory and ephemeral loopback port and closes in `finally`. No repeated-run stability claim is made. |
| Cancellation/resume/repeated interruptions | Inapplicable to the changed synchronous schema assertions; no resumable operator or transaction is invoked by these checks. |
| Hung/long commands | No build, test, server or long-running command was started by this verifier. Retained focused evidence finished in 300 ms under its 15000 ms budget. No timeout recovery claim is needed. |
| Partial output/zero cases | Raw manual bodies match the complete JSON artifact, coverage is exactly 28 distinct pairs, and focused output names 15 actual passes. A retained pass flag with zero negatives is rejected by the independent probe. |
| Resource ownership/cleanup | Inspected actual leftovers and creation/cleanup paths, as detailed below. No foreign resource was deleted. |

## Resource ownership

`cleanup.json` records completed focused/manual processes and says both scripts close their fixtures in `finally`. The source confirms this; the fixture's close method closes the server, removes its environment variable and recursively removes its own generated directory. Producer process exits are retained evidence, not freshly queried session handles.

Actual `os.tmpdir()` is `/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T`, not literally `/tmp`. Exactly these two matching-prefix directories remain:

- `dtf-prepare-test-6ABTvq`
- `dtf-prepare-test-sSyY0e`

Each contains `A-prepared.json`, `A-execution.json`, `A-sources.json`, the corresponding B files, `prepared.json`, `execution.json`, `deployment.json`, `evidence.json`, `checkpoint-7`, and `checkpoint-8`. The omission scripts and preparation fixture do not create A/B or checkpoint files. `execution.fixture.ts:17-28,45-46,101-127` creates this layout using a preparation-fixture root. This supports the producer's foreign execution-fixture ownership explanation; it does not identify the exact live worker or prove its state. Both directories were left untouched. This verifier created no temporary directory or server.

## Limits and disposition

No implementation, test edits, delegation, install, commit, Forge, transaction, full strict TypeScript, or full operator suite was performed. Producer files were preserved. Only the two independent report files and final lane verdict are authored.

Parent remains responsible for full strict TypeScript and the full operator suite after census work finishes. Census/F2-01 and full task 7 remain outside this verdict. No concrete fix is required for the F2-02 lane.
