# Council report — fee-earning single-token reserve

- Run: apex-012-design-recommendation-20261024
- Profile: research
- Council kind: full
- Coordinator: invoking agent. Not an extra vote.
- Draft reviewed: draft-apex-012-design-recommendation-20261024-r1
- This final is a coordinator revision. It is not member-approved text.
- This report does not authorize implementation.

## Participation

| Label | Task | Feedback |
| --- | --- | --- |
| astra | st_01a16e83 | requested-changes |
| grok | st_01a16e84 | requested-changes |
| minimax | st_01a16e85 | support-with-reservations |
| kimi | st_01a16e86 | support-with-reservations |

## Shared refusals

- No live same-pool liquidation quote as the share price.
- No external oracle or TWAP as the rate.
- No single-sided target range as the fee reserve.
- No view that sells, or that previews a sale through current depth.
- Temporary liquidity and an in-transaction price move must not mint shares or move the rate.
- No different price rule for V3 and V4. Adapters may differ.

The reserve that earns fees will hold the other token. That token is not newly valued in the published rate until a real conversion delivers target.

## The council does not have one machine

Two families came back. They are not wording variants of one design.

### Family A: the published number is what a dealing pays

Deposit, redeem, and the rate use settled target and supply. The live trading position is not priced or paid as a zap.

**Astra.** The vault holds the LP. On a schedule it removes the portfolio, sells the other token, and publishes a price only after the target has arrived, in a later transaction than the sale. Deposits and redemptions of that cohort deal at that one ratio. Between settlements the published rate stays at the last completed settlement. It does not fall when target is spent to reopen the position. Dealing is closed in that interval. The old cohort owns the realization, including other-token principal and fees, and bears the loss. Pending deposits stay segregated. Time separation stops a same-transaction pool move from setting the dealing inputs. It does not stop a bad auction or a multi-block manipulation.

**Grok.** The fee reserve is a full-range position held as vault property. Allocate spends idle settled target to open it. Convert sells other token and credits only the target delivered. The rate is idle target per share. It falls when target is spent to seek fees. Uncollected target fees are absent until harvest delivers them. A new deposit waits until the position is closed, and must not share a block with allocate or convert. A non-final redeem may pay `settledTarget * shares / supply` while the position is open. It does not touch the pool. That holder forfeits the unsold inventory to the remaining shares. The last holder must convert in a prior block, then exit at the updated counter.

### Family B: the share is the live position

MiniMax and Kimi. A share is a fraction of the ranges. Deposit and exit can run while the reserve is earning. Exit removes that fraction, sells only that slice's other token, and pays the target removed from the slice plus the target the sale delivered. The remaining position may fill that sale.

Both still publish `settledTarget * 1e18 / supply`. Both say a redeemer does not receive that number. Kimi says the sale's actual proceeds write the same counter, so this is one ledger rather than a previewed quote. MiniMax says neither path computes a price: the rate is stored target, and the exit is a real swap. Both reintroduce a sale of deposited target when the book already holds the other token, so the new holder buys a matching slice. That is a new process. Today's deposit does not do it.

The cost is that the published rate is not the exit proceeds. Kimi says the difference runs in both directions. MiniMax calls the rate a floor. Temporary liquidity does not mint shares, because the mint is from token amounts, not from a quote.

## What meets the constraint

If the requirement is that the number a holder can read is the number a redeem pays, Family A is the set that meets it. Family B meets a weaker reading: one ledger, with the exit amount set by a real sale rather than by that ledger's current ratio. Kimi's distinction is real. An executed sale is not the rejected preview quote. It is still not the same payout as the published rate.

This report does not choose Astra's epoch or Grok's window. It does not choose Family B for the owner.

## Limits

Static reading. No Forge run. No implementation authority.
