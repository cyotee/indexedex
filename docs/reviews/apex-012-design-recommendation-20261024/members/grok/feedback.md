# Member feedback

## Identity

- Run ID: apex-012-design-recommendation-20261024
- Member label: grok
- Profile: research
- Phase: advisory feedback
- Owned path: docs/reviews/apex-012-design-recommendation-20261024/members/grok/feedback.md
- Draft ID: draft-apex-012-design-recommendation-20261024-r1
- Draft path: docs/reviews/apex-012-design-recommendation-20261024/coordinator/draft.md
- Compared against: docs/reviews/apex-012-design-recommendation-20261024/members/grok/response.md
- Peers read before this feedback: no
- This file does not pick a family for the owner.

## Draft reviewed

draft-apex-012-design-recommendation-20261024-r1

## Disposition

requested-changes

The Family A grouping is fair on the one-rule axis: deposit, redeem, and `getRate` use only settled target and supply, and the trading position is not what a share is priced or paid in. The Grok bullet misstates when redeem may run. That sentence has to be corrected before the two Family A machines can be compared. This feedback does not choose between them, and it does not ask the draft to choose.

## Concerns

The draft says Grok's deposit and redeem run only when inventory is closed. Deposit does. Redeem does not.

Deposit reverts while booked other token is nonzero or the fee position has liquidity, and in the same block as allocate or convert. A non-final redeem pays `settledTarget * shares / supply`, does not touch the pool, and may run while the full-range position is open. The holder forfeits unsettled inventory to the remaining shares. Only a redeem that would leave supply at zero while booked other token or position liquidity remains reverts, and that holder must convert in a prior block, then exit at the updated counter. Redeem, like deposit, must not share a block with allocate or convert.

That forfeiture is a constraint the draft drops. Replacing it with Astra's "no target payout while mixed inventory remains" makes the two machines look alike on the point the draft later says they differ on. "Whether the position must be fully closed before any dealing" is the right difference only after the Grok bullet is fixed. As written, the bullet erases it.

Correct the bullet to: deposit only when inventory is closed; non-final redeem may pay the counter during exposure and forfeit the rest; terminal redeem reverts while inventory remains; neither deposit nor redeem shares a block with allocate or convert. Keep the payment formula and the "does not touch the pool" clause. Those are right.

What the draft does not misstate, and should keep: the share is settled target, not a fraction of the position; the fee reserve is a full-range position held as vault property; allocate spends settled target to open it; convert credits only target delivered; the rate is payable target, not liquidation value, and it falls when target is spent to seek fees; fees and new deposits do not share a state. The shared refusals match the constraints this response treated as binding: no live quote, no split between rate and zap, no single-sided target range as the fee reserve, no oracle or TWAP rate, no view that sells or previews a sale, no V3/V4 split in the rule.

The shared absence sentence is narrower than the constraint this response stated. Other token is absent until convert delivers target. Uncollected target fees are also absent until harvest delivers them into idle. Target already spent into the position is absent until a withdrawal delivers it. The family cost states the spend. It does not state the harvest gap. If the final text describes this design, keep both.

This feedback does not confirm the Astra, MiniMax, or Kimi summaries. Their response files were not read. Nothing here selects Family A, Family B, the epoch machine, or the allocate/convert window for the owner. The draft is right not to adopt Family B as a design that meets the one-rule constraint, and right not to choose inside Family A. Those are statements about the constraint, not a vote.

## Limits

Compared the draft with this member's response only. No peer files, no Forge run, no edit to the draft or to response.md. Advisory. Not an implementation instruction.
