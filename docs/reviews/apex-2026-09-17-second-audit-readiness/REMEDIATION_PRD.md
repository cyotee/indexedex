# Remediation PRD: APEX second-audit readiness

- **Status:** DRAFT
- **Date:** 2026-10-03
- **Updated:** 2026-10-06, owner decisions OD-01 through OD-08 recorded. OD-08 resolves the stage-1 consistency questions.
- **Review target:** Current working-tree source, tests, and evidence for the APEX 2026-09-17 remediation. The question was whether that work is complete and whether the tests are adequate to submit this source for a second audit.
- **Implementation plan:** [REMEDIATION_PRD.plan.md](./REMEDIATION_PRD.plan.md). Stage 1 only. Executing that plan requires a separate request.
- **This document does not authorize code changes.** It is a handoff. A later session must be explicitly asked to implement it.

## Required outcome

Do not represent the current tree as a completed, regression-verified implementation of the locked plan. Before that representation:

1. Close the confirmed deviations below. REQ-01 and REQ-02 follow OD-01. REQ-05 follows OD-04. REQ-06 follows OD-03. REQ-07 follows OD-02.
2. Replace the cited weak or mis-aimed tests with assertions that match the locked property.
3. Map the current FullSpread V4 implementation set to the submission identity and regenerate source-bound build, selector, size, and regression evidence for that tree. OD-05 ratifies the hookless and Pons-family split. Do not merge those packages back together.
4. Keep accepted residuals documented. Do not treat them as missing source fixes, and do not treat a prior green count as proof they were re-verified.
5. Follow OD-06 as amended by OD-08. Stage 1 includes the three FullSpread outside-trade tests, the wings outside-trade test, and the regenerated evidence run. Stage 1 passing is not audit submission. Stage 2 reopens the APEX program before submission.

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

- Uni V4 DETF residual helpers still catch dependency failures outside D41, D48, and D49. OD-08 limits book-and-wait to a successful Standard Exchange preview of `0`. A hook preview of `0` rolls back. No new catch is authorized.
- The single-CP residual preview no longer catches. OD-01 requires that a returned zero stay local and that a reverting preview not be treated as zero.
- The shared receipt adapter derives `maxRedeem` by flooring twice. Owner decision OD-03 replaces that with the OpenZeppelin direction: the share cap is primary, and `maxWithdraw` is `previewRedeem` of that cap.
- The standard exchange rate provider has a remaining-gas soft `quoteState` probe that D48 does not authorize. Owner decision OD-02 removes that self-snapshot. A caller-supplied snapshot remains a separate path.
- Cited custody and matrix tests do not prove the properties their names or acceptance citations claim.
- The cited V3 reserve-reconcile supplement does not create the stale-reserve boundary R3.3 describes.
- Current FullSpread V4 code is not the single Common path named in the September handoff.

Agreed residuals, not source defects:

- Live chain-4663 instances are immutable. Replacement verification is not deployment remediation (D7, R4).
- D12 non-atomic contract pretransfer, including contract wallets and EIP-7702 delegated accounts, is the accepted `UNSUPPORTED_USE` residual.
- Slipstream deprecation (D57) is not a missed rewrite.

`LocalCreditLib` (`available`, `budget`, `requirePretransferCaller`) matches D11 in the file that was read. That positive observation does not close the families that consume it.

## Owner decisions

### OD-01 — Zero quote retains residual; a revert does not

- **Date:** 2026-10-06
- **Decides:** REQ-01 and REQ-02. This is not an exception to D37. No new catch is authorized.
- **Related design, not authority:** `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` and its implementation plan were read. Wings O1 uses the same split for a different product: unsellable inventory stays in custody and is not a public sweep, while an unfinished calculation is not a zero quote. That design does not authorize a DETF `try/catch` and does not upgrade FullSpread.

The owner confirmed:

1. A successful Standard Exchange `previewExchangeIn` of `0` is the only book-and-wait signal. The leftover stays booked to holders. The parent user operation continues. The leftover is not paid to the caller or the fee recipient. The operative Standard Exchange deposit is not called after that zero.
2. Any revert rolls the transaction back. Do not catch it and continue. Do not translate it into a retained residual.
3. OD-08 narrows item 1. Book-and-wait does not apply to a hook preview of `0`. A hook preview of `0`, or a hook join revert, rolls the parent transaction back. It does not book a new holder reserve.

Implementation consequence: the book-and-wait path is `_pairQuoteIsZero` and the Standard Exchange preview it calls. Remove the hook-join translation catches and make those joins hard calls. A failed `supportsInterface` probe is not a zero deposit quote and is not decided here.

### OD-02 — A plain rate call does not take a snapshot

- **Date:** 2026-10-06
- **Decides:** REQ-07. This removes the gas-gated self-snapshot. It does not remove the snapshot functions a hook uses when it already holds a projected state.
- **Context:** The owner is keeping the FullSpread vault for reference and possible use, and is deprioritizing it for complex configurations because its gas cost cannot be reduced. The replacement direction is `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md`. That product decision does not delete transition quotes. The wings vault implements `quoteState`. Hooks still pass an existing snapshot into a rate quote when they are projecting a swap.

The owner confirmed:

1. `getRate()`, and any `_getRate` call with an empty state, prices the live vault through the ordinary preview. It does not call `quoteState`. It does not check remaining gas.
2. If a caller already has a snapshot, `quoteRate` may still price against that snapshot. That path is not a fallback for a failed or skipped snapshot.
3. A failed snapshot is not silently replaced with the live rate. The caller that needed the snapshot handles that failure. The plain rate path never attempts the snapshot, so it has no snapshot failure to hide.

Implementation consequence: delete the branch at `StandardExchangeRateProviderFacet._getRate` lines 69–85. Keep `_safePreviewExchangeIn` and the D48 exact-length rule. Keep vault `quoteState` and hook projection that passes an existing snapshot in.

### OD-03 — maxRedeem is the share cap; maxWithdraw follows it

- **Date:** 2026-10-06
- **Decides:** REQ-06. The current double-floor formula is not correct and is not kept.
- **Source checked:** OpenZeppelin Contracts `ERC4626.sol` v5.7.0, retrieved 2026-10-06 from `https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/contracts/token/ERC20/extensions/ERC4626.sol`. In that file, `maxRedeem` returns the owner's share balance, and `maxWithdraw` returns `previewRedeem(maxRedeem(owner))`. The comment states that overriding `maxRedeem` is the supported way to change both caps, because `maxWithdraw` depends on `maxRedeem`.

The owner confirmed that this adapter must follow that direction, not derive `maxRedeem` by converting `maxWithdraw` back into shares.

This is not a wholesale port of OpenZeppelin's vault. Do not add its virtual-share offset, change `previewRedeem` rounding, or replace the receipt-backed accounting library. The difference from the uncapped OpenZeppelin default is that this adapter can hold fewer deliverable receipts than the accounting entitlement. A plain `balanceOf` return is correct only when `previewRedeem` of that balance does not exceed held receipts and is not zero.

The required relationship is:

1. `maxRedeem` is the largest share amount at or below the owner's balance whose `previewRedeem` payout is at least one receipt and does not exceed held receipt tokens.
2. If `previewRedeem` of the full balance meets that test, `maxRedeem` returns the full balance. That is the OpenZeppelin uncapped result.
3. `maxWithdraw` returns `previewRedeem(maxRedeem(owner))`. It is not an independent floor of the share entitlement that is then converted back into shares.
4. `redeem` continues to pay `previewRedeem`. A call at `maxRedeem` must be payable from held receipts and must not pay another holder's backing.

### OD-04 — New vaults prove their own outside-trade credit

- **Date:** 2026-10-06
- **Decides:** REQ-05. The old incorrect vault is not kept in the tree merely to prove the new vaults.
- **Product context:** FullSpread remains a reference vault. The preferred new vault is `UniswapV4UpperLowerWingsStandardExchangeVault`, specified in `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md`. Removing the old vulnerable source does not change immutable copies already deployed.

The owner confirmed:

1. Do not retain the old incorrect Uniswap vault source only so a before-and-after demonstration can still compile. A frozen copy, an old commit, or an existing log may record that the auditor's finding was real. That record is not the proof that the new vaults are correct.
2. Do not reconstruct the old stored-total equality and greater-than cases on FullSpread or on the wings vault. Those cases belonged to accounting the new vaults do not use.
3. Stage 1 must add an outside-trade credit test for each FullSpread implementation and for the wings vault. Someone trades directly against the pool. That trade must not refresh the vault's books. A following deposit or redemption is credited only from tokens the vault actually holds. No unearned shares or output are credited. OD-08 names the FullSpread set: V3, V4 hookless, and V4 Pons-family. One variant does not prove the others.
4. The current reserve-reconcile supplement may remain as a custody-synchronization test. It must not be cited as the stale-reserve proof.

This review session does not write those tests. Recording OD-04 is not permission to edit code.

### OD-05 — The FullSpread hook split stays

- **Date:** 2026-10-06
- **Decides:** REQ-08's authorization question. The current split is ratified.
- **Owner statement:** The previous unified FullSpread scope was too broad. Distinct packages are required for specific Uniswap V4 hooks. The owner specifically asked for the hookless package and the Pons-family package.

Do not merge those packages back into one vault to match the September plan's single Common path. Evidence must name the current hookless and Pons-family files. This ratification is not a security certification of either package, and it does not make FullSpread the preferred product. The wings vault remains the preferred direction for new use.

Open follow-on, not decided here: if the Pons-family FullSpread vault has the same high gas cost as the hookless FullSpread vault, whether a later package may bind the existing wings vault to a pool whose hook is the Pons-family hook. A package that only checks the pool's hook address is not authorized by OD-05. The current Pons FullSpread package contains its own fee, protection, and registration code. The wings PRD specifies a hookless pool binding. Reuse needs its own ruling after that gas comparison.

### OD-06 — Repair first, then reopen the APEX program

- **Date:** 2026-10-06
- **Decides:** the width of the later implementation task. Both scopes happen, in order. Neither is skipped.

Stage 1 is the fast-fail path. Implement the repairs stated in this PRD and test those repairs. A failing stage-1 test is iterated, including an alternate design if the stated repair cannot be made correct. OD-08 puts the three FullSpread outside-trade tests, the wings outside-trade test, and the regenerated build, selector, size, and named regression run in stage 1. Stage 1 still does not certify the 108 original criteria or audit readiness.

Stage 2 starts only after the owner is satisfied with the stage-1 results. It reopens the APEX program and checks that the broader changes and the new vaults meet the same standard. Audit submission waits for that pass. Stage 1 passing is not permission to submit.

This review session still does not implement either stage.

### OD-07 — Production-route security tests are required

- **Date:** 2026-10-06
- **Decides:** question 7. Option 1 is the project rule.
- **Owner statement:** The project must have test coverage that proves the vaults are secure. That coverage is executable and uses the real production path.

The rule is:

1. Implementing tests must exercise the real vault, hook, or adapter path and assert the exact corrected result. A test may show that the forbidden credit, refund, or payout does not occur.
2. Test names, comments, and reports must not describe how to attack a live system. They must not include an exploit procedure, proof-of-concept, payload, or attack parameter.
3. A red run on preserved old source is not required. OD-04 already says the new vaults prove themselves. Historical logs may remain labeled historical.
4. "Proves the vaults are secure" means the tests assert the locked security properties for the vaults in that stage. Stage 1 covers the repairs in this PRD, including the outside-trade tests and the regenerated evidence run named in OD-08. Stage 2 covers the broader APEX standard before submission. A passing test does not prove every unreviewed path is safe, and it does not replace stage 2.

### OD-08 — Stage-1 consistency rulings

- **Date:** 2026-10-06
- **Decides:** the three consistency questions left by the targeted PRD check. These rulings control over older sentences in OD-01, OD-04, OD-06, REQ-01, REQ-02, REQ-05, and REQ-08.

1. Book-and-wait applies only to a successful Standard Exchange `previewExchangeIn` of `0`. Hook residual joins are hard calls. A hook preview of `0`, or a hook join revert, rolls the parent transaction back. That path does not add a holder-reserve update and does not pay the amount out.
2. The outside-trade credit test is required for all three FullSpread implementations: V3, V4 hookless, and V4 Pons-family. It is also required for the wings vault. One passing variant does not prove the others.
3. Stage 1 includes those outside-trade tests and the regenerated evidence run: the current-source map, build, selector check, size check, and named APEX regressions. Those runs are not deferred to stage 2. Stage 1 passing is still not audit submission.

## Requirements

### REQ-01 — Use a zero preview for unprocessable residual, and do not catch a revert

- **Severity:** Medium
- **Decision:** OD-01 as narrowed by OD-08. The earlier remove-or-amend choice is closed. No new catch exception is required.
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol`. Re-read 2026-10-06: translation catches remain at `:578-584`, `:610-616`, and `:633-655`. The zero-quote book-and-wait path is `_pairQuoteIsZero` at `:699-705`. The `supportsInterface` probe catch at `:669-678` is outside OD-01.
- **Intended behavior:** A successful Standard Exchange `previewExchangeIn` of `0` is the only book-and-wait signal. Book that leftover to holders and continue the parent operation. Do not pay it to the caller or the fee recipient. Do not call the Standard Exchange deposit after that zero. A hook preview of `0`, or a hook join revert, rolls the parent back.
- **Broken requirement or invariant:** D37 requires dependency reverts to propagate. The remaining catches translate `ResidualJoinUnavailable` or a `ZeroAmount` plus a zero preview into a stopped retry or a different error instead of leaving that result to the zero-preview check. A recognized-error catch is not the signal for an unprocessable deposit.
- **Impact class:** Error propagation and residual accounting. A caught operative failure can continue the parent operation. Financial loss was not demonstrated.
- **Acceptance criteria:**
  - After a successful Standard Exchange `previewExchangeIn` of `0`, the Standard Exchange deposit is not called. The leftover is booked, the parent operation completes, and neither the caller nor the fee recipient receives that leftover.
  - The hook-join translation catches are removed. A hook preview of `0`, or a hook join revert, rolls the parent transaction back and does not add a holder-reserve update.
  - A reverting preview is not converted into a zero quote. Only a successful Standard Exchange preview return of `0` uses the book-and-wait path.
  - Tests assert those two outcomes and assert that booked inventory is not paid out.
- **Non-goals:** Do not add a catch exception. Do not decide the `supportsInterface` probe at `:669-678` under this requirement. Do not treat this as proof of theft. Do not rewrite unrelated DETF economics, vesting, or thresholds. Do not apply this ruling to the wings vault.

Attributed: Grok finding 1, Kimi F1, Astra cross-review agreement, MiniMax cross-review partial agreement on the recognized-error sites. Coordinator re-read the cited functions on 2026-10-03.

### REQ-02 — A zero residual preview is a result, not a caught error

- **Severity:** Medium
- **Decision:** OD-01 as narrowed by OD-08. No exception is required. A hook zero is not the book-and-wait signal.
- **File and line:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:244-251`. Re-read 2026-10-06: `previewResidualBuffer` already returns `previewExchangeIn` directly. The old recognized-error catch is gone.
- **Intended behavior:** `previewResidualBuffer` stays a direct preview call. A returned zero is not a DETF book-and-wait result and does not add a holder-reserve update. A reverting preview reverts the caller. Do not recreate a catch that turns one dependency error into zero.
- **Broken requirement or invariant:** The review-time catch violated D37. The current direct return matches OD-01 only if callers treat a returned zero as local retention and do not treat a revert as zero. That caller contract still needs a regression.
- **Impact class:** Quote and residual-maintenance divergence if a later edit restores the catch, or if a caller treats a revert as a zero quote.
- **Acceptance criteria:**
  - `previewResidualBuffer` remains a direct preview call. It does not catch.
  - A regression shows a successful zero quote does not add a holder-reserve update and does not pay the amount out.
  - A regression shows a reverting preview reverts the caller and does not book the amount as a successful zero.
- **Non-goals:** Do not invent a new public sweep. Do not change D6 residual retention on paths that already match it. Do not require a new owner amendment.

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

### REQ-05 — Prove outside-trade credit on the new vaults

- **Severity:** Medium
- **Decision:** OD-04 as named by OD-08. Do not keep the old incorrect vault only as a red demonstration. Do not invent old stored-total cases on the new vaults.
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol:58-152` is not the proof. New tests are required for FullSpread and for `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`.
- **Intended behavior:** An outside trade against the pool does not by itself refresh the vault's books. A later deposit or redemption is credited only from tokens the vault actually holds.
- **Broken requirement or invariant:** The cited supplement builds a current local-plus-deployed total and then trades through the vault. That is a custody-synchronization check, not an outside-trade credit check. The old equality and greater-than cases are not a requirement for vaults that no longer use stored-total-minus-deployed accounting.
- **Impact class:** A completion citation does not prove the new vaults are free of unearned credit after an outside trade. This does not reintroduce APEX-2026-001-M in the new code. Deleting old source does not remediate immutable deployed copies.
- **Acceptance criteria:**
  - V3 FullSpread, V4 hookless FullSpread, and V4 Pons-family FullSpread each have an outside-trade test. The pool trade is not a vault call, the vault book is not refreshed by that trade, and the following credit uses only tokens the vault holds. One variant does not satisfy the others.
  - The wings vault has the same outside-trade test against its own accounting. That test is a stage-1 deliverable.
  - The reserve-reconcile supplement is not cited as the stale-reserve proof.
  - Historical evidence of the old bug, if retained, is labeled historical and is not required to keep the old source compiling.
- **Non-goals:** Do not reconstruct the old stored-total matrix. Do not claim a live instance was upgraded. Do not treat this review as authorization to write the tests now.

Attributed: Astra-03. Grok and Kimi re-read the supplement. Coordinator did not re-run it.

### REQ-06 — Make maxRedeem the share cap, in the OpenZeppelin direction

- **Severity:** Low
- **Decision:** OD-03. Do not keep the current formula.
- **File and line:** `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:67-81` and `:153-166`; `contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:54-70`
- **Intended behavior:** `maxRedeem` is the largest owner share amount that `redeem` can pay from held receipts. `maxWithdraw` is `previewRedeem` of that amount. This matches OpenZeppelin ERC-4626 v5.7.0's direction. It does not copy that contract's uncapped `balanceOf` return when held receipts cannot pay `previewRedeem` of the full balance.
- **Broken requirement or invariant:** `maxWithdraw` floors the owner's entitlement and caps by held receipts. `maxRedeem` floors that asset amount back into shares. `redeem` pays `previewRedeem`, so the cap and the payment do not use the same function. A deliverable full balance can be rejected. The formula is a lower bound, not the correct maximum.
- **Impact class:** Unnecessary redemption rejection and stranded share dust. No theft magnitude was established. No runtime case was executed.
- **Acceptance criteria:**
  - `maxRedeem` does not call `maxWithdraw` or `convertToShares`.
  - When `previewRedeem` of the owner's full balance is at least one receipt and no greater than held receipts, `maxRedeem` returns that full balance.
  - Otherwise `maxRedeem` is the largest smaller share amount whose `previewRedeem` is at least one receipt and no greater than held receipts, or zero if no such amount exists.
  - `maxWithdraw` equals `previewRedeem(maxRedeem(owner))`.
  - `redeem` at `maxRedeem` succeeds and transfers no more receipts than the vault holds. A larger redeem is rejected. A zero-receipt share burn is not advertised.
  - Both dispatched families have a non-integral-rate test for the payable full balance and a test for the receipt-limited case.
- **Non-goals:** Do not port OpenZeppelin virtual shares or change `previewRedeem` rounding. Do not change share decimals, fee rates, or the D45 dispatch rule. Do not add a new public selector.

Attributed: Astra-04. MiniMax, Grok, and Kimi re-checked the arithmetic. Coordinator re-read the two floor functions and the `redeem` cap.

### REQ-07 — A plain rate call uses the live preview

- **Severity:** Medium
- **Decision:** OD-02. The gas-gated self-snapshot is removed. No amendment keeps it.
- **File and line:** `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:69-85`
- **Intended behavior:** An empty-state rate prices the live vault through the ordinary preview. It does not call `quoteState` and does not check remaining gas. A caller that already holds a snapshot may still pass it to `quoteRate`. A failed snapshot is not replaced with the live rate.
- **Broken requirement or invariant:** `_getRate` currently calls `quoteState` when no state was supplied, the subject supports unlock-context quotes, and `gasleft()` exceeds 250,000. Failure or a short reply falls through to live `totalSupply()`. The same share can therefore receive a snapshot rate or a live rate depending on remaining gas. D48 does not authorize that branch. The Full Spread gas workaround is not a reason to keep it, including for the wings vault, which implements the same unlock-context interface.
- **Impact class:** Valuation inconsistency. A low-gas caller and a high-gas caller can observe different rates for the same vault. Fund loss was not demonstrated.
- **Acceptance criteria:**
  - Empty-state `getRate` and `_getRate` do not call `quoteState` and do not read remaining gas. The rate is the live preview path.
  - `quoteRate` with a caller-supplied snapshot still prices against that snapshot.
  - A test shows the empty-state path does not change when the vault's `quoteState` would fail or when the call budget is low.
  - A test shows a failed caller-supplied snapshot is not reported as the live rate.
- **Non-goals:** Do not delete vault `quoteState`, `quoteTransition`, or hook projection that passes an existing snapshot. Do not remove the D48 `_safePreviewExchangeIn` exact-length rule. Do not treat this as a Full Spread gas reduction. Do not require the wings vault to stop implementing transition quotes.

Attributed: Astra-05. Grok, MiniMax, and Kimi re-read the branch. Coordinator re-read lines 69-85. Owner decision OD-02 recorded 2026-10-06.

### REQ-08 — Bind completion evidence to the current FullSpread V4 tree

- **Severity:** Medium
- **File and line:** Current implementation under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`, including `hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:51-83`. The plan and evidence handoff still name the former `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` path and the 2026-09-25 release identity.
- **Intended behavior:** R1.3 and R12. Evidence identifies the actual corrected source, selectors, and runtime artifacts. D3 requires old and new code to be identified independently. A September attestation does not verify a later tree.
- **Decision:** OD-05. The hookless and Pons-family split is authorized. Do not revert it.
- **Broken requirement or invariant:** The plan's former single V4 Common path is not the current tree. The current hookless implementation imports separate inventory, protection, transition-planner, quote, and execution-context units and uses `operationScope`. The Pons-family package is a separate product. The completion header does not map these current variants. A prior green suite cannot be assumed to cover them.
- **Impact class:** Provenance and re-audit readiness. Submission identity can be mistaken. This does not prove the refactor is unauthorized or incorrect.
- **Acceptance criteria:**
  - A snapshot-to-current map names every current FullSpread V4 package, source file, and selector-set change, and states which tests cover each variant.
  - Historical evidence stays labeled historical. The authoritative current section cites commands and identities for the submission tree.
  - Build, selector, size, and the named APEX regressions are regenerated against the current tree in stage 1. This review did not run them. Stage 1 is not complete without that run. Stage 1 passing is still not audit submission.
  - The hook × SE matrix disposition used for submission is one current count. The follow-up record's 195/1/7 and the earlier 165/3/7 figure are not both treated as the current result until one is tied to the submission tree.
- **Non-goals:** Do not merge the hookless and Pons-family packages. Do not overwrite or delete historical logs. Do not treat `independent-completion.json` as a substitute for the new run. Do not treat OD-05 as approval to bind the wings vault to a Pons pool.

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
- No exploit procedure, proof-of-concept, payload, or attack parameter belongs in test names, comments, or reports. OD-07 still requires production-route tests that assert the forbidden result does not occur.
- Passing tests, a completion JSON, or four-reviewer agreement are not proof that unreviewed code is safe.

## Coordinator note

This note is not an Astra finding. The coordinator re-read the production and test lines cited in REQ-01 through REQ-07 and the hookless Common path in REQ-08. The coordinator did not re-run Foundry and does not adopt the 2026-09-25 green counts.
