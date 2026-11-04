# Coordinator-preserved drafting contribution

Grok returned this original contribution inline for the unified PRD authoring task. Preserved verbatim from Native final_response. It is not an advisory disposition or a replacement for the previous fidelity-review original.

---

Recommended disposition: publish one working document, identity `pairtoken-unified-prd-r1`, whose body is the archived r2 text with the sentences below substituted or added. Keep all existing requirement IDs and PT-AC-01 through PT-AC-58. Append only the new rows. Do not ship an errata annex, source locators, or an instruction to read target code. Do not edit the archived r2 or the fidelity files.

## Framing to place before Part I

**Purpose.** This is the single working specification for a fungible ERC-20 share of one full-range pool position plus the instance's idle pool-currency balances. A separate team uses this document alone to plan and implement the specified external behavior, integer results, and integration contracts.

**Users and operations.** Any caller may initialize an uninitialized instance once. Share holders may approve and transfer shares. A depositor may add both currencies, or one configured currency, and receive shares at a nonzero recipient. A holder may burn their own shares for both currencies, or for one selected currency. Anyone may compound. Views quote the current basket and a paired deposit or paired redemption. They do not move funds.

**Scope.** The normative baseline is source-equivalent behavior: public ABI, constants, formulas, rounding, casts, check order, events, errors, and the dependency limits in Part III. No bytecode identity, private storage layout, or original helper decomposition is required.

**Non-goals.** This document does not add `getRate`, ERC-4626 conversions, per-holder fee claims, a fee-rate clamp, permit approvals, delegated redemption, rescue, range changes, pause, rebalancing, or an IndexedEx, Crane, or registry adaptation. It does not certify runtime equivalence, an unexposed workflow, or legal clearance.

**Conformance.** A plan maps every requirement ID to planned work and observable acceptance evidence. It lists manager, factory, fee-manager, token, and hook assumptions. It does not fill a gap by consulting target implementation code. A successful-path example never overrides an earlier guard, dependency failure, arithmetic failure, or transfer failure. Changing a specified quirk is a labeled product change, not source equivalence.

**Provenance.** Working identity: `pairtoken-unified-prd-r1`. It supersedes archived `pairtoken-requirements-final-r2` plus the proposed errata as the document to work from. Those archives remain unchanged. This text incorporates the pull-return wording, the idle-pair read order, and the uncapped-fee consequence below. It is not a claim that the archived r2 bytes were edited.

## C1, replace the closing sentence of PT-DEP-05

Emit `Deposit` after the refund with pull-returned amounts `v0,v1` and net recipient shares. A native pull returns its selected nominal amount and does not measure a balance change. An ERC-20 pull returns its checked post-call balance minus pre-call balance, including zero. A lower post-call balance fails checked subtraction and rolls the deposit back.

Also replace the first sentence of PT-DEP-05 so it cannot be read as an event rule for native amounts:

Measured ERC-20 receipts replace the selected ERC-20 amounts for funding and for that leg of the event, but shall not change the already computed or checked shares.

Leave the rest of PT-DEP-05, including reservation, refund recipient, and zero-refund skip, unchanged.

## C1, replace the paired-amount sentence of PT-EVENT-02

Paired `Deposit` amounts are pull-returned amounts: the selected nominal amount for a native leg, or the checked ERC-20 balance difference defined by PT-BAL-02, including zero. Zap `Deposit` amounts remain the reported add-used amounts.

Do not change the genesis net-share sentence, the redemption event sentences, or PT-BAL-02.

## C2, add to PT-BAL-01

Whenever both configured idle balances are sampled as a pair, read currency0 idle before currency1 idle. This order adds no rejection, oracle, snapshot promise, or balance budget. Each route keeps its own price, burn, settlement, and reservation checkpoints. Paired-entry addition reads the fresh manager price after those two idle reads. Deploy addition uses the price Deploy already holds: the price read at the start of Deploy if no swap ran, otherwise the post-swap price. Deploy does not read a new price between its two idle reads.

Add a cross-reference, not a second rule, in PT-VIEW-02, PT-EXIT-01, PT-COMP-04, and PT-CB-05: sample idle0 then idle1 under PT-BAL-01. Keep PT-DEP-03's statement that its price-after-idle checkpoint is specific to paired entry.

## Uncapped fee, add to PT-COMP-02

The `uint16` protocol rate has no local maximum of 10000. For each currency, the attempted amount is the already specified checked `floor(reported collection * rate / 10000)`. That attempt is not capped by the collected amount or by a separately segregated principal budget. It may therefore exceed the collected amount and, if paid, use other instance balance. Native reservation excludes value from idle accounting only. It does not escrow that value against a later protocol payment.

If a native protocol payment succeeds and a later idle calculation's checked subtraction underflows, the failure reverts the whole transaction, including the payment. That rollback is not a committed principal reduction and is not a successful permanent drain. An ERC-20 attempt can likewise approve and notify more than the collected amount. A successful notification remains not proof that tokens were pulled. Do not add a clamp, a second fee calculation, or a spend-limited escrow.

Illustration, not a second formula: collected native fees are 100, the rate is 20000, those 100 units are already in the instance balance, there is no other free native balance, and reserved native `R` is at least 100. The attempt is 200. If that payment succeeds, the remaining balance is `R - 100`. The next idle subtraction of `R` underflows, and the transaction reverts.

## Acceptance rows to append

Preserve PT-AC-01 through PT-AC-58. Add:

| ID | Scenario | Expected observation | Requirements |
| --- | --- | --- | --- |
| PT-AC-59 | Native paired deposit sends `amount0`, the quote selects less, and the recipient differs from the sender | The event's native amount is the selected nominal pull return, not a balance delta around the pull and not the full `msg.value`. The unselected remainder is refunded to the sender after the reservation is cleared. A zero refund makes no call. | PT-DEP-05, PT-BAL-02, PT-BAL-06, PT-EVENT-02 |
| PT-AC-60 | An otherwise successful paired deposit receives an ERC-20 balance difference of zero for a selected leg | Shares stay at the pre-pull quote. The event shows zero for that leg. No rule requires the receipt to be strictly positive. | PT-DEP-05, PT-BAL-02, PT-EVENT-02 |
| PT-AC-61 | An ERC-20 pull's post-call balance is lower than its pre-call balance | Checked subtraction fails. The deposit rolls back, including any earlier compound effects. This is not `TransferFailed` merely because the difference is negative. | PT-BAL-02, PT-ERROR-03, PT-ERROR-04 |
| PT-AC-62 | Basket, redemption, compound, Deploy addition, and paired-entry addition each sample both idles | Each pair reads currency0 idle before currency1 idle. Paired entry reads price after both reads. Deploy addition uses its already-held price and does not read price between the idle reads. No new rejection is added. | PT-BAL-01, PT-DEP-03, PT-VIEW-02, PT-EXIT-01, PT-COMP-04, PT-CB-05 |
| PT-AC-63 | An accepted zap Deploy reports zero used amounts for both currencies | The share quote is zero and the zap rejects `MinShares`. Pull, swap, and add effects roll back. No dead-share mint or leftover refund is added. | PT-ZAP-04, PT-CB-05, PT-ERROR-04 |
| PT-AC-64 | Chosen-leg redemption's final output is zero; separately, a paired output leg is zero | The chosen-leg route still attempts the selected transfer. Native payout failure uses the wrapped payout error, not `TransferFailed`. The paired route skips each zero transfer. | PT-EXIT-03, PT-EXIT-04, PT-BAL-05, PT-BAL-06 |
| PT-AC-65 | Position liquidity is zero, one idle balance exceeds 1000, and Deploy adds no liquidity | Public `compound` returns `(0,0)`. No collection unlock runs. Deploy may still run. No `Compounded` event is emitted solely for a swap or for zero addition. No shares are minted. | PT-COMP-01, PT-COMP-04, PT-COMP-06 |
| PT-AC-66 | Collected native fees are 100, the protocol rate is 20000, that 100 is already in the balance, no other free native balance exists, and reserved native `R` is at least 100 | The attempt is 200, with no local cap. If the payment succeeds, the following idle subtraction underflows and the whole transaction reverts, including the payment. A committed principal reduction is not observed. No fee clamp is added. | PT-COMP-02, PT-COMP-03, PT-BAL-01, PT-ERROR-04 |

## Preservation and standalone risks

- Do not leave the old "measured amounts" sentence beside the new PT-DEP-05 sentence. The first sentence of PT-DEP-05 must stay ERC-20-specific, or it will again sound like a native measurement rule.
- Do not replace every use of "measured." ERC-20 receipts still replace selected funding amounts and still do not recompute paired shares.
- Do not turn the idle-order sentence into a reentrancy exploit, a snapshot promise, or a new revert. The order is the requirement. A state-mutating `balanceOf` was not established.
- Do not clamp the fee rate or call the rollback a successful drain. The numeric illustration is not a second formula. Its premises include the collected units already being in the balance.
- Do not generalize the two-word ABI encoding note. If a sentence is wanted under PT-VIEW-01, limit it to this: the specified preimage is the standard ABI encoding of two 32-byte words, and a packed concatenation of those same two words is the same 64 bytes. Do not extend that claim to shorter or dynamic fields, and do not change the slot formula.
- Do not copy source listings, source line numbers, or "see the implementation" into the planner document. Dependency unknowns stay in Part III.
- Do not add `getRate`, target normalization, principal escrow, or a full-fill check while consolidating.
- Do not say the archived r2 was corrected in place. Say this working document supersedes it. The fidelity disagreement on whether the fee sentence was a completeness gap stays in the review archive, not as a second normative status inside the PRD.

