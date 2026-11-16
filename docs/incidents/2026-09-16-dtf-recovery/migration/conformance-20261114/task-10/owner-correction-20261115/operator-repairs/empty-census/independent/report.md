# Independent empty compensation census review

Narrow verdict: **confirmed**. Failure class: **none in the two-file empty-census repair**. Confidence: **high**. The neighboring prepared range verifier has the concrete advisory blocker A1 below. That is separate from the confirmed unset-owner-bond census repair and does not reopen the settled issuance verdict.

## Findings first: adjacent advisory A1

**P1 - prepared verification still treats authentic deployment initialization as compensation.** Location: scripts/recovery/dtf-migration/execution-state.ts:384-405. The actual verifyConfiguration prepared branch queries the proxy from its original deployment block through latest. Its suffix topic list includes ThresholdsConfigured. The real saved proxy 0xa10fb7436b216df934cfafaca5fddcc7bb9c2902 emitted that event in deployment transaction 0x4098d83a9911e1173fa3a091c227701fd2ff1488f35aa403b902fc3626e9c258, block 0x67e5e5d, log 0x1. Its exact original receipt/header are retained and agree.

This is a range query, not the receipt of a configure call. It therefore reaches the initialization event regardless of whether any valid configure receipt contains it. Decoding the actual source-bound event yields uint256 values 1050000000000000000 and 950000000000000000. The representation predicate at lines 398-404 cannot match it: independent and NFT rows require different event names, while every other admitted originalId is a bytes32 string (schema.ts:8-9,94), strictly unequal to that first bigint argument. With a prepared manifest on this initialized proxy and the actual bound migration ABI, successful canonical deployment-receipt authentication therefore leads to STATE: configured original omitted from complete deployment census. This source/fact implication applies before current row/getter checks.

The public verify and activate commands invoke this prepared range branch at execution.ts:127 and :129. A valid later configure receipt does not remove the earlier initialization log or the deployment lower bound. The unset manifest reviewed here has no preparation and uses the newly repaired empty branch, so A1 does not negate its positive owner-bond preflight. There is no claim that a new real prepared execution or live verify/activate was run here; the advisory is established from the actual range, decoded authentic initialization and exhaustive row predicate, rather than matching text alone.

Advice for separately authorized work: classify actual admitted compensation configuration events in this prepared range branch while preserving the full deployment range, canonical authentication and omitted-origin failures; cover an initialized deployment in a prepared verification regression. No source edit is authorized or performed by this report.

**Receipt-bound lookalike is not a demonstrated defect.** The suffix check in captureAtReceipt's configure branch (execution-state.ts:78-85) is confined to one canonical signed configure transaction, with exact selected method/row/book identity. Mandatory ThresholdsConfigured is emitted by initialization (UniswapV4DetfInitializationLib.sol:86), called by guarded package initAccount (UniswapV4DetfMigrationDFPkg.sol:275-295). That construction path requires factory authority and zero deployed code; it cannot run inside a valid admitted configure transaction on the deployed proxy. The real archived input decodes to package deployVault, rather than a configure method. No speculative cleanup of that receipt check is requested. The prepared range check above lacks this transaction boundary.

## Narrow repair and event coverage

Read the completion claim, blocker, complete domain implementation/test file, producer report/ledger/programs, raw run output and original saved manifest/deployment data. Scope is verifyEmptyCensus in execution-domain.ts and its domain regressions, plus the explicitly requested adjacent advisory. No source file was edited and no settled test or manual replay was rerun.

execution-domain.ts:148-169 authenticates the original deployment before census admission. The new typed mapping covers all ten existing configurationKinds categories from payloads.ts:39-42 and adds IndependentAllocationIssued. It resolves each event through the already source-bound migration ABI; any missing fragment throws DOMAIN before a census range can be considered empty. There is no suffix match, one-event exclusion patch, missing-event fallback, broad exception suppression or policy change in this repair.

| Admitted category | Actual compensation event |
| --- | --- |
| independent | IndependentAllocationConfigured |
| nfts | NftEntitlementConfigured |
| weightedLiquid | WeightedLiquidEntitlementConfigured |
| weightedSy | WeightedSyEntitlementConfigured |
| dtfCustodySe | DtfCustodySeEntitlementConfigured |
| claimVault | ClaimVaultEntitlementConfigured |
| weightedReceipt | WeightedReceiptEntitlementConfigured |
| earlierReceipt | EarlierReceiptEntitlementConfigured |
| earlierLiquid | EarlierLiquidEntitlementConfigured |
| heldSeLp | HeldSeLpEntitlementConfigured |
| issuance | IndependentAllocationIssued |

The actual ABI declares all eleven events. ThresholdsConfigured's topic is 0x9c579265a1eecacb6388cab6eb461dd228c0e87d0e69dfcb16afb0244dbe1622 and is absent from the new list. Alternate NFT contribution and claimed-SY methods retain the existing NftEntitlementConfigured and WeightedSyEntitlementConfigured category identities; no separate admitted category was dropped.

The lower bound remains the authenticated deployment block, the upper bound remains latest, the filter remains the exact proxy, and any one matching compensation event requires exact preparation. verifyDeployment retains its bound receipt/arguments, canonical header/transaction and package/registry identity checks. All original functions outside this narrow selection hunk are unchanged.

## Preserved source and historical boundaries

Reversing only the production hunk and added configurationKinds import in memory reconstructs baseline domain hash fc57cc1f4eb75a5df8f53a36a83d7314922d5acd177c48c5ce563f1b2047ca40. Removing only the added census test import/cases and verifyEmptyCensus import reconstructs test hash 130932ca3a517b4753b3f3e34bdc2df11eca8f11c64429b629abc8eb66881acd. These match the actual before-fix records. The pricing artifact acquisition, stale/rehashed artifact negatives and required bound setter event guard are preserved. No new fallback or old manifest/domain rebinding occurred.

Historical preparation remains cutoff at its pinned preparation block, while current preparation ranges through latest, including when weighted-SY rows are empty (claimed-sy.ts:64,113-129; preparation.ts:254-257). The new repair does not change those paths. The 81 affected tests retain authentic A/current B load/verify/repeated resume, missing X, missing Y, current-empty, original signed-domain authentication and historical source/receipt tampering negatives. They do not cover A1's authentic mandatory initialization in a prepared range; their passing result is not used to dismiss A1.

All 41 original file before/after descriptors match one another and current bytes, including original manifest, deployment receipt, canonical-chain record, both journal domains and source artifacts. Four owned/evidence source fingerprints also match the final claim: all 45 independent hash/size comparisons passed. The owner-bond domain remains be76538efae814c63f22d9c99fd6878734da1e3b76d135df3b3c7fdf02428289. The standalone receipt equals the canonical-chain receipt; header hash/number and transaction membership agree; the original package target and complete encoded deployVault arguments agree with the saved transaction. There are 152 original logs, and the one proxy initialization log equals the blocker bytes.

## Authentic retained commands and results

All commands ran from /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 with Bun 1.4.2. Each attempt retains command, cwd, direct numeric exit, before/after source hashes and raw combined output. All eleven metadata sets agree with the ledger; source hashes are stable within each run. Raw output was read, not inferred from a producer PASS field. Independent verification.json records its hashes/sizes.

| Attempt | Command / change | Observed result |
| --- | --- | --- |
| 01 | bun test --timeout 15000 ./scripts/recovery/dtf-migration/execution-domain.test.ts | Baseline 10 pass, exit 0. |
| 02 | Same focused command, new regressions before fix | 32 pass, initialization positive alone fails with the actual nonempty-census error; exit 1. |
| 03 | Same focused command, repaired selector | 33 pass, 0 fail; exit 0. |
| 04 | Same command; logs.length changed to logs.length > 1 | 22 omission tests fail with missing expected rejection; exit 1. |
| 05 | Same command; lower bound moved to deployment + 1 | All 11 deployment-block omission tests fail; later-offset cases still pass; exit 1. |
| 06 | bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/empty-census/manual-empty-census.ts | 28 expected outcomes; exit 0. |
| 07 | Same manual; omit verifyDeployment | stale deployment header must reject assertion fails because the stale case is admitted; exit 1, no PASS. |
| 08 | Focused command after restoration | 33 pass, 0 fail; exit 0. |
| 09 | bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution.test.ts ./scripts/recovery/dtf-migration/remaining-claimed-sy.test.ts | 81 pass, 0 fail across three files; exit 0. |
| 10 | Final unchanged manual command | 28 expected outcomes; exit 0. |
| 11 | Scoped git status --short followed by git diff --check for the two owned files | Exit 0; empty diff-check output, status preserved separately in terminal-transcript.txt. No verifier Git operation. |

The original producer transcript is /Users/cyotee/.omo/agent/projects/indexedex-5248cf3d3615/senpi-task/children/st_01a1df60/sessions/st_01a1df60/2026-11-15T13-22-51.387Z_92629da0-d73c-43fe-a4f4-d1af12386029.jsonl. Its actual attemptCommand factory captures the direct command exit before hashing/printing and launches monitored commands. All eleven EMPTY_CENSUS_RESULT completion notifications corroborate the ledger, including expected failing mutants. The first cutoff-monitor tool emission at 16:51:12 was followed by an aborted session turn without a tool result; the re-emitted invocation at 16:51:20 has the actual completed monitor and retained run. No second successful test run is inferred from that incomplete tool emission.

The exact singleton, cutoff and removed-deployment-call edits were independently reconstructed in memory and reproduce their recorded mutant source hashes. Restored domain hash 0fdf11cbaa19577c61f70cf31f0115f524ba9cdcb6ff00ade3e18e52ef454af5 matches the first green and final passing runs. Final test hash is 378cd2a690cf5fea6ae0b9da8a617ddede4b85df368ac93de5d5df78c2209b5a. No mutation survives in product source.

## Manual proof and sensitivity

The final manual evidence is manual-qStpyA. It invokes the actual owner-bond preflightOperation on the exact loaded unset manifest. This is real operator code over explicitly synthetic isolated HTTP transport; it is not execution, signing, transaction simulation or a live chain census. The canonical deployment transport replays the exact saved transaction/header/receipt; range responses contain only those saved logs and clearly synthetic omission probes.

Its 28 outcomes comprise three accepted empty preflights (initial, repeated and restored), 22 rejected singleton compensation events (all eleven events at deployment and deployment + 7), malformed census RPC rejection, stale deployment-header rejection and missing issuance event ABI rejection. The hard-coded independent event-case table is not imported from the product mapping. Fixture transport applies address, topic AND block bounds to the rows, instead of returning emptiness on an unrecognized query string. The singleton and cutoff mutants therefore test real detection and range sensitivity, rather than assert a copied mapping or reject every input accidentally.

The recorded 136 transport requests are 28 receipt requests, 28 block requests, 53 log requests and 27 transaction requests. All 26 range queries use the exact original proxy, deployment block through latest and the eleven required topics. There are zero eth_call, eth_getTransactionCount or eth_sendRawTransaction requests. The missing-event case directly removes the issuance fragment from an otherwise valid loaded Interface; identical fail-closed resolution applies to every mapped fragment. Full artifact removal/rebinding is not claimed as a new separate manual probe.

## Limits, diagnostics and cleanup

No defect found in the narrow two-file repair. A1 is a concrete adjacent source/fact advisory for separately authorized work; it is not an extension of the producer's execution claim or a source edit. The issuance verdict stands for its original narrow scope and was not rewritten or reviewed again.

Native LSP freshness timed out in the producer lane; this is not a clean diagnostics claim. JSON Biome is absent and will not be installed. Full current operator suite and both strict tsc commands belong to st_01a1df7f's separate issuance-census-integration claim; they were neither run nor accepted here. No combined gate, readiness marker, fresh owner-bond success, activation or task-10 closure is established.

All three manual runs, including the failed mutant, retain cleanup receipts. Their temporary fixture roots are absent now; providers/listeners were closed and the original RPC alias restored after construction. The helper starts the existing fixture on an isolated listener and closes it in finally. No resource was started by this verifier. Regression evidence remains bound to these saved absolute paths; portability to a fresh checkout is unverified, and the original domains were preserved rather than rebound.

UI/browser/accessibility/responsive, throughput/load and public-network economic execution checks are outside this decoder/census evidence review. No source edits, installs, Anvil, Forge, public RPC, delegation, readiness marker, task-10 closure or producer-record modification occurred. Only this report, independent verification.json and the final narrow verdict are written.
