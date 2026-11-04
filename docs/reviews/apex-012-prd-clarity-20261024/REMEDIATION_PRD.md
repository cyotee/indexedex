# Council report — APEX-2026-012 PRD clarity

- Run: apex-012-prd-clarity-20261024
- Profile: review
- Council kind: full
- Coordinator: invoking agent. Not an extra vote.
- Draft reviewed: draft-apex-012-prd-clarity-20261024-r1
- This final is a coordinator revision after advisory feedback. It is not member-approved text.
- This report does not authorize implementation and does not edit the source PRD.

## Participation

| Label | Requested model | Task | Initial | Feedback |
| --- | --- | --- | --- | --- |
| astra | `chatgpt-subscription/gpt-6-astra:high` | st_01a16e2b | completed | requested-changes |
| grok | `xai/grok-4.7:xhigh` | st_01a16e2c | completed | requested-changes |
| minimax | `minimax/MiniMax-M3` | st_01a16e2d | completed | support-with-reservations |
| kimi | `kimi-coding/k3:high` | st_01a16e2e | completed | support-with-reservations |

All four requested initials and all four requested feedback files settled. Session IDs were not exposed.

## Coverage

| Target | Status |
| --- | --- |
| `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` | examined by all four |
| Tracker section `APEX-2026-012` | examined as context |
| V4 Wings sources needed to check locators | partially examined as context |
| V3 Wings source | absent. The family does not exist. |
| Runtime | not examined. No Forge run. |

## Verdict

No. Two implementers would not build the same contracts.

They share the prohibitions and the scope rulings. They do not share the accounting equations. All four recorded a missing mint basis. The direct conflict between minting from liquidity actually added and the temporary-liquidity sentence was explicit in a subset, and the contradiction itself stands.

Preserved owner rulings:

- Other token is sold only on the acting holder's entry or exit. Harvest and rebalance do not sell it.
- A share is a fraction of every position the vault holds, including idle balances. A later deposit does not open a new range.
- `getRate` and `quoteRate` read the settled counter and supply. They do not read `slot0` and do not preview an unsold sale.
- `liquidationValue` may remain only as a labeled preview that does not mint, burn, or set the rate.
- Build a new V3 Wings family. Do not convert or delete V3 FullSpread.
- The remaining position may fill an exit sale. Tests prove share fraction, not a constant target balance.
- Deployed vaults are not upgraded.

## Requirements questions

These are the questions whose answers change the contract, the tests, or the vault. Alternatives show the divergence. They are not recommendations.

1. **Counter.** After a deposit that spends some target in the entry swap, is `settledTarget` credited the gross deposit or the deposit net of target spent? On exit, what is the exact debit when the redeemer is paid and the remaining position fills the sale? Does the credit for a swap the vault executed include the LP fee the vault earns on that same swap? When supply hits zero, is the counter cleared? If an allowed debit would exceed the stored counter, does the call revert, or is another rule required? Internal moves between idle and liquidity are not counter events unless the equation names them. The counter is never copied from live holdings.

2. **Mint.** What per-slot equation preserves a common fraction of each existing position? A summed liquidity ratio and a target-balance ratio are not substitutes for that fraction. What happens to a slot with zero liquidity while supply is positive? Skipping it, reverting, and opening a range are different, and opening a range is already forbidden for a later deposit. What is the rounding direction, who owns the residual, and what happens if the input rounds to zero shares or a redemption rounds to zero liquidity? For a two-sided deposit, which rule wins: minted shares are equal with and without temporary liquidity, shares must not increase, or shares follow liquidity actually added? Equality also forbids a decrease. Test 3's window must match the rule that wins.

3. **Idle, already owned.** Accounting already includes idle in the position. Exit currently pays burned liquidity plus swap proceeds. Which payout implements the idle ownership: pro-rata idle target and idle other, or burned liquidity only? Is unused deposit target refunded or booked as idle? Does the existing liquid-reserve sleeve remain, so part of a deposit stays idle?

4. **Entry swap.** What amount is swapped? May that size be read from the current tick on both families? May the vault's own liquidity fill the entry swap? When is a three-slot book two-sided: the aggregate, or one slot? A mixed core with single-sided wings is the normal Wings state. What does a deposit do when the position is single-sided in the other token? Which snapshot fixes old holders' entitlement: before the swap, or after the vault fills it?

5. **Exit.** Is `minimum` the total target paid, or the swap output alone? Must the whole other-token slice be sold, or may a partial sale succeed? What price limit replaces `MIN` and `MAX`? Are the shares burned before the swap or after it? On V3, may redeem read the current tick to split the removed slice? A literal reading of the `slot0` ban makes that split impossible. A valuation-only reading does not.

6. **Fees and donations.** Do uncollected fees that accrued before entry belong to the old holders? Do fees created by the acting holder's own swap belong to the remaining position? Are other-token fees part of the slice that is sold? If a completed target-fee collection happens during an add or burn, must the counter be credited, or only during an explicit harvest? A direct token transfer and fee growth later collected as target fees are different events. Which of those is covered by this PRD, and which stays with the open 040 item?

7. **First deposit and a later empty slot.** What opens the initial ranges, how many shares does the first target deposit mint, and what is `settledTarget` afterward? If supply is already positive and a slot is empty, or the holdings are entirely idle, what may entry do without opening a new range?

8. **Harvest.** Besides crediting collected target fees, may harvest close a converted wing and place the tokens again? If it may, does that change `settledTarget` or any holder's fraction? Do deposit and redeem harvest before they mint or burn? If a wing is not closed, are other-token fees left uncollected, booked idle, or compounded into liquidity?

9. **Rebalance path.** The sell ban stands. The current rebalance executes a swap. Is that swap removed, or does rebalance revert until a later change? The 025 loss-cap finding stays open either way.

10. **Exact routes.** `depositExactShares`, `redeemExactAssets`, `requiredInput`, and exact-output `exchangeOut` still price from the quote. Do they move to the new execution, or become unavailable? If `exchangeOut` stays exact-output, what are the executed input, maximum input, refund, and surplus rules? `quoteRate` reads the counter. Does a supplied `state_` get ignored, or does the call revert? It does not value a projected book. `liquidationValue` may remain as a non-executing labeled preview.

11. **V3 surface.** Does the new family copy the V4 Wings geometry, fee policy, and facet surface, using V3 pool calls? If not, which document specifies those facts?

12. **Precedence.** `UNISWAP_V3_V4_STANDARD_EXCHANGE_REMEDIATION_PRD.md` line 13 requires a V2-style constant-product model for new V3 and V4 Standard Exchange vaults. The 2026-10-15 header says the other requirements in that document remain in force and names Upper/Lower Wings as a supported V4 consumer. Does the 012 PRD govern these two Wings families instead? This is a precedence question. It is not a third model, and it does not touch V3 FullSpread.

13. **Locked pool.** When the V4 pool manager is already unlocked, or the V3 pool is locked, do deposit and redeem revert?

14. **Test 2.** The proof is that payout equals target removed from the slice plus target the swap delivered, and that this result does not come from the forbidden quote. A required numerical inequality is not that proof, because a correct execution can land on the comparison value.

## Advisory outcome

Astra and Grok requested changes. MiniMax and Kimi supported the draft with reservations. The changes above carry those concerns. Absence of a further round is not approval. No member proposed a different economic design.

## Limits

Static reading only. No Forge run. V3 Wings source does not exist. The source PRD was not edited.
