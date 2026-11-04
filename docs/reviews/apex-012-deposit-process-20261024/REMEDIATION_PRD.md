# Council report — deposit sale premise

- Run: apex-012-deposit-process-20261024
- Council kind: full
- Coordinator: invoking agent. Not an extra vote.
- Draft reviewed: draft-apex-012-deposit-process-20261024-r1
- This final is a coordinator revision. It is not member-approved text.
- This report does not authorize implementation.

## Participation

| Label | Task | Feedback |
| --- | --- | --- |
| astra | st_01a16e5b | requested-changes |
| grok | st_01a16e5c | support-with-reservations |
| minimax | st_01a16e5d | support-with-reservations |
| kimi | st_01a16e5e | support-with-reservations |

## Agreed

The prior review treated a deposit as a sale of target because the PRD Entry section says a two-sided deposit swaps part of the target into the other token. That sentence is not in `_deposit`. The questions that assumed target spent in an entry swap were questions about that sentence. They are not evidence that the code sells target.

The existing deposit does not sell target for the other token. The order is: pull target, harvest, read `Quote.quote`, compute shares, credit the gross target, mint the shares, place. Harvest's header says an ordinary harvest never swaps. `_swapDeficit` sells the other token for target, and only a redeem reaches it.

Question 1 is invalid while it assumes that sale.

## Not agreed

Removing the quote and keeping the rest is not agreed to be valid. The members used different rulings.

- Kimi: the preserved violation is that placement can open a new range for an empty slot while supply is positive. Place only into slots that already have liquidity. Leave the rest idle. Mint `supply == 0 ? assets : supply * assets / settledTarget` and credit the gross deposit. No entry swap. The gift sentence is not a preserved owner ruling.
- MiniMax: a target-only mint is valid when the position holds no other token. When it already holds the other token, that mint gives the new holder a slice of it. Under the no-sale correction, that deposit reverts unless the owner approves a conversion. Quote removal also leaves `Accounting.issue` without a denominator, and the mint happens before placement, so the mint cannot be "liquidity actually added."
- Grok: any positive fungible mint gifts pre-existing other token. No denominator inside the unchanged sequence removes that claim. The process that still completes the deposit swaps deposited target for other token when that inventory is positive, sized so retained target and the increase in vault-owned other token match the pre-add ratio, then mints on that increase and credits retained target. If vault-owned other token does not increase, revert. When other-token inventory is zero, keep the existing sequence without a swap. Do not size that swap with `Quote.quote`, a simulated book sale, or `slot0`.
- Astra: the decisive ruling is proportional addition to every existing position, not the gift by itself. A target-only deposit can grow one slot and leave another unchanged. The repair freezes the existing ranges, does not open an empty slot, adds one common fraction to every existing position and to idle, and swaps only when that fraction needs other token the depositor did not supply. Rejecting a deposit that cannot fund the fraction without a swap is a smaller no-swap operation, and it disables mixed-book entry. An entry swap does not by itself satisfy the temporary-liquidity equality sentence.

## What rides with every choice

Whichever deposit rule is chosen, a later deposit must not open a new range. Placement into an empty slot is a separate defect from the sale premise. Skipping that slot and leaving the target idle is the fix named for it.

## Owner choice

The correction rejects the claim that the current deposit sells target. It makes the existing process the reference unless a ruling makes that process invalid. It is not, by itself, a ban on a future swap that names the ruling it repairs.

1. Keep the target-only deposit, minus the quote, and do not open a new range. A new holder receives a fraction of other token already held. This drops the gift sentence and the proportional-add sentence.
2. Keep that deposit only while the position holds no other token. Otherwise revert.
3. When the position already holds the other token, swap deposited target for other token before the mint, under the constraints in the Grok and Astra bullets. This is a new process. It is not what `_deposit` does.

No member selected an option. This report does not select one.

## Limits

Static reading. No Forge run. V3 Wings source does not exist.
