# Coordinator draft

- Draft ID: draft-apex-012-prd-clarity-20261024-r1
- Path: `docs/reviews/apex-012-prd-clarity-20261024/coordinator/draft.md`
- Run: apex-012-prd-clarity-20261024
- Profile: review
- Coordinator: invoking agent. Not an extra vote.
- Question: Is the APEX-2026-012 PRD clear enough that two implementers would build the same V3 and V4 Upper Lower Wings accounting?

## Participation

| Label | Task | Initial status | Response |
| --- | --- | --- | --- |
| astra | st_01a16e2b | completed | `members/astra/response.md` |
| grok | st_01a16e2c | completed | `members/grok/response.md` |
| minimax | st_01a16e2d | completed | `members/minimax/response.md` |
| kimi | st_01a16e2e | completed | `members/kimi/response.md` |

All four requested initials settled. This is a full council, not a partial. No peer response was treated as runtime proof. Static reading only.

## Verdict

No. Two implementers would share the economic policy and would not share the contracts.

Agreed and preserved: a share is a fraction of the position, not a quoted pile of target. Deposit and redeem do not use a live whole-book liquidation quote. The vault accepts and pays only target. An exit sells only that holder's other token through the same pool, and the remaining position may fill that sale. `getRate` is a settled target counter over supply, not `slot0` and not a preview of an unsold sale. Other token is sold only on the acting holder's entry or exit. Harvest does not sell the other token. A new V3 Wings family is required. V3 FullSpread stays. Deployed vaults are not upgraded.

## Agreed defects

All four found the same blockers. Locators were checked against the PRD and, where cited, the V4 sources.

1. **No share-mint equation.** Entry says shares come from liquidity added against the position that existed before the add. It does not say whether that is one ratio across core plus both wings, the minimum slot ratio, or a target-balance ratio. Idle balances are inside the position definition and outside the mint sentence.
2. **Line 43 and the temporary-liquidity test cannot both hold as written.** Minting from liquidity actually added makes a two-sided entry depend on pool depth, because the entry swap's other-token output depends on depth. The same deposit then mints more shares if an outsider adds liquidity for the call. The PRD also says that must not happen. Astra, Grok, MiniMax, and Kimi all recorded this conflict.
3. **`settledTarget` has a read formula and no transition.** Gross deposit credit, credit net of target spent in the entry swap, and a rewrite from tokens still held are different rates. An exit filled by the remaining position both pays target and moves target through the pool. The prose does not pick a debit.
4. **Idle and the liquid sleeve are unnamed.** Current V4 keeps an idle target sleeve. The PRD defines the position as liquidity plus idle, then pays an exit from burned liquidity plus swap proceeds. Paying pro-rata idle and leaving the sleeve with remaining holders are different redemptions.
5. **Entry swap size is "part of that deposit."** That does not choose a pre-swap ratio, a post-swap ratio, or a solved amount. A position that is single-sided in the other token is not covered. Whether the vault's own liquidity may fill the entry swap is stated for exit and not for entry.
6. **Exit protection is a prohibition.** The text forbids `MIN` and `MAX` price limits that ignore the slice. It does not say what limit replaces them, whether `minimum` is total target paid or swap output alone, or whether a partial sale of the slice may succeed.
7. **The V3 family is a name.** Accounting is required. Geometry, custody, bootstrap, fee, and interface parity are not. A full-range core and a narrow core produce different ratios for the same deposit.
8. **Harvest and rebalance contradict the sell ban if left unchanged.** Harvest must not sell. Current harvest also closes a converted wing and re-places inventory. The PRD says rebalance is unchanged and also says no function may sell the other token. Current rebalance can sell it. Both sentences cannot stand.
9. **Quote and exact-route surfaces are unnamed.** `getRate` moves to the counter. `quoteRate(state_)`, `liquidationValue`, transition quotes, and exact-output `exchangeOut` are not given a disposition. Leaving them on the old quote keeps a second valuation. Dropping them changes the interface.

MiniMax's claim that `contracts/vaults/standard/exchange/protocols/uniswap/UNISWAP_V3_V4_STANDARD_EXCHANGE_REMEDIATION_PRD.md` still requires a V2-style constant-product model was re-read. Line 13 of that file does say new V3 and V4 Standard Exchange vaults must use that model. The 012 PRD does not say it supersedes that sentence. That conflict is real. It is not a reason to invent a third model.

## Requirements questions

These are the questions whose answers change the contract. Duplicates across the four responses are collapsed. Alternatives are the divergence, not a recommendation.

1. **Counter equations.** After a deposit that spends some target in the entry swap, is `settledTarget` credited the gross deposit, or the deposit net of target spent? On an exit, is it debited only the target paid to the redeemer, or does it also credit swap proceeds and then debit the payout? When the remaining position fills the sale, is the target that left through the pool a separate debit? When supply hits zero, is the counter cleared? Smallest close: one equation per operation, and a statement that the counter is never copied from live holdings.

2. **Mint basis, and which sentence wins.** Is the mint `shares * liquidityAdded / liquidityBefore`, summed across core and both wings, before the add? If yes, temporary liquidity can change the entry swap's output and therefore the shares, which breaks the "must not increase" sentence. Which sentence governs a two-sided deposit? What is the rounding direction, and is test 1 exact or tolerant of one unit?

3. **Idle and the sleeve.** Does a share include idle balances? Does an exit pay `s / S` of idle target? Does the existing liquid-reserve sleeve remain, so part of a deposit stays idle?

4. **Entry swap.** What amount is swapped? May the size be computed from the current tick on both families? May the vault's own liquidity fill that swap? What does a deposit do when the position is single-sided in the other token?

5. **Exit execution.** Is `minimum` the total target paid, or the swap output alone? Is the sale exact-input of the entire other-token slice, reverting if any remains unsold? What price limit replaces `MIN` and `MAX`?

6. **Uncollected fees.** On burn, are fees part of the slice that is paid and sold, or do they stay with the remaining position?

7. **First deposit.** What opens the initial ranges, how many shares does the first target deposit mint, and what is `settledTarget` after it? This does not have to close the deferred dead-share item.

8. **Harvest mutations.** Besides crediting collected target fees, may harvest close a converted wing and re-place inventory? Do deposit and redeem still harvest before they mint or burn?

9. **Rebalance.** Does the sell ban override the existing rebalance swap, or does rebalance stay unchanged and remain allowed to sell the other token?

10. **Other surfaces.** For each of `quoteRate(state_)`, `liquidationValue`, transition quotes, `exchangeRate`, and exact-output `exchangeOut`: does it execute or report the new accounting, or is it a labeled non-executing preview? Exact-output `exchangeOut` does not match "redeem `s` shares with a minimum target out" unless one of them is restated.

11. **V3 family.** Does V3 copy the V4 Wings geometry, fee policy, and facet surface, with V3 pool calls? If not, which document specifies those facts?

12. **Older mandate.** Does this PRD supersede the constant-product sentence in `UNISWAP_V3_V4_STANDARD_EXCHANGE_REMEDIATION_PRD.md` for these two Wings families? That file was re-read. The 012 PRD does not mention it.

13. **Locked pool.** When the V4 pool manager is unlocked, or the V3 pool is locked, do deposit and redeem revert? The PRD says an unlocked manager does not make `getRate` a live quote. It does not say whether the money calls revert.

## Already decided

Do not reopen these. The owner already selected them.

- Other token converts only on the acting holder's entry or exit.
- Harvest does not sell the other token and does not set the rate from the current tick.
- Build a new V3 Wings family. Do not convert or delete V3 FullSpread.
- A share is a fraction of core and both wings. A later deposit does not open a new range.
- Remaining holders may take the exit sale. Tests prove share fraction, not a constant target balance.
- `getRate` does not read `slot0` and does not preview an unsold sale.
- Deployed vaults are not upgraded. This review does not authorize implementation.

## Disagreement

No member said the PRD was implementation-complete. Astra listed 21 questions, Grok 15, MiniMax 10, Kimi 11. The extra items are narrower cases of the thirteen above, not a different verdict. Astra alone asked whether test 2's numerical inequality is mandatory. That is a test-wording fix, not a separate product question. MiniMax's constant-product citation is confirmed. No member proposed a different economic design.

## Limits

Static reading. No Forge run. V3 Wings source does not exist, so the V3 half cannot be checked against code. This draft does not edit the source PRD. Advisory review has not happened. Silence after this draft is not approval.
