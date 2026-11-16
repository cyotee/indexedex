# Task 10 independent blocked-claim verification

Date: 2026-11-15. Verdict: **needs-fix**. Failure class: **harness**.

The missing donor fixture is real within the exported authority bundle and matches the plan's prescribed stop. The producer correctly left the rehearsal unrun. However, the requested command evidence is incomplete: `bundle-export.log` contains the exact argv and successful offline-integrity output, but does **not** contain exit 0. The actual exit 0 is independently corroborated in the producer transcript. That corroboration does not satisfy the explicit requirement that the log itself contain it. No product defect or skipped eligible covering donor was established.

## Finding H1: export exit status is outside the required log

Location: `task-10/bundle-export.log:1-2`, relative to the conformance evidence directory.

The entire 703-byte log consists of the `bun ... cli.ts bundle-export --input .../authorities-input.json --output .../authorities-bundle` command and the JSON result with `"mode":"offline-integrity-only"`. There is no exit-status line. Its SHA-256 is `10c171d534be637b2522e26f9a9fe9195f59b40159d2071b4abbf0d420ec24db`.

The producer's command at transcript line 56 redirects only the command group into this log, then prints `BUNDLE_EXPORT_EXIT` outside that redirection. Transcript line 68 records `BUNDLE_EXPORT_EXIT=0` and watcher exit code 0. Thus this is an evidence packaging failure, not a failed export. Repair direction: preserve the original bytes and bind the observed process-exit receipt into the required command evidence with explicit provenance. Do not invent an exit status, present export as lifecycle success, or run the rehearsal merely to repair this record. No repair was performed by this verifier.

## Evidence bindings and method

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

Claim: `.omo/ulw-execute/dtf-conformance/task-10-done.json`, 10558 bytes, SHA-256 `f170f66b0bfb520ed0a38a2f9ee06636291182503159c854f0682ca8d42e7586`. Its final complete read was byte-identical to the initial read; its size did not change.

Plan: `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md`, 126320 bytes, SHA-256 `fb1b8bca1b0e569334bfa8327bda865c3d60c7e61a304513e9b2f8f64aefd3df`. Task 10 is at lines 480-503. Line 486 requires candidates from existing authority-bundle transfer/holdings evidence, exclusion of admitted sources, compensation wallets and recovery custody, and a pinned balance covering 10000 DTF. It expressly requires reporting missing fixture acquisition if none covers the budget, rather than consuming NFT 3 or fabricating balances.

Producer transcript: `/Users/cyotee/.omo/agent/projects/indexedex-5248cf3d3615/senpi-task/children/st_01a1dde5/sessions/st_01a1dde5/2026-11-15T06-29-13.694Z_17f3b054-fb85-421b-9cc6-eff6ab4860c8.jsonl`, 1749872 bytes, SHA-256 `d0b4a0f02e7cb8c0beaca939b5b06e4f557bc14cde45c92930b445f89ace3dc9`. Parsed all 233 records and inspected all 48 top-level tool calls, including embedded commands and patches. This is local provenance corroboration, not an external chain attestation.

Verification used local raw-file reads, SHA-256 computations, JSON/CSV comparisons, source inspection, and read-only Git status, branch and scoped diff-stat commands. No producer script was executed. No Forge, RPC, rehearsal, install, commit, delegation or transaction was performed.

## Donor search and authority completeness

All 22 source roles match `scripts/recovery/dtf-migration/bundle.ts:11-25`. All 22 exported source items match their declared sizes and hashes and their original source bytes. The template is byte-identical to `authorities-input.json`, 12705 bytes, SHA-256 `2601b5c3fa6b349984e42730ee5d380221e5541f7234212fb8bf3c4fe0a7ab8c`. The data directory contains exactly the 23 declared content files, including the template. Bundle manifest: 10246 bytes, SHA-256 `4ab93713b6aafd43d674a7b605252f938c4e70cf638a1ed89bf33b4fc5f1dac0`.

All 16 artifacts fingerprinted by the claim match their current raw sizes and hashes. The probe contains precisely the sorted union of 282 retained-transfer candidates and the producer's 60 authority-document addresses: 337 unique rows. Each returned hex balance decodes to its recorded decimal balance, and each covering flag agrees with the exact budget `10000000000000000000000`. The successful probe log and saved covering rows agree after ignoring JSON object key order.

The saved pin is block 108944663 (`0x67e5d17`), hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`. Token is historical DTF `0xee5576fa1bcaa380e591d01245f406f3f384eb01`, with the probe's 18-decimal setup units.

Only two of the 60 authority candidates cover the budget:

| Address | Saved raw DTF balance | Required exclusion |
| --- | ---: | --- |
| `0x2e9c1f705ab967c5af59249203d7495bdabb223b` | 16226464590164018429679811 | Admitted custody source, `payloads.ts:12` |
| `0x999dae02d22e5fee1c4508430d5196d31d631009` | 48199379819584937212078 | Admitted W-SW source, bundled `held-se-lp-source-contract:8` |

After excluding those two, the largest remaining saved balance is only `118850873190003046246`, at `0xb7d4bb379d361ad442cddee53ea71a33957826a7`, itself another source. Further compensation/custody exclusions cannot create a covering donor. The NFT 3 holder `0x72bea6fa3e68ef18c87d045aac7c4aa5249d933b` holds only `37105386057342850836` raw DTF.

An independent scan of all 22 raw authority files found 64 complete address literals. The four omitted from the producer's 60-address superset occur only in the source archive: Ethereum-mainnet WETH9, canonical Permit2, the ETH mover, and the archive's own deployed-contract address. Their occurrences are library constants or deployment metadata, not DTF transfer/holdings witnesses. They do not establish a skipped donor within the plan's allowed search. Hex prefixes inside bytecode and 32-byte hashes were not treated as holder addresses. The bound donor descriptions in the admission documents concern personal WE or SY weights, not a 10000-DTF balance.

The separately retained `transfers.csv` has 4535122 bytes and SHA-256 `c840d060c5c7119a1f4777730d726fc0e0390e87ed3190ea0b4b841e99417939`. Recomputed 2522 DTF transfer rows and exactly the 282 input candidates. The first sorted covering candidate in that external census is `0x0da0877ab57a89e5db9125069fa8cd3702536e37`, with saved raw balance `1160555124327723708919833`. This address is absent from the authority bundle's holder evidence. The CSV is not a declared bundle item. Therefore the block is transport/provenance, not global DTF scarcity.

The current authority schema fixes the exact 22 roles (`bundle.ts:20-25`); source objects are strict (`schema.ts:202-215`); bundle loading rejects undeclared data and unused references (`bundle-files.ts:105-107,109-129`; `bundle.ts:134-137`). The producer neither added an unreferenced CSV nor substituted an authority document. A follow-up must resolve how genuine donor evidence is bound and transported while preserving those guarantees. This verification does not authorize that extension.

## Custody, execution and dirty worktree

The producer's mutation calls target task-10 evidence and the claim only. Its checkout creation copies local files into `task-10/checkout` and links dependencies/artifacts; it does not alter the source product. The direct and embedded patch calls at transcript lines 54, 102, 104, 118, 134, 136, 142, 206 and 211 all remain within task-10 evidence or the claim. No product-file edit by task 10 was found.

Read-only Git reported branch `work/dtf-conformance-20261115-wave-1`, with 108 tracked dirty entries and extensive untracked evidence/copied checkout files. Existing shared changes from tasks 1-9 are not attributed to task 10 merely because they appear in status. The producer's initial status and complete action audit support that distinction; status alone cannot prove authorship. No dirty files were reverted or modified by this verifier.

The current setup still calls `claimBond("3", ...)` at `rehearse.ts:114-125`, which explains why running it would violate task 10's fixture restriction. The producer did not invoke that command. Its actual executed probe calls only `eth_getBlockByNumber`, `eth_call` and `eth_getCode`; `RehearsalChain.send`, `call` and `close` at `rehearsal-chain.ts:39,43-45,79` add no transactions. The first Anvil log has one block read; the corrected log has one block read, 338 calls and 337 code reads, with no send, storage mutation, impersonation or reset methods. The saved transaction count is zero. There is no task-10 runtime directory, receipt set or rehearsal-location record.

These independent local observations corroborate that task 10 did not consume NFT 3 principal, mint/etch historical DTF, fabricate donor funds or run the rehearsal. No fresh chain state was queried, as requested. The initial import-path and quantity-parsing probe failures were inspected; the corrected probe completion is recorded at producer transcript line 192. Those failures were not hidden as lifecycle success.

## Adversarial checks and limits

| Case | Result |
| --- | --- |
| misleading_success_output | H1 fails the required log packaging. Actual export exit 0 is corroborated at transcript line 68. `"offline-integrity-only"` is never accepted as lifecycle success. |
| stale_state | All claim fingerprints and source/bundle bytes match; final claim read is unchanged. Saved stale-authority log records `PROVENANCE` and `EXIT=1`. No stale success artifact closes task 10. |
| dirty_worktree | Existing shared dirt is preserved. Full producer command/patch audit finds no task-10 product writes. |
| malformed_input | Saved malformed-authority log records `INPUT`, missing 22 roles, and `EXIT=1`. Inspected the strict role/schema checks; did not rerun them. |
| untrusted_external_text | Claim, logs, archive, CSV and transcript were treated as data. No embedded command or instruction was executed. Addresses, counts and hashes were recomputed locally. |
| hung/flaky/cancel/interruptions | Not applicable to the unrun rehearsal. A prior Git pager exit and probe retry are not evidence of lifecycle timeout, cancellation, interruption or fault-recovery handling. |

All mixed-pricing, same-block, same-recipient B/A, unset-pricing activation, donation-resume, NFT 3 two-bond and second-callback rollback obligations remain unverified and blocked. The export proves only offline integrity. The missing donor condition is confirmed, but the overall submitted claim receives **needs-fix / harness** because the explicit exit-status-in-log requirement is unmet. Neither implementation nor an operational donor, allocation, transaction or authority extension is approved here.
