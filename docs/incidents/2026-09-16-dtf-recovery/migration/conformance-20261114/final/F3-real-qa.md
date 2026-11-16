# F3 real manual QA

Date: 2026-11-15.
Disposition: **NOT-APPROVE**.
Classification: **known task 10/13 evidence gap; no new product defect established**.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
Plan: `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md`, F3 at lines 601-604 and task 10 at lines 480-503.
Evidence paths below are relative to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/` in that worktree.

## Decision

The saved records do not establish the complete real operator lifecycle required by F3. Task 10's `cli.ts rehearse` invocation was not run. Its absent receipts cannot be replaced by task 11's isolated gas experiments, task 13's passing Foundry cases, synthetic transport tests, or aggregate counts. The existing `[~]` status is an acknowledged incomplete evidence gate, not a newly discovered product defect.

This review inspected existing local records only. It did not implement, delegate, run Forge or Bun commands, invoke the rehearsal, call RPC, send transactions, or create commits. The only writes are this report and the subsequent F3 verdict JSON.

## Task 10: actual records and missing artifacts

`task-10/funding-blocker.json` records a budget of `10000000000000000000000` raw DTF units, zero transactions sent, and no NFT 3 principal consumed for setup. The pinned block is 108944663, hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.

The blocker is provenance and admission, not global token scarcity. Its two covering authority candidates are excluded admitted sources: `0x2e9c1f705ab967c5af59249203d7495bdabb223b` and `0x999dae02d22e5fee1c4508430d5196d31d631009`. The separate `donor-budget-probe.json` contains funded candidates outside the fixed authority bundle; that does not make them admissible rehearsal donors. `task-10/verification/report-r2.md` preserves the same limitation and qualifies the successful bundle export as offline integrity evidence only.

Direct local existence checks found no `task-10/runtime/` or `task-10/rehearsal-location.json`. The plan requires the following records inside the actual timestamped runtime child identified by that location file. None is delivered as a task-10 runtime receipt; the corresponding task-10 root filenames are absent as well:

| Missing artifact | Fact that remains unverified by the required real surface |
| --- | --- |
| `mixed-pricing.json` | Actual mined A configuration recovery after B without resend; retained A and loaded B records through activation; setter lifecycle and stale-load negatives. |
| `same-block-config-a-then-b.json` | Transaction-specific A completion recovery after B overwrites the same key in one canonical block, with ordered logs and no new nonce. |
| `same-recipient-config-b-issuance-a.json` | Current B configuration independently reconciled with immutable A issuance, its original signed domains, principal, funding and clock. |
| `unset-pricing-owner-bond-activation.json` | Genuine paid owner-first purchase, mined-receipt resume and activation with unset pricing and no prepared manifest. |
| `donation-identity-resume.json` | Two distinct donation IDs with identical calldata, separate exact balance deltas and once-only receipt recovery. |
| `nft-three-two-bonds.json` | Authenticated original-wallet surrender, one source custody/consumption transition, two distinct funded bonds, separate component principals/gons and fresh 90-day clocks. |
| `nft-three-rollback.json` | Actual second-bond callback failure with atomic rollback of both bonds, source custody, consumption and supply; a first-bond failure does not prove this. |
| Existing lifecycle/recovery/receipt records in the missing runtime child | Complete source surrender, delayed clocks, ordinary flows and repeated reward-only recovery through the actual operator. |

Also missing is the actual successful rehearsal command/result and its linked signed intents, canonical headers, transaction ordering and captured state for those scenarios. No replacement receipts or guessed timestamped directory are asserted here.

## Task 11: real saved receipts, bounded conclusions

Read `signed-envelopes/{transactions,constrained-receipts,operation-gas,cleanup}.json`, `attempt-signed-final/{commands.json,raw.log}`, `gas-negatives.json`, `batch-limits.md`, and task 13's `task-11-reuse-audit.json`. The accepting command records exit 0. Cleanup records the local node exited on port 18561.

The transaction file contains 299 signed transaction records. The measured files contain four construction receipts and 51 operation/recovery samples: 28 independent configuration samples, 18 independent issuance samples and five recovery samples. Local joins of all 55 measured receipts to the transaction file found no mismatches in transaction hash, complete saved receipt, successful status, signed 32,000,000 gas limit, actual gas used, or each log's transaction hash/index and block hash. This is consistency of saved evidence, not a fresh canonical-chain query or independent cryptographic reauthentication of every signed byte.

Concrete construction gas used is 19,746,754 and 29,860,062 for parent `0x2ccdcba076936467420fa5a9f52c0603a2681364`, and 19,595,874 and 29,298,754 for parent `0x11c0b94370d6934edaac28ecabe5626341b3412d`. These establish the recorded construction samples under the stated gas envelope.

The saved transaction calldata selectors were identified using the current allocation target artifact's `methodIdentifiers`. The following are real saved successful receipts, not invented missing task-10 records:

| Surface | Saved transaction and observation | Limit of support |
| --- | --- | --- |
| Setter | `0x8425476636c5a388651f52e2846293760297c6d0669c57a2c44a05ec4be5772e`, block `0x67e5e0a`, and `0x9aba74c4e1ba301091f1b0fb1a1d2b9f1c4a093319aa2d64f4b9659aacfa384b`, block `0x67e5e3a`; both status 1, selector `0x43d1e0cc`, with distinct indexed book values in their saved logs. | Local gas-fixture setters exist. They do not supply task 10's accepted A/B journal histories, pinned getter observations or post-purchase owner lifecycle proof. |
| Configuration | `0x9653b4adc460f964c342f4ec18172de239fe5d7ac4328850e454d84d6d312f2b`, status 1, 543,427 gas, one selected recipient and one original. | A real measured configuration sample, not proof of interrupted CLI recovery, same-block replacement or retained mixed-book state. |
| Issuance | `0x09c337944e774f134e28394caab64d35cff189d34868dea3b6bff6dafd3ebcbd`, status 1, 850,202 gas, one selected recipient and one original. | A real measured issuance sample, not the required B-configuration/A-issuance history with independently authenticated original contexts and bond state. |
| Activation | `0x6408db2d3206508e1f2d3c2df85282351cc4a2fe26a61fc933ee82ea99e656f2`, block `0x67e5e3d`, status 1, selector `0xe9dc9e6d`; saved removal logs include setter, configuration and issuance selectors. | Activation occurred in the gas fixture. Its receipt alone does not prove the required actual operator owner-purchase/resume, unset-pricing branch or complete postactivation state census. |
| Surrender/recovery setup | `batch-limits.md` explicitly qualifies holder transfers, approvals and surrenders as fixture setup. Five measured recovery samples are separate snapshot branches. | Neither setup transactions nor historical branch receipts establish task 10's NFT 3 original-wallet two-bond surrender and second-callback rollback. |

The largest admitted measured axes are 64 recipients with one original for loading, 32 recipients with one original for issuance, and one recipient with 64 originals. They do not admit their Cartesian product or arbitrary batches. `gas-negatives.json` records rejection of 64-recipient issuance before signing/sending with unchanged nonce, rejection of a saved 32,000,001 gas intent, and an actual status-0 underfunded transaction with equal before/after configuration hashes. Those are gas-policy and rollback witnesses, not the missing NFT callback witness.

Recovery receipts were captured on independent local snapshot branches and are not claimed to survive together on one final chain. Task 13's reuse audit qualifies two changed historical source-map entries as outside the helper's reachable modules; its bounded gas reuse does not establish an unchanged entire historical fingerprint or a completed lifecycle.

## Task 13: actual suite outputs

Read the three result manifests and the raw logs, including their final summaries and the operator assertion:

| Existing result | Raw evidence | Observation |
| --- | --- | --- |
| Production build | `hermetic-r2/03.log.command.json` and `results.json` | Recorded exit 0 for `forge build --use solar`; retained warnings are qualified in the task-13 report. |
| Full hermetic | `hermetic-r2/04.log`, final line 64138; `results.json` | 28,641 passed, zero failed/skipped, 2,691 suites, recorded exit 0. |
| Migration forks | `fork/03.log`, final line 5677; `results.json` | 183 passed, zero failed/skipped, 30 suites, recorded exit 0. |
| Operator typecheck | `operator-r2/results.json` | Recorded exit 0. |
| Full operator tests | `operator-r2/04.log`, final summary; `results.json` | 240 passed, one failed, 241 tests across 21 files, exit 1 and `completed:false`. |

The failing test is `claimed-sy-witness.test.ts:92`: actual compiled code hash `0x33a0fe038a5d441aa3d9fe48b841bcfc0d0f00f0b085e44b9c41b9b0a7aab2bc` differs from expected pin `0x4ae06bcb278766df6529bcd60e05453fee6c853f6536b9f18d2a4d0dac8fd899`. Task 13's `failure-dispositions.md` already identifies this unresolved authentication gap and its prior task-7 provenance. This F3 pass does not retune the pin, diagnose a new cause or relabel it a new defect.

Task 13's `report.md` and `completion-audit.json` expressly leave acceptance incomplete for the operator failure and absent task 10/12 lifecycle proofs. Passing suite counts support their executed test surfaces only; they cannot close F3's real receipt requirement.

## Evidence bindings and limits

SHA-256 of directly read principal artifacts:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `task-10/funding-blocker.json` | 12503 | `032b72966ee7a584eefe165d863dfc5fd1864a19f0de7810825c34f701d9b5c1` |
| `task-11/signed-envelopes/transactions.json` | 8545084 | `bab31afd8f2b7876defeb3b94f545641bc80de8d47e33660b2cacbef7f8a9392` |
| `task-11/signed-envelopes/constrained-receipts.json` | 386644 | `18ce2d0d12baa398120cc0f1343a5ccca86bc85d0b0d1533e3a905d94da22416` |
| `task-11/signed-envelopes/operation-gas.json` | 1621240 | `0ddd14f703e66937d5a94fa8e71ef2e77a5541921dfd320215738257f47429b8` |
| `task-13/hermetic-r2/results.json` | 1282 | `81de51eff8d5ae17e8126245a752baa1ebdafbb8354c30f0488188f854dcc676` |
| `task-13/fork/results.json` | 1218 | `504602638cfc909263428c3f5417fcecc83e71a5cf2e304bc17ab76f9819ca97` |
| `task-13/operator-r2/results.json` | 1514 | `8fa61a9c225b3a0aec0d18360fe16052d1d6fd38b23e98e9d74ae2158692193b` |

No present public state, complete canonical header chain, missing operator journal, NFT 3 custody state or second-callback trace was independently observed. Approval remains withheld for the known task 10/13 gap. No new product defect is asserted, and this report authorizes no implementation, rehearsal rerun or public action.
