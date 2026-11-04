# Coordinator draft

- Draft ID: draft-apex-012-deposit-process-20261024-r1
- Path: `docs/reviews/apex-012-deposit-process-20261024/coordinator/draft.md`
- Run: apex-012-deposit-process-20261024
- Coordinator: invoking agent. Not an extra vote.

## Participation

| Label | Task | Status |
| --- | --- | --- |
| astra | st_01a16e5b | completed |
| grok | st_01a16e5c | completed |
| minimax | st_01a16e5d | completed |
| kimi | st_01a16e5e | completed |

## Agreed

All four agree on the first two answers.

The prior review treated a deposit as a sale of target because the PRD Entry section says so. Line 43 says a two-sided entry swaps part of the deposit into the other token. That sentence was not read out of `_deposit`. The prior questions about gross versus net credit assumed that sentence. They are not evidence that the code sells target.

The existing deposit does not sell target for the other token. `_deposit` pulls target, harvests, reads `Quote.quote`, mints, credits the gross target, and places. Harvest's header says an ordinary harvest never swaps. `_swapDeficit` sells the other token for target, and only `_redeem` reaches it through `_fund`.

## Not agreed

Removing `Quote.quote` and keeping the rest is not agreed to be valid.

- Kimi: the only preserved-ruling violation is that `_place` can open a new range for an empty slot while supply is positive. The fix is to place only into slots that already have liquidity and leave the rest idle. Mint `supply == 0 ? assets : supply * assets / settledTarget`, then credit the gross deposit. No entry swap. The gift sentence is not a preserved owner ruling. It is open question 2.
- MiniMax: a target-only mint into a position that already holds the other token gifts that other token. The smallest process that keeps the owner's no-sale correction is to revert that deposit. A two-sided target-only deposit cannot satisfy both a share of the whole position and no gift. Do not add a swap unless the owner approves it.
- Grok: the same gift is arithmetic. Any positive fungible mint gives the new holder a slice of other token already held. No denominator inside the unchanged sequence removes that claim. The smallest process that still completes the deposit is an entry swap when other-token inventory is positive, sized so the bought other token matches the existing ratio, then mint on that bought amount. If the swap does not increase vault-owned other token, revert. When other-token inventory is zero, keep the existing sequence without a swap.
- Astra: proportional addition to every existing position cannot be funded in target alone when one position needs the other token. The smallest structural fix is an entry swap to buy that missing token, then add the same fraction to every existing position and to idle. Rejecting a deposit that cannot fund that fraction without a swap is a smaller no-swap operation, and it disables mixed-book entry.

The gift sentence and the proportional-addition sentence are in the PRD. The owner has now rejected the entry swap those sentences were written to require. The council does not agree which of those sentences still binds.

## Owner decision this draft does not make

1. Keep the existing target-only deposit, minus the quote. A new holder receives a fraction of other token already held. Do not add an entry swap.
2. Keep the target-only deposit only when the position holds no other token. Otherwise revert.
3. Add an entry swap when the position already holds the other token, despite the correction, so the depositor buys the other token their share will claim.

This draft does not pick one. It does not invent a fourth process.

## Limits

Static reading. No Forge run. Advisory review has not happened.
