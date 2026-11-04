# Advisory feedback

## Identity

- Member: grok
- Profile: research
- Phase: advisory feedback on the coordinator draft
- Draft under review: `draft-se-fullspread-owner-decisions-20261103-r1`
- Path read: `docs/research/se-fullspread-owner-decisions-20261103/coordinator/draft.md`
- Fingerprint: not computed. Not recomputed.
- Peers read before this feedback: no
- Requested role: council-member
- Requested model: `xai/grok-4.7:xhigh`
- Runtime identity: not exposed

## Disposition

requested-changes

The Coverage verdicts can stand. The requested changes are to three sentences in Proposed text. They are not a request to flip a yes or no.

## Whether the draft states the proposal

The draft states the proposal accurately for F1, F2, F3, F5, F6, F8, F9, and F11, and for the F13-F15 line. F7 states the two-trigger problem and then asks a narrower missing fact than the one recorded. F4 does not state the accepted definition. F12 attributes a missing fact that was not recorded, and it omits the lock collision.

F10 is stated accurately in that section and in Preserved disagreements: the signature stands, and the true-branch dependency is carried under F1. The Coverage row's flat "no" is acceptable only if that section stays. It is not a second signature defect.

F7's "partly" matches the distinction already drawn: the claim-versus-deposit reason is the misunderstanding, and naming `Donation()` is a change, not that misunderstanding. The field does not need to be flattened back to yes.

Other members' readings are not confirmed here. They were not read.

## Corrections

### F4. Position ratio

The section says the accepted definition is the current pool price at the stored ticks. That is not the sentence that was accepted, and it is not what the proposal recorded.

The accepted definition is the token amounts a full-range liquidity unit consumes at the current square-root price and the stored ticks, excluding unpaid fees and booked balances, read immediately before the proportional add. "Current pool price" is a different object. A reader who copies this section would lock the price, not those amounts.

The no / no / no verdicts can stay. Replace the definition sentence.

### F7. `Compounded()` and `Donation()`

The prose correctly says "deploy booked tokens" and "a donation that also collects accrued fees" are not the same predicate. The missing-fact sentence then asks only whether `Compounded()` fires for any booked deploy or only for tokens known to be fees.

That fee-origin question is real, and line 254 is why. It is not the whole fact that was recorded. The recorded fact has three branches: fire when booked tokens are deployed, fire when the call collects a nonzero fee delta, or fire only when both happen. The collect branch can be true when those fees are not deployed in that call. Put that branch back in the missing fact. Do not leave it only in the prose above the fact.

### F12. Live `feeTo()`

Do not attribute the `address(0)` question to this proposal. It was noted as not decided, and it was not answered. It was not the recorded missing fact.

The recorded missing fact is one question: after `feeTo()` changes, is owner authority only the new `feeTo()` address, or both that address and the owner stored at initialization?

The "if possible" clause is a second unnamed branch that was recorded: it does not lock whether the Operable predicates are required. That part of the section is accurate.

The section also says the reconsideration replaces the report's freeze. That is accurate, and it is not a misunderstanding. It omits the other half of the problem: the owner did not say this replaces the 2026-11-02 sentence that the initialization-time `feeTo()` address is the owner `onlyOwnerOrOperator` uses. Add that. Without it, the problem reads as unnamed facts only, and the lock collision is lost.

The three questions now listed under "two unnamed facts" should be split. Keep the stored-owner question and the "if possible" branch as this proposal. Do not assign the zero-address question to it.

## Omitted load-bearing parts

### F1. Overstated maximum

The primary fork is stated: refund and process nothing, or credit another sitting balance. The recorded fact also asked which balance, if the credit reading is the one kept. That half is omitted. It is the same fact, not a new product question. Add "and which balance" to the missing fact if the credit branch stays open.

The non-atomic case inside the aggregate unbooked balance is stated accurately, and it is correctly separated from the overstated case.

### F7. `Compounded()` and `Donation()`

The collect-versus-deploy branch named above is the omitted load-bearing part of the missing fact. The pair-token `Donated` signature was an observation that the owner did not adopt that event. It is not load-bearing once the section says `Donation()` has no fields. Do not add it for that reason.

### F12. Live `feeTo()`

The omitted load-bearing part is the unreplaced 2026-11-02 initialization-owner sentence, named in the F12 correction above.

## Sections that need no correction

F2 states the proposal. "Leave fees untouched" does not match the accepted booking sentence. The withdrawal lock at blockers line 256 is cited. The Kimi reading is preserved as not the only reading. That does not misstate this proposal. `Pool.sol` lines 189-193 are not repeated. They are not load-bearing beside the PoolManager citation.

F3, F5, F6, F8, F9, and F11 state the proposal. F6 correctly keeps the exit sentence accepted and charges the 48% explanation as the problem, including the conflict with the F5 acceptance. F5 correctly does not treat that sentence as a replacement of the acceptance.

F13 through F15 are stated: not decided, and silence is not acceptance.

## Limits

- This feedback does not treat the draft as an owner lock.
- This feedback does not authorize implementation.
- This feedback does not authorize a PRD edit.
- This feedback does not replace the draft.
- Peer responses and peer feedback were not read. Attributions to other members are not confirmed.
