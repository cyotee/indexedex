# Advisory feedback

## Identity

- Member: grok
- Profile: research
- Phase: advisory feedback
- Requested role: council-member
- Requested model: `xai/grok-4.7:xhigh`
- Runtime identity not given in the assignment: not exposed
- Peers read before this feedback: no

## Draft under review

- Draft ID: `draft-se-fullspread-blockers-resolutions-20261103-r1`
- Path: `docs/research/se-fullspread-blockers-resolutions-20261103/coordinator/draft.md`
- Fingerprint: not computed. This pass did not compute a hash.
- The named file opened. This feedback reviews that file only.

## Disposition

requested-changes

The no-processing branch, the fee booking, the actual-balance total, the pool-price ratio, the ratio-sized swap, the seven-address write, the selector restatement, the three-argument `donate`, the stored owner, the two reserve names, the compound-sentence replacement, and the consumer-list completion rule are the proposals I made, in compressed form. Four sections still misstate a load-bearing part or drop one that would let two implementors diverge. Those are corrections, not a request to paste my response back in.

This draft is not an owner lock. This feedback does not authorize implementation, does not authorize a PRD edit, and does not replace the draft.

## Accuracy

| Draft section | States my proposal accurately? |
| --- | --- |
| Proposed text, opening | No, on the rule that a recommended sentence fits a lock already made. F6 does not. |
| F1. Overstated maximum | The no-processing branch matches. The sentence does not. It is not the form I raised. |
| F2. Fees on a liquidity-adding user route | The book-and-keep-off-the-user disposition matches. The sentence omits three limits. |
| F3. Booked total | The actual-balance total and the zero-liquidity skip match. Exhaustion and the balance's measure are thinner than the proposal. |
| F4. Position ratio | Yes. "Booked balances" is the same exclusion as booked remainders if the first clause is the definition. |
| F5. One-token swap size | The size rule matches. "Rounded so any remainder is in the input token" carries the direction I named as round down. |
| F6. Unconverted exit principal | The attribution matches: I proposed payment to the output recipient, and I am not support for the revert. The recommended sentence is not my proposal, and its reason misstates the lock. |
| F7. `Compounded()` | The recommended sentence matches, except it does not say a `Swap` is not required. The later tables do not match. |
| F8. Seven-address write | Yes. |
| F9. Selector row | Yes. "The other absences in that row stay" covers the absences I named. |
| F10. `donate` signature | The signature and the pull-versus-flag split match. `compound()` staying argument-free is omitted. |
| F11. Batch-swap routes | The route split matches, including the one-token exit. The borrowed-path checks I kept are omitted. |
| F12. Owner after initialization | Yes. |
| F13. Two names | Yes. Adding `reserveOfToken` does not contradict the proposal. |
| F14. Sentences the no-compound lock removes | Yes. "Does not decide a sentence F2 already proposes" is the same limit as not deciding fee collection. |
| F15. Consumer list | The completion rule matches. "This file" does not. |
| Preserved disagreements | F6's record of my non-support is accurate. F7's "deployed balance" is not my predicate. |
| Coverage | Same F7 miss. F1's "Astra, Grok, Kimi" overclaims that I raised the draft's shorter form. |
| Evidence gaps | Fair as a limit. It does not misstate the proposal. |
| Limits | The non-authorization matches. |

## Corrections

### Proposed text

The opening says a sentence is recommended only where it fits a lock the owner already made. F6 recommends a revert the redemption no-revert sentence does not fit. Either narrow that opening, or stop presenting the F6 revert as a reading of the existing lock.

### F1. Overstated maximum

Do not say this form was raised by Grok. I raised the no-processing branch. I did not raise this shorter sentence.

Replace "Previews and minimums follow that branch." The pull-path preview has no `pretransferred` argument. If it follows the overstated branch, a declared pull against an empty unbooked balance quotes zero. The pretransfer preview reads the current unbooked balance and uses the snapshot branch. The pull-path preview does not. The execution minimum uses the execution branch's zero output, and a positive caller minimum fails that existing check. The difference itself does not revert.

### F6. Unconverted exit principal

Keep the record that Grok is not support for the revert. That part is accurate.

Do not state, as the recommended sentence, that the no-leftover-shortfall-revert sentence removes only the former sleeve top-up. The already-locked list states that sentence as a redemption rule: the redemption pays the principal fraction and does not have a leftover shortfall revert. Sleeve-only scope is a contested reading. It is not the lock's text.

If the draft still recommends the revert, say that the recommendation reverses that redemption sentence, and that the owner has not chosen the reversal. Do not describe the reversal as what the lock already says. Name both the vault's own unlock and the borrowed unlock, or the two paths diverge under the draft's own sentence.

The reason "paying the residual moves principal somewhere the lock does not name" is not a statement of my proposal. The principal-payment sentence names the payment. The output recipient is the payee the exit already uses. Rejecting payment is a choice. It is not a finding that the lock has no payee.

### F11. Batch-swap routes

Add that `exchangeIn` proceeding while unlocked does not delete the FS-UNLOCK-02 borrowed-path checks, including `pretransferred` false. Without that clause, "may proceed" reopens the borrowed `pretransferred` revert the proposal kept.

### F15. Consumer list

Replace "This file does not contain that list." In a sentence meant to be copied, "this file" can mean the draft, the blockers file, or the PRD. The blockers file does not contain the list. The PRD is where the pass must write it. Those are not the same file.

### Preserved disagreements

F7's recommended column, "Emit only when fees are in the deployed balance," is not the predicate in the F7 sentence and not my proposal. The predicate is: `donate` or `compound` adds positive liquidity, and the processed balance included a positive collected or previously booked fee in either token. Fungible units are not traced into the position.

### Coverage

The F7 result, "Emit when fees are deployed," has the same miss. The F1 agreement line should not say I raised the draft's F1 form.

## Omitted load-bearing parts

### F1. Overstated maximum

- On an aborted multi-leg call, refund each overstated snapshot and each within-maximum leg's declared amount only. Do not refund the surplus above a within-maximum declaration, and do not leave that declared amount sitting.
- The payer is the caller that declared the maximum, not the output recipient and not a discovered token sender.
- A processed donation books a taken amount that cannot be deployed. It does not refund that taken amount. The overstated donation is not processed, so that booking rule does not apply to it.
- An executing pretransfer still shapes a swap, on a route that swaps, so the refundable remainder is in the provided token. "Leave the rest" does not carry that sentence.
- Within-maximum, the amount subtracted is the amount taken into the route, not the amount deployed. Deployed-versus-taken is what keeps the donation booking rule from fighting the refund.

### F2. Fees on a liquidity-adding user route

- Book the `feeDelta` for both tokens. "Those fees" can be read as the input token only.
- Do not swap the booked fee delta on the user route. "Do not deploy" does not say that. A one-sided deposit already swaps, and the fee tokens can be swept into that swap.
- That booking is not a `Compounded()` emission.
- A pass-through still takes no usage fee. The draft says it collects no position fees and does not say the usage-fee exclusion is unchanged.

### F3. Booked total

- The measured balance is the vault's ERC-20 balance after settlement, not a PoolManager delta and not a calculated counter.
- Inexact exhaustion of the scarcer token is not a second deposit and not a revert. "Not a second booking" does not say that.

### F5. One-token swap size

- Weir's divide-by-two is not the amount. The size sentence already excludes it if it is read strictly. The section should say so, because FS-OWN-33's "about half" is that formula and a rewriter can copy it under another name.
- The size does not move a user-deposit remainder into the booked balance, or a maintenance remainder to the caller.

### F7. `Compounded()`

- A `Swap` event is not required to justify the emission, and it is not the amount record for a both-token add. The section says `ModifyLiquidity` is not the amount record. It does not close the `Swap` reading.
- "A positive amount in either token" should be explicit. A fee in one token still emits. A zero fee does not.

### F10. `donate` signature

- `compound()` keeps no arguments. The new `donate` flag does not spread to it.
- `pretransferred` true uses the unbooked balance up to `amount`, and the overstated case refunds the snapshot and deploys nothing. "Under F1" carries that only if F1 is corrected first.

### F11. Batch-swap routes

The omitted borrowed-path checks are the correction above. The one-token exit inclusion is not omitted. The attribution records that inclusion and does not record the checks.

### F15. Consumer list

The missing hook-scenario clause: the absent list is not a defect in the B-08 hook-scenario lock. "May start without the consumer list" covers the start gate. It does not cover that defect claim.

## What was not adopted from others

Peer response files and peer feedback were not read. Attributions of Astra, MiniMax, and Kimi are not confirmed and not denied.

From the draft's own account, my F6 payment to the output recipient is not adopted. That record is accurate. I do not accept the sleeve-only reading offered as the reason. I do not adopt unread peer sentences, and I do not treat the draft's choice of the revert as an owner lock.

## Limits

- Comparison is to the proposal submitted earlier in this conversation. `response.md` was not re-opened in this pass.
- No hash was computed. No Forge, tests, installs, or Git were run. No other file was edited.
- This feedback does not replace the draft. It does not authorize implementation, a PRD edit, or an owner lock.
- This feedback does not request a further round.
