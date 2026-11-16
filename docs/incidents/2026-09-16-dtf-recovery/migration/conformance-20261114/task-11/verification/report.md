# Independent task 11 verification

Verdict: **needs-fix**. Failure class: **harness**. Date: 2026-11-15.

The measured samples and test counts are supported, but the required command-bearing raw evidence is incomplete for the gas negatives and historical policy. The completion claim does not override these gaps. No product defect is established by this verification.

This review used the task 11 plan and evidence in `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`. Paths below are relative to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-11/` unless stated otherwise. No Forge, bun CLI, RPC, installation, commit, transaction, or delegation was performed. JavaScript cells read and analyzed local files; the only subprocess was read-only Git status.

The untrusted claim is `.omo/ulw-execute/dtf-conformance/task-11-done.json`, 11,316 bytes, SHA-256 `1145910001463fce554ed877b6fd42f1e1b4986b74336eed14c8850b613c3d49`. Its size stayed unchanged, and a subsequent complete byte read matched the initial read.

## Findings

### H1: Negative details are saved outside the command-bearing failure log

Locations: `attempt-signed-final/raw.log:57`; `gas-negatives.json:1`; repository-relative `docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts:210-242`.

The accepting raw log contains exact bun argv at lines 1-2 and `EXIT_CODE 0` at line 65. Boundary rejection is explicit at lines 18 and 46: 64 selected recipients, capped simulation gas 32,000,000, zero signing and sending calls, and unchanged nonce. Those boundary checks pass.

The underfunded and saved-intent details are different. Line 57 logs only the boundary object, failed transaction hash, and saved nonce. It does not log the underfunded signed limit, failed receipt/status, before/after configuration hashes, or the saved intent's 32,000,001 gas limit and validation counters.

The separate `gas-negatives.json` does contain a signed underfunded transaction, status `0x0`, zero receipt logs, and equal state hashes `251b5acb73ab38ce907a18c3051d096d8f546d3742b4d0993d6788a376ff952f`. It also contains the rejected oversized intent and unchanged nonce `0x889`, with zero signing during validation and zero sends. The Anvil log corroborates the failed transaction hash and 987,108 gas used, but has no command or exit receipt. These corroborating files do not satisfy the requested failure-log contract.

A census of all 30 task 11 `.log` files found no occurrence of the rollback state hash, the underfunded raw signed bytes, or `32000001`. This is an evidence packaging failure, not a finding that rollback failed.

Cause: helper lines 236-241 save the detailed negative witness to JSON; line 242 prints a reduced success summary instead of that witness. The audit checks the separate JSON and therefore accepts evidence weaker than this independent verification requires.

Requested repair: preserve the original logs and bind the complete negative witness to exact command/exit evidence through an explicitly provenance-backed supplemental record or a separately authorized fresh capture. Include the failed receipt, signed limit, state hashes, and oversized-intent validation counters. Do not manufacture missing historical stdout or silently rewrite the original log.

### H2: Historical gas policy lacks the required raw command provenance

Locations: `batch-limits.md:3-9`; `signed-envelopes/source-manifest.json:1`; repository-relative `docs/incidents/2026-09-16-dtf-recovery/migration/nft-recovery/implementation/chain-gas-limits.log:1-18`.

The cited historical log records `PIN=4663/108944663`, gas-accounting outputs, `32000000`, and successful labeled exits. It never records the command, RPC method/signature, or called address. Its SHA-256 matches the batch document: `8c6e29f6470180b1f429f737586a6048b121a1200029d3bc9759eb50af04485f`.

The source manifest correctly hashes the historical diagnosis JSON as `4b31c4a85d992dabdba1c97389bde803064520566c5222bf39840490590afacf`. That JSON supplies the block header, alias, call address, and transaction-limit interpretation. The header limit `0x4000000000000` is present there but absent from every task 11 raw log. A hash binds these saved bytes; it does not supply the missing raw command and exit evidence for their origin.

Consequently the policy numbers are internally consistent, but do not meet the user's stricter requirement that every gas number be supported by a raw log containing the exact command and exit code.

Requested repair: recover and bind the original command-bearing policy/header evidence, or obtain it in a separately authorized capture. Preserve the historical block/hash and distinguish it from the permissive local block setting. No new policy is selected by this report.

## Required checks

| Check | Result | Evidence and interpretation |
| --- | --- | --- |
| 1. Artifact-helper gas tests | Pass | `attempt-forge-2/raw.log:1-3` places exact Python argv before helper output. Lines 3859, 3863-3874, and 3878 contain 14 individual passing cases; line 3925 totals 14, with zero failed/skipped; line 3927 records exit 0. Build and test commands contain `--use solar`. |
| 2. Signed envelopes and counts | Pass with branch qualification | `attempt-signed-final/raw.log:1-2,65` binds exact bun argv and exit 0. There are 46 `OPERATION_GAS` records and five `RECOVERY_GAS` records, totaling 51 independently countable samples. Line 63 contains all four construction witnesses. `signed-envelopes/transactions.json` contains 299 actual signed-record entries with receipts, rather than just the claim's count. |
| 3. Boundary, saved intent, rollback | Needs fix | Boundary rejection passes at raw lines 18 and 46. Full saved-intent and rollback witnesses are confined to separate JSON, as detailed in H1. |
| 4. Batch document versus raw evidence | Table passes; policy needs fix | All 51 table rows match raw records by transaction hash, method/stage, selected count, original-array lengths, unrelated population, estimate, signed limit, and actual gas used. Policy provenance fails H2. |
| 5. Pins, public transactions, task 10 | Pass within inspected evidence | Protected source hashes are unchanged. The helper targets an owned loopback Anvil fork; its generation command is a dry run. No public send appears in the inspected execution path. Task 10 lifecycle completion is explicitly disclaimed at `batch-limits.md:97-99` and in the claim. |

The 299 signed records were independently RLP-decoded: all have gas limit 32,000,000 and chain ID 4663. Each recorded transaction/receipt hash agrees with its corresponding fields, and each receipt has status 1. This check did not independently recover signatures or recompute Ethereum transaction hashes.

There are 298 distinct transaction hashes among the 299 records. The duplicate is `0x53abd7d91196c60275282876dee93ce321ffc922e9c9419da9c9d047d8a6d335`, consistent with the disclosed snapshot-branch experiments. The count therefore describes captured signing/mining records, not 299 distinct final-chain transactions. All record hashes are present in the Anvil log; 56 record entries' hashes and six raw signed byte strings occur in the command-bearing accepting stdout log. The full JSON records provide the countable raw transaction evidence.

The four construction rows in accepting raw line 63 match `constrained-receipts.json` exactly, independent of object-key ordering:

| Method | Parent | Owner decoded from transaction calldata | Actual gas used |
| --- | --- | --- | ---: |
| prepareSyChildren | 0x2ccdcba076936467420fa5a9f52c0603a2681364 | 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 | 19,746,754 |
| deployVault | 0x2ccdcba076936467420fa5a9f52c0603a2681364 | 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 | 29,860,062 |
| prepareSyChildren | 0x11c0b94370d6934edaac28ecabe5626341b3412d | 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 | 19,595,874 |
| deployVault | 0x11c0b94370d6934edaac28ecabe5626341b3412d | 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 | 29,298,754 |

Every construction has a 32,000,000 signed envelope and successful receipt. Two-step construction and two distinct owners/parents are supported.

All 51 sample estimates, actual gas values, and 3/2 estimate envelopes fit 32,000,000. The tested axes support loading 64 complete recipient records, issuance of 32 complete recipient records, and one recipient containing 64 complete originals. They do not establish the Cartesian product or arbitrary calldata. The five recovery samples cover one/eight WeightedClaim selections at the disclosed populations and one WeightedUnstake; reverted snapshot receipts are historical experiment records.

Other claimed pass counts also have command-bearing raw support: `attempt-execution-1/raw.log:1-2,6-16,18-22` contains 11 passing operator cases and exit 0; `attempt-recovery-fork-1/raw.log:1-2,3630-3635` contains one passing recovery case and exit 0. Strict TypeScript output has exact argv and exit 0 at `attempt-types-final/raw.log:1-4`. These are inspected prior results, not reruns by this verifier.

## Adversarial assessment and provenance

- **misleading_success_output:** The retained synthetic log `adversarial/misleading-success.log` prints `ALL TESTS PASS` but records exit 7. The verifier did not accept that text or the aggregate audit success marker as a passing command. H1 demonstrates why a successful audit marker alone is insufficient.
- **stale_state:** All files in the accepting signed run's source manifest match their current SHA-256 values. The claim was fully reread unchanged. The saved reference-mutation probe is supported by `probes.ts:36-43`, `adversarial/results.json`, and the command-bearing probe log; it was not rerun.
- **dirty_worktree:** Read-only `GIT_MASTER=1 git -C <worktree> status --short --untracked-files=all` exited 0 and returned 68,481 lines. Nothing was staged, cleaned, or reverted. Against the recorded initial 217-source baseline, 214 files match; only the three permitted existing files differ: `execution.test.ts`, `MigrationDeploymentGasResumedQA.s.sol`, and `verify-bounded-deployments.ts`. Baseline hashes are saved evidence, not an independent proof of pre-baseline authorship.
- **generated_or_cached_artifacts:** The saved probe mutates a copied ABI and checks authenticated-byte rejection (`probes.ts:44-54`). Raw Forge evidence shows unchanged artifact-build roots skipped, followed by two test files compiled with Solar and passing tests. The generation log records its exact Solar script command, dry-run output, and exit 0. Current source fingerprints match the signed-run manifest. These facts qualify cache use; they are not a fresh rebuild by this verifier or a cryptographic proof of every deployed runtime byte.
- **hung/flaky/cancel/interruptions:** Not applicable to this verification because no execution was rerun. The producer's synthetic hung-child experiment is historical evidence only and does not establish behavior under economic-operation interruption.

`execution.ts`, `execution-schema.ts`, `rehearsal-proof.ts`, `claimed-sy-witness.ts`, and `rehearsal-claimed-sy-witness.ts` match both the initial baseline and accepting signed-run source hashes. No witness pin retune was found. The helper uses the existing rehearsal chain with a loopback endpoint; its archive URL is used for fork reads. This is a local-source/evidence conclusion, not a fresh network audit.

Earlier failed signed/type attempts remain recorded and were not counted as accepting executions. The raw Forge log also exposes the pre-existing missing-dependency auto-install attempt; this verifier performed no installation and does not reinterpret that message as successful dependency installation.

## Decisive evidence bindings

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| attempt-forge-2/raw.log | 272118 | ebd8d340f398870f91386b9eb89300bd407730aee09adf8c26f05fd7dc11efab |
| attempt-signed-final/raw.log | 2009879 | 8564769f3fe4ee7641327b0274c706a3d7e06528818a391d84323b5eeb9df641 |
| attempt-execution-1/raw.log | 1585 | 3c6c0e622178b1953fb2ef33f98babb54b37704639996a98d1986cb5574f6565 |
| attempt-recovery-fork-1/raw.log | 251248 | ca99a55781b18b417cd612d7215bfe17cba301a2b0ca14bab1db4178eff6988f |
| gas-negatives.json | 113771 | 37568eb59592305665dbe4bee56f65d11d28ee850b743a70192dcb6d9baa82a8 |
| batch-limits.md | 11725 | 4e985e24085e0a472d3f3b28ac85a79827c6a3ad3b1f5561bbbf38f547c12c9b |
| signed-envelopes/transactions.json | 8545084 | bab31afd8f2b7876defeb3b94f545641bc80de8d47e33660b2cacbef7f8a9392 |

Only this report and the final task 11 verdict are authorized verification outputs. Product files and `task-11-done.json` remain untouched. Task 10 remains incomplete; this report certifies no missing rehearsal lifecycle and authorizes no implementation or public action.
