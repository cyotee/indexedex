# Independent issuance decoder repair verification

Verdict: **confirmed**. Failure class: **none**. Confidence: **high for the narrow decoder repair**.

Scope: execution-state.ts and execution-state.test.ts, specifically transaction-local independent issuance child-event selection and validation. This verdict excludes the sibling execution-domain census repair, any changed combined operator/type gate, fresh Anvil success and task-10 lifecycle acceptance. No settled test or manual replay was rerun by this verifier.

## Actual reproduced cause

Read operator-issuance-event-blocker.json, issuance-repair-done.json, the producer report, all evidence programs, raw before/after output and exact run records. Existing repository rules and the scoped task-10 context remain applicable; this review makes no policy or product change.

The saved actual attempt-41 transaction is 0xa41931626451a9242220fcb3c253b9275e8d697beb1a7fd860afcc6fd2ebdc68, status 0x1, block hash 0xcd7a32d10749d878890d870619fa139a79d8ab5f063b51e50eea40604c1e37a0. At log 0xa, the bond child 0xebb22b8619265b4a587a72eaa2b438b0f0c0bc50 emits a four-topic ERC721 Transfer with empty data, receiver 0x0e9971c0005d91336c1441b8f03c1c4fe5fb4584 and token ID 3. At log 0xc, the same child emits MigrationPositionCreated for that ID/receiver, principal 736, start 1794111266 and unlock 1801887266. The real staking child's Staked is earlier at log 0x8, and parent issuance follows at log 0xe.

The generated bond ABI declares Transfer's tokenId indexed, while the generated staking/ERC20 shape puts amount in data. The old fundingAbi included ERC20 Transfer and passed every bond-child log to parseLog. Its shared Transfer signature therefore selected the wrong layout and tried to read a missing data word. The retained real diagnostic and state-before regression show the same BUFFER_OVERRUN, rather than an unsuccessful issuance or missing position event.

The saved signed transaction hashes to the recorded receipt transaction. Its immutable journal hashes to d94078f655dd1888faf7c5a47c2f18978ce61b2e13ae435475ca1af182fa88cf, matching the intent domain. Header hash and transaction membership agree. These are read-only evidence calculations, not a new transaction or a rerun of production verification.

## Repair mechanism and same-cause coverage

execution-state.ts:179-190 selects each required child event by exact emitter AND fragment topic before decodeEventLog. The unused Transfer fragment is removed. Both affected scans use this selector: bond MigrationPositionCreated and staking Staked (lines 191-192). ERC721 Transfer, staking ERC20 Transfer and BondPurchased can coexist without being decoded as a different proof.

A matching required event is always decoded; there is no catch, fallback or suppression that can hide malformed input. It must re-encode to identical topics/data. Lines 196-205 require exact required-event counts in signed-request order; creation ID, receiver, principal, start/cliff, staking payer/recipient, amount and gons must agree with the original request and receipt-block getters. The staking log must precede creation, which must precede its parent issuance log. Parent event selection at lines 143-144 supplies its canonical log position.

The actual NFT Transfer is a coexisting incidental log, not a substitute required-event proof. Receiver and ID authority remain the required creation event, issuance record and ownerOf/positionOf/isMigrationPosition checks. This repair does not add a requirement to decode or validate every unrelated token event.

All other decoder sites in the owned file were inspected: the proxy-only bound-interface decoder at line 58 and configured-topic census decoder at line 395 are unchanged. There is no additional broad child-log scan. The separate ThresholdsConfigured classification question is outside this verdict and remains with the domain owner.

In-memory reversal of only the issuance changes reconstructs the exact previously reviewed state hash 58881534f693274494b8cdb4e87027208fe409024fbc9d228dd0d0f54f80ae67. Removing only the new issuance import/tests reconstructs test hash d8834a16ed91152100a700b529bc0a52f9a04e7ef3a06017171031b6bc8ac6fe. Thus the source-bound setter guards, strict pricing encoding, proxy unknown-event policy, canonical signed transaction checks and unrelated owned-file behavior were preserved. execution-rpc.ts, rehearsal-data.ts and execution.ts also match their prior combined-gate hashes. No new source-binding policy or historical fallback was introduced.

## Retained runs and authenticity

All runs used cwd /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1, Bun 1.4.2. Each command's raw streams, numerical exit and run-time state/test hashes were independently compared with evidence.json. All 23 source/output/history/protected-source hashes matched, as did recorded sizes wherever supplied. Current final state/test hashes equal the passing run's hashes.

| Run | Exact command | Exit and interpretation |
| --- | --- | --- |
| state-before | bun test --timeout 15000 ./scripts/recovery/dtf-migration/execution-state.test.ts | 1; new valid-issuance regression fails BUFFER_OVERRUN, existing 8 state tests pass. |
| manual-before | bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/issuance/manual-issuance.ts --before | 0; asserts the expected production parser failure. It is NOT accepted issuance. |
| state-after | bun test --timeout 15000 ./scripts/recovery/dtf-migration/execution-state.test.ts | 0; 10 top-level state tests pass, zero failures. Nested corruption cases are not counted as 25 extra top-level passes. |
| manual-after | bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/issuance/manual-issuance.ts | 0; new synthetic production completion accepts, all 25 event corruptions reject, status-0 and stale principal reject. |
| test-audit | bun /Users/cyotee/.omo/binary-runtime/5.1.70/plugin/skills/programming/scripts/typescript/check-test-junk.ts ./scripts/recovery/dtf-migration/execution-state.test.ts | 0; no junk findings. |
| dirty-worktree | env GIT_MASTER=1 git status --short | 0; 193 existing dirty rows retained; no broad diff attribution or cleanup. |

The producer transcript is /Users/cyotee/.omo/agent/projects/indexedex-5248cf3d3615/senpi-task/children/st_01a1dfd7/sessions/st_01a1dfd7/2026-11-15T15-33-41.800Z_2a7ced55-b940-4cb0-a4be-9663cc148cb5.jsonl. Actual invocation records eb53cb11, a29059f4, d38733b1 and 209af0d0 bind before-state test/manual and after-state test/manual commands. The runEvidence factory redirects raw output, captures the direct command exit before printf, records actual source hashes and launches one monitor. Completion notifications 01955c68, d62b248c, c51cbb0a and 53582fbf independently report exits 1, 0, 0 and 0. Audit/status have their own completed monitors. This is stronger than accepting producer-written success text or exit sidecars alone.

## Negative sensitivity

The 25 independent copies cover missing position event, empty position data, missing indexed topic, duplicate, wrong emitter/signature/ID/receiver/principal/start/cliff, extra topic/data; missing staking event, empty staking data, duplicate, wrong emitter/payer/recipient/amount/gons, extra topic/data; and both forbidden relative orderings. Their names and raw rejections are retained in verification.json.

Each mutation starts from the accepting synthetic receipt. It supplies the same mutated full log set to the canonical fixture transport and reindexes logs contiguously. Missing, duplicate and reordered cases therefore do not merely fail because of stale log indices or an inconsistent eth_getLogs response: they exercise required-event count/content/relative-order checks. Wrong fields remain ABI-valid inputs, so getters and expected request values form the independent comparison. Extra topics/data target exact re-encoding rather than relying on a permissive decoder. There is no test-only production seam.

The existing canonical identity path separately rejects altered log transactionHash; status 0 cannot be rescued by valid-looking events; stale principal cannot be rescued by matching event presence. The original positive before-fix failure demonstrates sensitivity to the actual decoder defect. No separate per-guard mutation campaign is claimed; these are independently corrupted receipt inputs, not 25 production-code mutants.

## Historical and synthetic boundaries

The original canonical receipt file, diagnostic, journal domain and intent all match their before/after SHA-256 values: 1e05a886203d090dfa235589da6a98c5c130b5e00afc7be5d9c636b80eabebd9, 31f09da7ed01fa1cf0c4985eb1bfbe53d80f55ce57b10d3479f9339d9372091e, fe236c0897e683f89f0ea0df18512febc5a42c9c4a6400adea2584f11c675ba2 and b3354bb973d2431e25f4991ce394239786ef80ce8512c67116689790295da705 respectively. No old domain was rebound.

The saved real channel authenticates receipt/event facts and diagnoses the collision. It lacks the complete saved post-issuance getter answers needed for full historical captureCompletion; neither producer nor this verifier claims that completion passed. Manual-before exit 0 proves an expected failure assertion passed.

The accepted context is explicitly new and synthetic: transaction 0xb5577401fdc6f2f38bef13e2da0b124530873b99d0b6e35e0088f1b5bb91c85e, domain a9edd6e9c075cd47422d5c8feb93de461fe855676503fde6020e7b107767c57f, synthetic addresses, principal 9007199254740993133 and synthetic getter replies. Its event encodings come from generated bond/staking artifacts bound in the new fixture manifest. All retained non-temporary artifact hashes/sizes match. Production retains its existing funding event Interface; this review does not misstate those fixture bindings as a new production artifact loader. Temporary fixture files were intentionally removed, not retained as a portable signed-history proof.

## Limits and cleanup

No concrete in-scope defect found. Fixes: none. The local selector has two callers, reuses existing Interface behavior and introduces no exception suppression, type escape, retry, fallback, logger or authority. The large state/test files already exceed generic size guidance; the explicit two-file repair scope does not authorize a structural rewrite.

Applicable stale-data, malformed-input, misleading-success, dirty-tree, canonical-identity and cleanup classes are covered as described. UI/browser/accessibility/responsive and load/throughput are inapplicable to this offline decoder repair. Public-network, wallet authorization, deployment, restart, reorg/chain rollback and real economic lifecycle are not exercised and are not waived for task 10.

All six retained monitors exited. Fixture cleanup closes providers/server and removes temporary roots; the manual-after temporary source path is now absent. No resource was started by this verifier. Production/manual LSP results were clean; test/fixture freshness timeouts are not clean typechecks. The earlier 280-test combined gate is invalidated for this changed tree, and no shared suite or strict tsc command was run here. The census sibling, subsequent combined QA and fresh Anvil/task-10 lifecycle require separate verdicts. No source edit, install, Forge, RPC, transaction, delegation, readiness marker, task closure or old evidence modification occurred.
