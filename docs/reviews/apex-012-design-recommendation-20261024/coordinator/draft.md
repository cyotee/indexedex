# Coordinator draft

- Draft ID: draft-apex-012-design-recommendation-20261024-r1
- Path: `docs/reviews/apex-012-design-recommendation-20261024/coordinator/draft.md`
- Run: apex-012-design-recommendation-20261024
- Coordinator: invoking agent. Not an extra vote.

## Participation

| Label | Task | Status |
| --- | --- | --- |
| astra | st_01a16e83 | completed |
| grok | st_01a16e84 | completed |
| minimax | st_01a16e85 | completed |
| kimi | st_01a16e86 | completed |

## What all four refuse

- A live same-pool liquidation quote as the share price.
- One mark for the rate and a different zap for the redemption.
- A single-sided target range as the fee reserve.
- An external oracle or TWAP as the rate.
- A view that sells, or that previews a sale through current depth.
- Different prices for V3 and V4. Adapters may differ. The rule may not.

All four also agree the reserve that earns fees will hold the other token, and that other token is absent from the published rate until a real conversion delivers target.

## No single recommendation

The four designs are two families. They are not one design with wording differences.

### Family A: the rate is the payout

Astra and Grok. Deposit, redeem, and `getRate` use only settled target and supply. The trading position is not what a share is priced or paid in.

- Astra settles the whole portfolio to target on an epoch, in a later transaction than the sale, then deals deposits and redemptions at that cash. It then reinvests. No mint or target payout while mixed inventory remains.
- Grok keeps a full-range position as vault property. Allocate spends settled target to open it. Convert sells other token and credits delivered target. Deposit and redeem run only when that inventory is closed, and not in the same block as allocate or convert. A redeem pays `settledTarget * shares / supply` and does not touch the pool.

Cost of this family: you do not earn fees and take new money in the same state. The published rate is payable target, not the liquidation value of the position. It falls when target is spent to seek fees.

### Family B: the share is the position

MiniMax and Kimi. A share is a fraction of the live ranges. Deposit and exit can run while the reserve is earning. Exit removes that fraction and sells only that slice's other token. The holder is paid the target that sale delivered.

Both still publish `settledTarget * 1e18 / supply`. Both say that number is not the exit proceeds. Kimi says the difference runs in both directions. MiniMax calls the rate a floor.

That is a rate and a different exit price. The brief rejected that split. This draft does not adopt Family B as the recommendation that meets the one-rule constraint.

Family B also reintroduces an entry conversion when the book already holds the other token. The owner rejected describing the current deposit as that sale. These members say the goals require it if a new holder must buy a matching slice. That is a proposal, not a reading of today's `_deposit`.

## What this draft recommends, and what it does not

If deposit, redeem, and the rate must be one number, the council's designs that satisfy that constraint are Family A. This draft does not choose between Astra's epoch auction and Grok's allocate/convert window. Both meet the constraint. They differ in machinery and in whether the position must be fully closed before any dealing.

This draft does not recommend Family B unless the owner accepts that the published rate is not the exit price.

## Limits

Static reading of the four responses. No Forge run. Advisory review has not happened. This draft does not authorize implementation.
