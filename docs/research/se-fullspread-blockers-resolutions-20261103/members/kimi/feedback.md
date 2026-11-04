# Kimi advisory feedback

## Identity and disposition

- Member: `kimi`
- Draft under review: `draft-se-fullspread-blockers-resolutions-20261103-r1`
- Disposition: requested-changes

## Does the draft state Kimi's proposal accurately?

Not completely. The draft accurately records my F1, F4, F6, F8, F9, F11, F12, F13, F14, and F15 proposals, and it accurately records rather than conceals the F5 and F10 disagreements. F2 turns my conditional fee-booking rule into an unconditional collection assertion, F3 adds a pre-deposit skip that I did not propose, and F7 omits the positive amount-source rationale from my proposal.

## Corrections by draft section

### F2. Fees on a liquidity-adding user route

My proposal was to book **any fees actually collected** by the liquidity modification and to book none if no fees were collected; it did not assert that every deposit-side liquidity modification necessarily collects position fees. Replace “collect position fees through their liquidity modification, book those fees” with “book any position fees collected through their liquidity modification,” and retain the explicit zero-collected-fee case. This also removes the tension between the categorical recommendation and the draft's own evidence gap.

### F3. Booked total

My zero-liquidity proposal was a post-deposit outcome: if the one permitted deposit adds zero liquidity, retain the actual held balances as booked and return without another attempt. The draft instead says to predict that result and skip `modifyLiquidity`; that is a different procedure and was not my proposal. Either restore the post-deposit condition or identify the no-call rule as a coordinator refinement rather than including it in the blanket four-member agreement.

### F7. `Compounded()`

The emission predicate accurately reflects my proposal, including previously booked fees, mixed balances, donation-only exclusion, and zero-liquidity exclusion. The omitted load-bearing part is the replacement amount rationale: add that observers reconstruct token amounts from PoolManager currency deltas and any `Swap` event, rather than only saying what `ModifyLiquidity` does not contain. Without that positive source, F7's requested replacement rationale remains incomplete.

## Other sections

No correction is requested to the draft's treatment of F5 or F10: it recommends different procedures while expressly recording that my exact-half swap and two-argument `donate` proposals were not adopted. The preserved-disagreements and coverage tables accurately reflect those splits.

## Limits

This feedback does not treat the draft as an owner lock, authorize implementation, authorize a PRD edit, or replace the draft. I read only the exact coordinator draft named in the request, computed no fingerprint, and read no peer feedback.
