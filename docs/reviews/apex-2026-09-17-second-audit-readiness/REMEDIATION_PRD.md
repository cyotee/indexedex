# Remediation PRD: APEX second-audit readiness

- **Status:** DRAFT
- **Date:** 2026-10-03
- **Review target:** Current working-tree source, tests, and evidence for the APEX 2026-09-17 remediation. The question was whether that work is complete and whether the tests are adequate to submit this source for a second audit.
- **This document does not authorize code changes.** It is a handoff. A later session must be explicitly asked to implement it.

## Required outcome

Do not represent the current tree as a completed, regression-verified implementation of the locked plan. Before that representation:

1. Close or explicitly amend the confirmed deviations below.
2. Replace the cited weak or mis-aimed tests with assertions that match the locked property.
3. Map the current FullSpread V4 implementation set to the submission identity and regenerate source-bound build, selector, size, and regression evidence for that tree.
4. Keep accepted residuals documented. Do not treat them as missing source fixes, and do not treat a prior green count as proof they were re-verified.

A second auditor may still be given the source with these items open. That is not the same as claiming remediation acceptance is complete.

"All possible attacks" is not a finite claim and is not a requirement of this PRD. The threat-model bar is the locked plan, the seven audit findings plus both retractions, and the adversarial catalog classes already named in the IndexedEx and Crane testing skills.

## Inputs used

| Input | Path | Role |
| --- | --- | --- |
| Implementation plan | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` | Locked decisions D1–D69 and acceptance criteria. Claims, not proof. |
| Remediation PRD | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` | Intended behavior, including owner clarifications. |
| Audit report | `docs/audits/APEX-IndexedEx-Audit-2026-09-17.pdf` | Auditor claims. Not independently re-executed in this round. |
| Follow-up record | `docs/audits/apex-2026-09-17-followup-fixes.md` | Later completion claim, dated 2026-09-25. Not re-run. |
| Evidence narrative and directory | `docs/audits/apex-2026-09-17-evidence.md`, `docs/audits/apex-2026-09-17-evidence/` | Historical and later claims. Historical sections are not current failures by themselves. |
| Open-items ledger | `docs/audits/apex-2026-09-17-review-open-items.md` | Later owner rulings. Claims, not proof. |
| Open-item PRDs | `docs/audits/apex-2026-09-17-open-item-1-hook-se-matrix-PRD.md`, `apex-2026-09-17-open-item-3-etherfi-interface-research-PRD.md`, `apex-2026-09-17-open-item-4-legacy-join-facets-removal-PRD.md`, `apex-2026-09-17-open-item-5-buffer-hook-staticcall-exception-PRD.md`, `apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md` | Additional intended behavior. Not all reviewers read every PRD. |
| Router and skills | `CLAUDE.md`; `.claude/skills/indexedex-adversarial-testing/SKILL.md`; `.claude/skills/indexedex-testing/SKILL.md`; Crane adversarial and testing skills | Deploy, testing, and catalog law. |

No forge tests, builds, chain reads, or deployments were run in this round. The follow-up claim of 34,909 passing tests, 33 campaigns, and a 195/1/7 matrix is unverified execution evidence.

Reviewer originals and cross-reviews:

- `docs/reviews/apex-2026-09-17-second-audit-readiness/astra-original.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/astra-cross.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/grok-original.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/grok-cross.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/minimax-original.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/minimax-cross.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/kimi-original.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/kimi-cross.md`

## Astra participation

Astra answered both turns with substantive, file-level reviews. Neither response was censored. The censorship cap was not used.

| Turn | Attempts | Result | Session |
| --- | --- | --- | --- |
| Independent first pass | 1 collected substantive review | The initial task poll timed out with no answer collected. The same session was resumed and returned a substantive review. That resume was a collection continuation, not a censorship rewrite. | `ses_efedbea33ffeiXIiaYN3lpvkJ4` |
| Cross-review | 1 of 3 | Substantive review, same session | `ses_efedbea33ffeiXIiaYN3lpvkJ4` |

Other successful sessions, preserved for follow-up: Grok `ses_efedba981ffe2HHDI7axlM96f6`; MiniMax M3 `ses_efedb685dffeFUZVpB5GMex0Mw`; Kimi K3 `ses_efedb20a4ffe9dgQoPxdM9jLgi`. Their initial polls also timed out; the same sessions were resumed and returned substantive originals before any peer text was shared.

## Agreements

After cross-review, all four reviewers' updated verdict is **not ready** to submit the current tree as completed and regression-verified. MiniMax M3's first-pass verdict of ready-with-documented-residuals was withdrawn in `minimax-cross.md` after re-reading source.

Agreed and coordinator-checked against current source:

- Uni V4 DETF residual helpers still catch dependency failures outside D41, D48, and D49.
- The single-CP residual preview turns one named dependency error into a zero quote.
- The shared receipt adapter can floor a redemption cap twice.
- The standard exchange rate provider has a remaining-gas soft `quoteState` probe that D48 does not authorize.
- Cited custody and matrix tests do not prove the properties their names or acceptance citations claim.
- The cited V3 reserve-reconcile supplement does not create the stale-reserve boundary R3.3 describes.
- Current FullSpread V4 code is not the single Common path named in the September handoff.

Agreed residuals, not source defects:

- Live chain-4663 instances are immutable. Replacement verification is not deployment remediation (D7, R4).
- D12 non-atomic contract pretransfer, including contract wallets and EIP-7702 delegated accounts, is the accepted `UNSUPPORTED_USE` residual.
- Slipstream deprecation (D57) is not a missed rewrite.

`LocalCreditLib` (`available`, `budget`, `requirePretransferCaller`) matches D11 in the file that was read. That positive observation does not close the families that consume it.

## Requirements

### REQ-01 — Remove or explicitly amend Uni V4 DETF residual catches

- **Severity:** Medium
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:572-578`, `:604-610`, `:628-635`, `:642-649`, `:664-685`, `:699-706`, `:718-721`
- **Intended behavior:** D37. Every `try`/`catch` in D16 DETF production source is removed except the D41 and D48 staticcall exceptions, later extended only by the named D49 Balancer buffer-hook probes. The dependency revert propagates. D30 forbids a family-specific recognized-error list on the paths it governs.
- **Broken requirement or invariant:** Current production source still catches self-calls, interface probes, and previews in this D16 DETF file. Some failures return false, defer, translate a zero-output error, or recognize `AlignmentNotAchievable` instead of propagating. These sites are not named by D41, D48, or D49. A scoped search of the evidence narrative did not find an owner exception for them. That search is not proof that no exception exists anywhere else.
- **Impact class:** Error propagation and residual accounting. A failed probe or a recognized alignment error can continue or park residual instead of rolling the operation back. Financial loss was not demonstrated.
- **Acceptance criteria:**
  - Each catch in this file is either removed so the dependency revert propagates unchanged, or covered by a written owner amendment that names the function, the permitted error, and the required retention or rollback behavior with the same specificity as D49.
  - Tests for the chosen disposition assert the exact error or the exact retained residual, and assert that every other dependency revert still propagates and does not pay booked inventory to the caller or the fee recipient.
  - The evidence ledger records the disposition against the current file, not against the baseline `REPORTED` rows in `catch-sites.json`.
- **Non-goals:** Do not treat this as proof of theft. Do not rewrite unrelated DETF economics, vesting, or thresholds. Do not delete historical evidence.

Attributed: Grok finding 1, Kimi F1, Astra cross-review agreement, MiniMax cross-review partial agreement on the recognized-error sites. Coordinator re-read the cited functions on 2026-10-03.

### REQ-02 — Make the single-CP residual preview obey the catch rule or record an exception

- **Severity:** Medium
- **File and line:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:246-257`
- **Intended behavior:** D37 and D30. Hook production catches are removed except the named staticcall exceptions. A recognized-error list that turns one dependency error into a zero quote is not authorized for this function.
- **Broken requirement or invariant:** `previewResidualBuffer` catches `previewExchangeIn` and returns 0 when the reason is `AlignmentNotAchievable`. Other reasons are rethrown. A zero return is not propagation of that error. The operative `exchangeIn` at lines 262-268 remains a hard call.
- **Impact class:** Quote and residual-maintenance divergence. A caller that treats zero as "no shares" can keep the residual locally instead of failing closed. No direct payout was shown from this view alone.
- **Acceptance criteria:**
  - The function propagates the dependency revert, or an explicit amendment names this selector, forbids using the zero result as credit, and states what local retention is allowed.
  - A regression asserts both the retained-local outcome, if that outcome is approved, and that every other revert still surfaces unchanged.
- **Non-goals:** Do not invent a new public sweep. Do not change D6 residual retention on paths that already match it.

Attributed: Grok finding 2, Kimi F2, Astra and MiniMax cross-review agreement. Coordinator re-read lines 246-268.

### REQ-03 — Pin the custody negatives the scanner does not see

- **Severity:** Medium
- **File and line:** `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:38-44` and `:112-124`; `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol:55-85`; `scripts/apex_bare_expectrevert_scan.sh:14-21`; production guard at `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:57-59`
- **Intended behavior:** R2.4. A negative test asserts the precise intended error and unchanged affected state. A test named for an ownership or reentrancy property must reach that property. The scanner must cover the D16 tests used as remediation evidence, not only files that contain an APEX marker.
- **Broken requirement or invariant:** `test_ADV_cannotBurnOtherHolderViaInternalSy` uses bare `vm.expectRevert()` and calls internal-balance redeem as `bob`. The production path checks `requirePretransferCaller` before the burn, so a code-less caller fails the EOA guard and the named ownership check is not reached. The reentrancy test accepts any revert. The exact-out minimality fuzz test accepts any revert and checks only the successful return value. The scanner's fixed roots plus an APEX text filter do not include these custody files.
- **Impact class:** False-positive security coverage. Unrelated reverts can preserve a green result. This does not show that the production EOA guard is missing. `test_ADV02_insufficientSharePretransferReverts` at lines 97-109 is a separate, correctly pinned contract-caller control and does not repair the mis-aimed test.
- **Acceptance criteria:**
  - The ownership test uses an allowed contract caller, expects the precise share-accounting error, and asserts the other holder's shares are unchanged.
  - The reentrancy test expects the nested-guard error and asserts no partial credit.
  - The minimality fuzz test expects the family's exact short-funding error and asserts shares, balances, and reserves are unchanged on rejection and exact on success.
  - The scanner selects the full D16 regression inventory used for R2.4, including custody files that do not contain the APEX marker.
- **Non-goals:** Do not weaken the EOA guard so the old test can pass. Do not replace these tests with broader `expectRevert()`.

Attributed: Astra-01. Grok and Kimi re-checked the adversarial test and the scanner. Coordinator re-read those lines and the SY guard.

### REQ-04 — Stop matrix rounding controls from accepting any revert

- **Severity:** Medium
- **File and line:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol:177-216`, `:236-258`, `:369-383`. The same catch-all shape was located in the dual, orbital, single non-CP, single-CP, Balancer-quad, and curve-quad matrix behaviors.
- **Intended behavior:** R10.3 and R2.4. A rounding or partial-consumption control must show the specified outcome: measured consumption, exact booked remainder, and the precise error when the operation is rejected. A catch of every revert is not that control.
- **Broken requirement or invariant:** `_roundingToZeroControl` catches every revert and passes if two balances are unchanged. Transaction rollback makes those checks true for any revert. The partial-consumption check uses a range rather than measured consumption versus booked remainder. The exact-output SE-share assertion is a strict decrease, not a burn of only the shares used. The AMM separation check does not establish a nonzero unpaired book before comparing an ending lower bound.
- **Impact class:** Overstated matrix coverage. A row can pass a named rounding control without testing rounding. Other controls in the same row may still be meaningful, so the whole matrix is not declared vacuous.
- **Acceptance criteria:**
  - Each of the seven matrix behaviors either expects the family's exact rounding error or asserts a successful measured zero-output and retained-book outcome, including the branch precondition.
  - Partial-consumption tests reconcile actual dependency consumption, credited amount, book change, and exact share movement.
  - D33 tests establish a nonzero unpaired inventory that is not consumed by the later caller's input.
  - A row is not marked COMPATIBLE on the strength of the catch-all control alone.
- **Non-goals:** Do not delete funded swap, refund, or EOA controls that already assert exact deltas. Do not count an INCOMPATIBLE or DEPRECATED row as a passing integration.

Attributed: Astra-02. Grok re-read the weighted behavior and confirmed the catch token in the other six files. Kimi re-read the weighted behavior. MiniMax left the bodies unverified in the first pass and did not refute them.

### REQ-05 — Cite a real stale-reserve control for R3.3

- **Severity:** Medium
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol:58-152`; acceptance citation in `docs/audits/apex-2026-09-17-evidence/acceptance.json` for R3.3
- **Intended behavior:** R3.3. Replacement credit is checked after a partial mismatch, an equality case, and a greater-than case relative to the old stored-total baseline, including a rebalance followed by an independently funded external pool trade that does not refresh the vault book.
- **Broken requirement or invariant:** The cited supplement builds `total` from current local plus deployed reads, checks a dust-bounded sleeve, and then trades through `vault.exchangeIn` before asserting a synchronized book. That is not an independently moved pool state, and it is not the historical stored-total boundary.
- **Impact class:** A completion citation does not prove the criterion. This finding does not reintroduce APEX-2026-001-M. Other FullSpread tests may cover part of R3.3; that map was not completed.
- **Acceptance criteria:**
  - The evidence row for R3.3 names tests that actually create the stale-book boundary on the preserved implementation and that check replacement credit after an external pool action that does not run the vault's synchronization.
  - The current supplement may remain as a custody-synchronization test, but it is not labeled as the stale-total boundary.
- **Non-goals:** Do not edit preserved Uniswap V3/V4 source under `contracts/protocols/dexes/uniswap/{v3,v4}/`. Do not claim a live instance was upgraded.

Attributed: Astra-03. Grok and Kimi re-read the supplement. Coordinator did not re-run it.

### REQ-06 — Do not double-floor a deliverable receipt redemption

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:67-80` and `:162-166`; `contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:54-70`
- **Intended behavior:** D45 and R14. Receipt payout limits must match actual deliverable receipts. An owner whose full share balance has a payable receipt entitlement must not be rejected only because that entitlement was floored and then floored again back into shares.
- **Broken requirement or invariant:** `maxWithdraw` floors the owner's share entitlement to receipt units and caps by held receipts. `maxRedeem` converts that amount back to shares with floor division and then caps by balance. `redeem` rejects shares above that smaller cap. With a non-integral share/receipt ratio, `maxRedeem` can be below the owner's balance even when held receipts cover `previewRedeem` of that balance.
- **Impact class:** Unnecessary redemption rejection and stranded share dust. No theft magnitude was established. No runtime case was executed.
- **Acceptance criteria:**
  - `maxRedeem` returns the full owner balance when that balance's rounded receipt payout is within actual receipt inventory.
  - Otherwise the share cap is computed from the receipt-liquidity inequality with one consistent rounding direction and an owner-balance bound.
  - Both dispatched families have a non-integral-rate test for a full-balance redeem that is deliverable, and a test that still rejects a redeem above actual receipt inventory.
- **Non-goals:** Do not change share decimals, fee rates, or the D45 dispatch rule. Do not add a new public selector.

Attributed: Astra-04. MiniMax, Grok, and Kimi re-checked the arithmetic. Coordinator re-read the two floor functions and the `redeem` cap.

### REQ-07 — Keep the rate-provider fallback inside the locked exception

- **Severity:** Medium
- **File and line:** `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:69-88`
- **Intended behavior:** D48. Failed-quote handling is confined to `_safePreviewExchangeIn`: a failed call or a reply that is not exactly 32 bytes yields `(false, 0)`, and the existing search loop continues. Other dependency failures stay hard. D60 does not authorize a gas-dependent snapshot path.
- **Broken requirement or invariant:** When state is empty and the subject reports unlock-context support, `_getRate` attempts `quoteState` only if `gasleft()` exceeds a threshold, forwards a reduced stipend, and on failure falls through to the live-supply probe. The adjacent comment states that this failure must not revert. That is a soft dependency path outside the D48 rewrite. Absence of `try`/`catch` in this file is not conformance.
- **Impact class:** Requirement deviation and valuation-assurance gap. Callers may observe a different quote path or failure behavior depending on remaining gas. Price manipulation or fund loss was not established.
- **Acceptance criteria:**
  - Either the gas-gated soft snapshot is removed and a failed `quoteState` follows the locked hard or exact-length rule, or a written amendment names this probe, the gas bound, the fall-through, and the required rate equivalence.
  - Tests cover success, failed call, short return data, and a call budget that cannot pay for the snapshot, and they assert the approved rate or the approved revert.
  - D48 evidence is refreshed against this implementation. The prior result is not inherited.
- **Non-goals:** Do not remove the D48 `_safePreviewExchangeIn` exact-length rule. Do not treat D41 or D49 probes as permission for this path.

Attributed: Astra-05. Grok, MiniMax, and Kimi re-read the branch. Coordinator re-read lines 69-88.

### REQ-08 — Bind completion evidence to the current FullSpread V4 tree

- **Severity:** Medium
- **File and line:** Current implementation under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`, including `hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:51-83`. The plan and evidence handoff still name the former `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` path and the 2026-09-25 release identity.
- **Intended behavior:** R1.3 and R12. Evidence identifies the actual corrected source, selectors, and runtime artifacts. D3 requires old and new code to be identified independently. A September attestation does not verify a later tree.
- **Broken requirement or invariant:** The plan's former V4 Common path is not the current hookless implementation. That implementation imports separate inventory, protection, transition-planner, quote, and execution-context units and uses `operationScope`. The completion header does not map these current variants. A prior green suite cannot be assumed to cover them.
- **Impact class:** Provenance and re-audit readiness. Submission identity can be mistaken. This does not prove the refactor is unauthorized or incorrect.
- **Acceptance criteria:**
  - A snapshot-to-current map names every current FullSpread V4 package, source file, and selector-set change, and states which tests cover each variant.
  - Historical evidence stays labeled historical. The authoritative current section cites commands and identities for the submission tree.
  - Build, selector, size, and the named APEX regressions are regenerated against that tree under a separate execution request. This review did not run them.
  - The hook × SE matrix disposition used for submission is one current count. The follow-up record's 195/1/7 and the earlier 165/3/7 figure are not both treated as the current result until one is tied to the submission tree.
- **Non-goals:** Do not overwrite or delete historical logs. Do not treat `independent-completion.json` as a substitute for the new run.

Attributed: Astra-06. Grok, Kimi, and MiniMax agreed after checking the current path. Coordinator confirmed the hookless Common file exists at the cited path.

## Dissent and unverified audit items

### Dissent

- **Evidence contradiction severity.** Grok finding 3, Kimi, and MiniMax treated conflicting historical and final counts as an evidence-integrity defect. Astra disagreed: the evidence file and follow-up record already label earlier sections as historical, so different counts alone do not prove the later claim is false. Coordinator disposition: do not require historical sections to be rewritten as false. Do require REQ-08's current-source map. The later 34,909/0 claim remains unverified because this round did not re-run it.
- **MiniMax first-pass readiness.** Withdrawn by MiniMax in cross-review. No remaining dissent that the tree is ready.
- **MiniMax M3-03.** The earlier PARTIAL list for R4.2, R4.3, and R4.5 is not adopted as a current defect. The follow-up claims a later fork pass. That pass was not re-run. Status: unverified.
- **MiniMax M3-07.** The locked D41, D48, and D49 probes are recorded exceptions, not defects. The extra soft path is REQ-07, not a reason to delete those exceptions.
- **Kimi F3.** `contracts/protocols/staking/token/TokenStakingTarget.sol:452` has a silent `try`/`catch` around `synchronizeRewards`. Kimi and Grok agree the site exists and that this file is not in the named D16 set. No locked requirement was shown to be broken. Do not remove it under this PRD unless a later scope ruling puts it in D16 or D37.
- **Kimi F4.** Dangling `lib/crane/.grok/skills/` targets were reported by search tools and broke a repository glob. Agreed as hygiene. Not an APEX money-path defect and not a blocker by itself. Repair belongs to mirror maintenance, not to this remediation's accounting fixes.

### Unverified

The council did not confirm or refute the full set of 108 criteria. Unverified, and therefore not closed by this PRD:

- Execution of the 2026-09-25 hermetic run, the 33 campaigns at 256×64, and the 37 fuzz properties at 10,000 cases.
- Current hook × SE matrix row states. Documentary counts conflict and were not re-counted from current tests.
- Historical fork inventory at chain 4663 block 64025200, and the EtherFi eth_main precheck run. Live exposure was not re-queried.
- Receipt-backed dispatch, Morpho burn sites, Stata and Aave loop capacity behavior, Lido, Rocket, and EtherFi prechecks, Balancer D68/D69 transition quotes, and DETF prepaid entries other than the residual helpers in REQ-01.
- Whether every D16 public pretransfer entry rejects a code-less caller and credits a same-state contract caller only under D15.
- Catalog classes A–K, A0, L, M, N, and O on surfaces whose tests were not read. Absence from this review is not proof a test is missing.
- Crane interface NatSpec was re-read by Astra in cross-review and matched D12. Other reviewers did not all re-read it. D12 remains an accepted residual.

Audit items:

| Audit item | Disposition |
| --- | --- |
| APEX-2026-001-M | Replacement local-book helper was inspected in part. Full stale-reserve closure is not proved (REQ-05, REQ-08). Live instances not remediated. |
| APEX-2026-001-M2 | Historical inventory not re-executed. Not a source-completion failure by itself. |
| APEX-2026-003 | Custody source correction was visible on the paths that were read. Cited tests are mis-aimed (REQ-03). Live custody instance not remediated. |
| APEX-2026-008 | Orbital refund and credit helpers were read by some reviewers and looked aligned. Five-site execution coverage was not fully re-checked here. |
| APEX-2026-009 | ERC-4626 and Morpho whole-balance refund removal was not fully re-read by every reviewer. Not confirmed closed. |
| APEX-2026-004B | Named dust-to-fee helpers were not found under `contracts/` by one search. Replacement booking behavior was not fully re-read. |
| APEX-2026-005 | `LocalCreditLib` matches the locked arithmetic. Consumer inventory was not re-derived. |
| `beforeSwap` retraction | No invented missing-guard finding. Named Balancer-quad control not re-executed. |
| Weighted dust retraction | Buffer-first tests exist. Catch-all matrix controls do not prove the rounding branch (REQ-04). |

## Non-goals for the whole PRD

- No deployment, migration, registry disablement, broadcast, or live transaction.
- No change to preserved historical Uniswap V3/V4 implementations except as read-only reproduction evidence.
- No removal of D12, and no new sender-attribution mechanism.
- No Slipstream product rewrite.
- No exploit procedure, proof-of-concept, payload, or attack parameter belongs in the implementing tests. Tests must assert the locked accounting and error results.
- Passing tests, a completion JSON, or four-reviewer agreement are not proof that unreviewed code is safe.

## Coordinator note

This note is not an Astra finding. The coordinator re-read the production and test lines cited in REQ-01 through REQ-07 and the hookless Common path in REQ-08. The coordinator did not re-run Foundry and does not adopt the 2026-09-25 green counts.
