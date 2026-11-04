# Settled three, not a draft

Written while Grok's initial task was still running and had no response file. Do not publish this as the recommendation.

## The fork

The three settled responses answer different readings of "use this liquidity."

| Member | Who holds the LP principal | How the share is minted | Single-token exit | Constraint the member names |
| --- | --- | --- | --- | --- |
| astra | A separate sponsor. Depositors hold reserved T plus assigned T-denominated LP fees. | `floor(D * S / A)` against T backing. No pair price. | Pay T from the reserve and collected T fees. No sale of the other token. | The deposited T is not reused as AMM principal. |
| minimax | The vault, in the underlying V4 pool. | `floor(S * D / (max(V(spot), V(old TWAP)) + D))`. This uses a same-pool price on the whole book. | Harvest, then sell only the redeemer's non-target slice. Revert if target cannot be delivered. | Does not claim the pool-price exposure is gone. |
| kimi | The vault, Wings-shaped positions plus idle sleeves. | Price-free per-component join, `m = floor(lambda * S)`, unmatched tokens refunded in kind. | Sell only the redeemer's opposing slice, or let the holder take that slice in kind. | A strictly single-token deposit is not the accounting act. An unpriced zap sits outside issuance. |

## What must not be averaged

- Astra removes the prior quote, executed-price, and self-fill channels from the holder path by not putting the LP inventory in the share. That also means the share is not the liquidity the user asked to use, unless "use" means only a fee claim another hook can hold.
- MiniMax keeps the liquidity in the share and prices the untraded book. The prior report's executed-price rows are about that class of mint. A `max(spot, old TWAP)` haircut is not the same rule as those rows, and the current TWAP source is not the frozen observation MiniMax requires. Do not treat the haircut as a settled repair.
- Kimi keeps the liquidity in the share and removes the pool price from minting. The prior report adopted that acceptance identity and did not adopt post-sale immunity. Kimi's `getRate` is still a live one-share sale preview, so one transaction can move the number another hook would read.

## Still missing

Grok. No response file at the time of this note.
