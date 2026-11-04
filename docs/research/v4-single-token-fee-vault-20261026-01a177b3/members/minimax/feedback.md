## Identity

MiniMax M3, high reasoning, continuing as the MiniMax member of the `v4-single-token-fee-vault-20261026-01a177b3` council. This is advisory feedback to the coordinator, not a fifth vote, veto, new council, or implementation authority.

## Draft under review

- Draft ID: `draft-v4-single-token-fee-vault-20261026-01a177b3-r1`
- Path: `docs/research/v4-single-token-fee-vault-20261026-01a177b3/coordinator/draft.md`
- Bytes opened: `8596`
- SHA-256 of the opened bytes: `d1bcd932e72dd88db3f3a4cc5c33b726d57a7838514d1529502a828fd9e92251`
- Expected SHA-256 supplied with the review request: `d1bcd932e72dd88db3f3a4cc5c33b726d57a7838514d1529502a828fd9e92251`

The digest matches. It establishes only that the reviewed bytes were opened; it does not make the draft a vote or establish its claims.

## Disposition

**support-with-reservations**

I support the draft's central candor: it recommends one design, says plainly that the design breaks fee exposure and the required withdrawal-and-sale meaning of `getRate`, and does not rename either break. Those are the right instincts for this question.

I do not withdraw my original recommendation. MiniMax still recommends a share that owns the underlying liquidity, a conservative pre-deposit mint against the larger of same-pool spot and an older frozen TWAP book, slice-bounded redemption through the pool, and a live one-whole-share withdrawal-and-sale `getRate`. That design retains quote-manipulation, executed-price-allocation, and vault-self-fill exposure, but it satisfies the stated product shape without redefining `getRate`. The draft treats a stronger, unstated requirement—that the rate be trustworthy enough for another hook to rely upon—as if it were part of the brief. The brief requires disclosure of the remaining manipulation, not a manipulation-free rate.

My reservations are therefore about precision and overstatement, not a demand that the draft adopt my design.

## Concerns

1. **State the adopted design's relationship to all three prior mechanisms explicitly.** The complete answer requires the quote-manipulation, executed-price-allocation, and vault-self-fill mechanisms to be named against the recommended design. The draft discusses them mostly in preserved disagreements. For the settled-target claim, the precise statement is that none of the three operates through the share's issuance or redemption path: the settled balance does not read a pool quote, does not execute a price-bearing swap, and the share does not own the pool liquidity that could fill its exit. This is a consequence of moving the pool principal outside the share, not proof that pool-position manipulation is generally solved. The separate fee position still carries ordinary LP and inventory risk.

2. **Answer the required one-transaction `getRate` question for the adopted design.** The draft says that MiniMax's live rate can move in one transaction, but does not state the adopted rate's behavior. The settled rate is a settled-balance-to-supply ratio. No same-pool trade can move it because the rate path does not read the pool. A caller can still bundle an authorized state change with a read: a deposit changes both settled balance and supply and can move the ratio through issuance rounding; an authorized target-fee credit changes the balance without minting shares; redemption changes both quantities with floor rounding. The final should say which of these can move the returned rate and that no market-price manipulation path exists for it.

3. **Correct the hook-law wording.** “Another hook can hold this share and value it as raw balance, or as balance times a rate provider” is too broad for this share. If another hook holds this vault share as a buffered leg, the leg token is the share and the Standard Exchange is this vault, so they differ and a rate provider is mandatory. Raw-balance valuation is for an identity leg. The provider may return settled target per whole share and must fail closed on revert, a short return, or zero, but the draft should not leave the impression that the buffered share can use the raw-balance branch without a provider.

4. **Do not turn “no settled response established” into an impossibility claim.** The draft should distinguish three propositions:

   - No opened public design was found that satisfies every stated constraint.
   - The adopted settled-target claim is one member's closest design and explicitly breaks two constraints.
   - MiniMax's response did establish a different design that keeps depositor-funded pool principal in the share and keeps `getRate` as an actual withdrawal-and-sale preview, while retaining the prior manipulation mechanisms and requiring a genuinely frozen TWAP observation that the current target does not provide.

   The first proposition is compatible with the second and third. Saying that the stronger design “cannot be valued through a rate another hook can trust” adds a trust requirement that the brief did not state. Under the locked law, a rate provider may expose the live sale preview; the resulting hook value inherits that preview's manipulation exposure, which the answer should disclose rather than use as an unstated disqualifier.

5. **Keep the deposited-liquidity break adjacent to the fee-exposure break.** The draft correctly says that the deposited target is not pool principal and that a separately funded position earns fees. The final should also make clear that the depositor's target remains idle settled backing, that its own deposit does not cause fee-earning liquidity to be deployed, and that the separately funded position's principal, impermanent loss, and capital source are outside the share's backing. This prevents “holders earn pool fees” from implying that the holder's deposit funds the position.

6. **Specify how target-fee credits are distinguished from donations.** The rule that a bare transfer does not increase `A` is necessary but incomplete. The final should state that `A` increases only from an authorized harvest or accounting path that recognizes an actual target-token fee delta, not from an arbitrary target transfer to the vault. This matters because the settled claim and its downstream rate depend on that distinction.

7. **Retain the exact two breaks in the final answer.** The draft is strongest because it says that the adopted design does not expose holders to the other token's LP fees and that its `getRate` is not a withdrawal-and-sale preview. The final should not soften either break by calling the no-sale preview a “withdrawal preview” without immediately restating that it violates the brief's specified meaning, and it should not describe target-fee-only credit as complete fee exposure.

## What was not adopted from others

- I did not adopt the settled-target claim as a complete answer to the original question. I accept it as one member's closest design only if the final retains both named breaks and does not treat the draft or the member count as a vote.
- I did not adopt an implicit “trustworthy enough for another hook” threshold beyond the locked held-reserve law. The live sale-preview design is law-consumable and manipulation-exposed; that exposure should be stated, not converted into a legal disqualifier.
- I did not withdraw my acceptance of the prior report's price-free per-component acceptance identity. I also do not adopt any stronger post-sale immunity claim; the prior disagreement remains.
- I did not adopt claims about the THORChain Savers page, Bancor pages, Bunni repository, or Bunni incident that the coordinator did not re-fetch. They may remain attributed member observations, but I do not rely on them.
- I did not adopt raw-balance valuation for the buffered share leg. The rate-provider requirement should be explicit.

## Limits

- This review is advisory. It is not a veto, a revised member response, a coordinator instruction, or implementation authority.
- I did not read peer feedback or peer response files for this review. I read only the coordinator draft and my own original response.
- I did not execute the settled-target mint arithmetic, the MiniMax mint arithmetic, a Forge trace, or a production Wings lifecycle.
- The matching digest verifies the reviewed bytes only; it does not validate the draft's source characterization or arithmetic.
- My original response remains unchanged, and this feedback does not authorize edits to the draft, `RUN.md`, peer files, project code, tests, configuration, or Git.
