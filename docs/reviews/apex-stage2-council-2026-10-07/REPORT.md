# Stage 2 consolidated report — review-council partial execution

Snapshot reference: last supplied identity in `docs/research/apex-stage2-review/recurrence-20261007/evidence/source-before-build.json`, captured 2026-10-07T20:54:31Z. IndexedEx `5709cb3507a9df72b11ec476d27b79ef88696c3a`. Crane `b35609951b4951a3c107e267e22844a50c4dc043`. Content hash `82e1f83932a7149cacb7269cdcf90001541cc31306f54407e8037a6597eb5c32`. This session did not recompute that hash.

Report state: **PARTIAL_REPORT**. Date: 2026-10-07. Owner launch reference: the request to execute `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`, with Stage-1 acceptance already recorded. Do not re-ask.

This session ran **no builds, tests, forks, simulations, or chain checks**. The continuation text authorizes those runs. This coordinator runtime forbids shell, so that authorization was not used. `evidence/full-build.log` is only `Compiling 1862 files with Solc 0.8.35` and is not a completed build. `evidence/forge-version.txt` reports forge 1.5.1-stable and is not a test pass. Recurrence `ApexRecurrence*` / `*APEX_Recurrence*` tests exist and were not executed.

## 1. Executive summary and actual concurrency

Three of four assigned reviewers returned substantive independent originals. MiniMax's hooks/matrix/Balancer assignment did not return a file after the initial call and one same-session resume. Both calls poll-timed out at 1,800,000 ms. That lane is **UNINSPECTED** in this wave. No reviewer was impersonated. No four-member consensus is claimed.

| Assignment | Agent | Session | Outcome |
| --- | --- | --- | --- |
| A-vaults | review-council-astra | `ses_ee7c3c41effeYQYXPCEIvWJJVS` | Substantive original written. The task return timed out after the file existed. Not a censorship refusal. No resubmission. |
| B-credit | review-council-grok | `ses_ee7c39bfdffe3UuuuiBqYNZZ7f` | Substantive original after one resume of the timed-out first call. |
| C-hooks | review-council-minimax | `ses_ee7c378ebffeUmQNGUktYmxqXU` | Failed. No original. |
| D-detf-release | review-council-kimi | `ses_ee7c34ec4ffeOABWPSUENRQSF2` | Substantive original after one resume of the timed-out first call. |

The first four calls were requested in one coordinator turn with `run_in_background: false`. Background parallelism is denied by this runtime. Overlap is not proven by scheduler events. S2-AC-02 is **not satisfied**.

Cross-review was **not started**. The failure rule stops the round rather than replacing MiniMax or sharing originals after an incomplete roster. Originals were not rewritten.

This is not an audit-submission approval and not `INSPECTION_COMPLETE`.

## 2. Scope, source identity and authority

Write root substitution: `docs/reviews/apex-stage2-council-2026-10-07/`. The plan's `docs/research/` root remains historical. Prior accepted report `docs/research/apex-stage2-review/accepted-20261007/` is a prior-wave claim, not this wave's proof.

Authority used: Stage-2 PRD and plan; readiness PRD OD-08 and REQ-01–REQ-08; `STAGE1_EVIDENCE.md`; current source reads listed in §5. Wings, hook-matrix, and audit-PDF coverage were not completed here. The audit PDF was not read in this session. Kimi reported it unreadable and marked historical allegations `CLAIM_UNVERIFIED`.

## 3. Criterion coverage and missing work

The original 108-ID ledger was **not re-reconciled** in this session. The accepted-wave ledger is not adopted as a current pass. Supplemental rows were not completed.

| Group | This wave | Limit |
| --- | --- | --- |
| C02–C05 four vault identities | Astra original, partial | Not a full R3 closure. Execution `MISSING`. |
| C06–C08 credit, receipt, AMM, staking | Grok original, partial | Aave loop, Lido stake limits, Slipstream money paths not inspected. |
| C09–C11 hooks, matrix, Balancer | **UNINSPECTED** | MiniMax failure. No documentary denominator re-derived. Do not adopt 195/1/7, 165/3/7, or 217. |
| C01 / C12 / C13 / Stage-1 continuity | Kimi original, partial | REQ-04 matrix files not re-read. Audit PDF unread. |

Uninspected source is not an execution gap. Inspected properties with no run remain `INSPECTED` or `PARTIAL` plus execution `MISSING`. Both limits apply.

## 4. Matrix

No current documentary denominator was re-derived. Matrix runtime evidence was not established. `COMPATIBLE` is not an executed pass.

## 5. Findings

Coordinator re-reads are labeled as such. Reviewer-only items are not upgraded by agreement. No exploit procedure is included. No fund-loss amount was measured.

### Confirmed by a coordinator re-read

| ID | Class / severity | Location | What was re-read |
| --- | --- | --- | --- |
| RC-01 | CODE_DEFECT / High on generic inheritors; see dissent | `NativeStandardYieldTarget.sol:34-67`; `ERC4626StandardExchangeCommon.sol:272-291` | Internal-balance redeem self-calls with `pretransferred=false` and does not check initiator bytecode. ERC-4626 false-flag burn uses `msg.sender`, which is the vault after that self-call. |
| RC-02 | CODE_DEFECT / High | `CamelotV2StandardExchangeOutTarget.sol:748-764` | Zap-out share burn does not compare `amountIn` to `maxAmountIn` before `_secureSelfBurn` on the false-pretransfer path. |
| RC-03 | CODE_DEFECT / High, plus a launch decision | `UniswapV3StandardExchangeCommon.sol:855-871`; `Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol:56` | True-flag credit uses stored reserve minus live deployed. Current Robinhood testnet stage still calls `deployUniswapV3StandardExchangeDFPkg`. Product README says these preserved trees are not deprecated. |
| RC-04 | CODE_DEFECT / Medium | V3 FullSpread Common `:253-279` and `:500-525`; Crane `UniswapV3Quoter.sol:141-158` | Quote returns only `amountIn`. Quoter sets `fullyFilled` and can return a partial `amountOut`. Execute path checks input against the maximum and does not check output fulfillment in the re-read function. |
| RC-05 | CODE_DEFECT / Medium | `RocketPoolRETHStandardExchangeCommon.sol:445-459,500-515` | A sub-minimum booked stake returns without depositing. The second stake offers `liquid - target`, which still includes that skipped book. |
| RC-06 | DECISION_NEEDED / Medium, possible `STAGE1_OPEN` REQ-01 | `UniswapV4DetfCommon.sol:634-654` | Supported inverse branch books when `amount_` is below `quoteInputForExactShares(state_, 1)` without calling `previewExchangeIn`. OD-08 says book-and-wait applies only to a successful preview of `0`. |
| RC-07 | EVIDENCE_GAP / Medium, possible `STAGE1_OPEN` REQ-08 | `scripts/r12_selector_size_compare.py:36-63` | Discovery globs only the parent directory of live baseline rows and is not recursive. Nested replacement package directories are outside that mechanism unless a live baseline row already uses that parent. |

### Reviewer-supported, not coordinator-re-read

These stay out of the remediation requirements until a follow-up re-reads them. They are not refuted.

- Astra-AV-03: V3 native SY wallet redemption routed through the contract-only push gate. V3 only.
- Astra-AV-04: exact-output funding diagnostic can precede `EOAPretransferNotAllowed`. Low. Not an authorization bypass.
- Astra-AV-05 / AV-06: Wings bare `expectRevert` and invariant handlers that swallow failures.
- Grok G-B-03: EtherFi R14.4 exact allocation not pinned by non-drift tests. No arithmetic defect claimed.
- Grok G-B-04: R5.3 acceptance cites a generic receipt suite.
- Grok G-B-05: non-drift receipt tests omit R14.17/R14.18 operations. REQ-06 double-floor reported absent in current target; coordinator did not re-read that target.
- Grok G-B-08: Morpho `maxRedeem` may advertise less than a payable full balance. Informational decision. No loss claimed.
- Kimi K3-D-03: Stage-1 named passes are narrative, `INCOMPLETE_PROVENANCE`.
- Kimi K3-D-04: one R14.7 withdrawal/preview assertion not found. Low. Executor correctness not claimed.

Astra and Grok both support RC-01's missing gate. They disagree on impact breadth. See §8.

## 6. Audit-item mapping and residuals

Not completed. Kimi marked all seven entries and both retractions `CLAIM_UNVERIFIED` because the PDF was unreadable. That is the correct status for this session. Current-source notes in Kimi's original are inspection notes, not historical-claim proof.

Accepted residuals, including D12, were not re-litigated. RC-01 does not treat D12 as a waiver of an applicable initiating-caller bytecode gate.

## 7. Evidence limitations and readiness

Every code conclusion above has execution evidence **MISSING** / supplied outcome **UNKNOWN**. Missing execution blocks a runtime closure claim. It does not by itself create the code defects; the defects are source contradictions.

Stage-1 contradictions retained under original IDs:

- REQ-01 / RC-06: possible `STAGE1_OPEN`. Not renamed as a new discovery.
- REQ-08 / RC-07: possible `STAGE1_OPEN` on evidence scope. Not a claim that a facet is oversized.

No source-drift hash was recomputed after the supplied capture. Recurrence tests are known drift relative to the accepted inspection snapshot. Conclusions apply to the tree read in this session, not to a certified immutable archive.

## 8. Attribution, corrections, dissent

No cross-review occurred. Originals:

- `reviewers/astra-vaults-original.md`
- `reviewers/grok-credit-original.md`
- `reviewers/kimi-detf-release-original.md`

Unresolved dissent on RC-01 severity and reach:

- Astra: Medium. FullSpread and Wings select vault-held shares. This does not burn an arbitrary third-party wallet. D12 limits a universal-theft reading. The missing D9 gate still blocks that acceptance claim.
- Grok: High for families that inherit the adapter and burn `msg.sender` after the self-call. Custody SY has the guard and is not the same defect. Coordinator re-read confirms the ERC-4626 false-flag burn uses `msg.sender`.
- Coordinator disposition: keep both. The shared adapter lacks the gate. Generic inheritors that burn the post-call `msg.sender` are the higher-impact consumers. FullSpread's self-held path is a narrower manifestation, not a refutation.

Grok rated Camelot High. The accepted prior wave rated the same branch Medium. Coordinator keeps High for the authorization failure on the caller's own shares, and records the prior Medium as unresolved severity dissent. No third-party share burn was shown.

Kimi classifies RC-06 as `DECISION_NEEDED` rather than a definite code defect, because NatSpec describes inverse retention as intentional and a consistent quote may imply a zero preview. Coordinator agrees the code conflicts with OD-08's exclusive signal and that an owner amendment could ratify the alternate signal. Until that amendment, the locked rule is contradicted.

## 9. Acceptance assessment

| ID | Result | Why |
| --- | --- | --- |
| S2-AC-01 | Satisfied as a recorded gate | Stage-1 acceptance and launch are in the plan, PRD, and `STAGE1_EVIDENCE.md`. |
| S2-AC-02 | Unmet | Background concurrency denied. One roster member failed. No evidenced complete overlapping review. |
| S2-AC-03 | Partial | Supplied identity recorded. Not recomputed. Drift not closed. |
| S2-AC-04 | Unmet | 108-ID ledger not re-reconciled. |
| S2-AC-05 | Unmet | Supplements not fully inspected. |
| S2-AC-06 | Partial | Four vault identities separated in Astra's original. Not execution-closed. |
| S2-AC-07 | Unmet | C09–C11 unread this wave. |
| S2-AC-08 | Unmet | Audit PDF unread. Claims unverified. |
| S2-AC-09 | Unmet | No current matrix denominator. |
| S2-AC-10 | Partial | Some assertion gaps cited. Catalog not fully applied. |
| S2-AC-11 | Partial | Confirmed findings have citations. Corroboration is incomplete. |
| S2-AC-12 | Unmet | Originals preserved. Cross-review not performed. |
| S2-AC-13 | Partial | Code defects, decisions, and missing execution are separated for the confirmed set only. |
| S2-AC-14 | Partial | This report does not claim ledger totals it did not build. |
| S2-AC-15 | Met for this session's actions | No production/test/config edit and no execution by this session. Continuation text would have allowed execution in a different runtime. |
| S2-AC-16 | Conflict | The plan forbids an automatic remediation PRD. The review-council role requires a DRAFT handoff. That file does not authorize a fix. Owner checkpoint still applies. |

## 10. Owner checkpoint

1. Is this partial coverage enough, or is another inspection required for the unread hook, matrix, and Balancer lane and the unre-read reviewer-only items?
2. Which evidence gaps need a separately authorized verification session? This session could not run Forge.
3. Which confirmed items in `REMEDIATION_PRD.md` should be implemented later? Writing that PRD does not authorize the fix.
4. Which policy questions need rulings: OD-08 versus the supported-inverse quote signal; whether current launch scripts may keep constructing legacy Uniswap V3 Standard Exchange; Morpho `maxRedeem` alignment, if the owner wants it in scope.

**Stop.** No implementation, deployment, or further review wave is authorized by this report.

Implementation handoff: **none authorized or performed**.
