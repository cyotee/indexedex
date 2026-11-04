# APEX-2026-012 open questions

Recorded 2026-10-24 from the council review. Work these one by one. Do not treat an unanswered question as decided.

Status 2026-10-24: paused. The owner is reconsidering the vault design. The active question is the council recommendation in `docs/reviews/apex-012-design-recommendation-20261024/`. These questions are not the active path until that recommendation is accepted or rejected.

Source list: the questions stated after the council final. Longer form: `docs/reviews/apex-012-prd-clarity-20261024/REMEDIATION_PRD.md`.

PRD: `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`.

These questions do not reopen the rulings already made. Other token converts only on the acting holder's entry or exit. Harvest and rebalance do not sell it. A share is a fraction of every position, including idle. A later deposit does not open a new range. `getRate` reads the settled counter, not `slot0`. Build a new V3 Wings family. Do not convert or delete V3 FullSpread. Deployed vaults are not upgraded. Implementation is not authorized.

| # | Status | Question |
| --- | --- | --- |
| 1 | premise rejected | Counter. The owner rejected the premise that a deposit sells target for the other token. See the note under question 1. |
| 2 | open | Mint. |
| 3 | open | Idle. |
| 4 | open | Entry swap. |
| 5 | open | Exit. |
| 6 | open | Fees. |
| 7 | open | First deposit. |
| 8 | open | Harvest. |
| 9 | open | Rebalance. |
| 10 | open | Exact routes. |
| 11 | open | V3. |
| 12 | open | Precedence. |
| 13 | open | Locked pool. |

## 1. Counter

Owner correction, 2026-10-24: a deposit does not sell target for the other token. This question is invalid while it assumes that sale. The existing deposit process is the reference unless a council shows that process is invalid under the preserved rulings.

Existing V4 deposit, `UniswapV4UpperLowerWingsStandardExchangeVaultMoney._deposit`: pull target, harvest, quote the book, mint shares from that quote, credit local target, place liquidity. Harvest's own comment says ordinary harvest never swaps. The opposing-token sale is `_swapDeficit`, used while funding a redeem, not a deposit.

Council result, 2026-10-24: `docs/reviews/apex-012-deposit-process-20261024/REMEDIATION_PRD.md`. All four agree the sale premise came from the PRD Entry sentence, not from `_deposit`. They do not agree that the quote-removed sequence is valid. The owner has not chosen among keep-and-accept-the-fraction, revert when other token is already held, or add a conversion that names the ruling it repairs. A later deposit must not open a new range under every choice.

If a deposit spends some target buying the other token, is `settledTarget` credited the gross deposit or only the target kept? On exit, what is the exact debit when the remaining position fills the sale? Does that credit include the LP fee the vault earns on its own swap? When supply hits zero, is the counter cleared? If a debit would exceed the counter, does the call revert?

## 2. Mint

What equation gives every holder the same fraction of each existing position? A slot with zero liquidity, while supply is positive, is skipped, or does the call revert? Opening a range is already forbidden. For a two-sided deposit, which rule wins: the same shares with or without temporary liquidity, shares must not increase, or shares follow the liquidity actually added? Those three are different. Equality also forbids a decrease.

## 3. Idle

Idle is already part of the position. Does an exit pay a fraction of idle target and idle other, or only the burned liquidity plus the swap? Is unused deposit target refunded or left idle? Does the liquid-reserve sleeve stay?

## 4. Entry swap

How much is swapped? May that size be read from the current tick on both V3 and V4? May the vault's own liquidity fill it? When is a three-slot book two-sided, the aggregate or one slot? What happens if the position holds only the other token? Which snapshot fixes the old holders' claim, before the swap or after the vault fills it?

## 5. Exit

Is `minimum` the total target paid, or only the swap output? Must the whole other-token slice sell, or may a partial sale succeed? What price limit replaces `MIN` and `MAX`? Are the shares burned before the swap or after it? On V3, may redeem read the current tick to split the slice? A literal `slot0` ban makes that split impossible.

## 6. Fees

Do fees accrued before entry belong to the old holders? Do fees from the acting holder's own swap belong to the remaining position? Are other-token fees sold with the slice? If target fees are collected during an add or burn, must the counter be credited then, or only on an explicit harvest? A direct transfer and fee growth later collected as target are different. Which of those is this PRD, and which stays with the open 040 item?

## 7. First deposit

What opens the first ranges, how many shares does the first target deposit mint, and what is `settledTarget` afterward? If supply is already positive and a slot is empty, what may entry do without opening a range?

## 8. Harvest

Besides crediting collected target fees, may harvest close a converted wing and place the tokens again? If it may, does that change the counter or any holder's fraction? Do deposit and redeem harvest first? If a wing is not closed, are other-token fees left uncollected, booked idle, or compounded into liquidity?

## 9. Rebalance

The sell ban stands. The current rebalance executes a swap. Is that swap removed, or does rebalance revert until a later change? The 025 loss-cap finding stays open either way.

## 10. Exact routes

`depositExactShares`, `redeemExactAssets`, `requiredInput`, and exact-output `exchangeOut` still use the quote. Do they move to the new execution, or become unavailable? If `exchangeOut` stays exact-output, what are the input, refund, and surplus rules? Does `quoteRate` ignore a supplied state, or revert? It does not value a projected book.

## 11. V3

Does the new family copy the V4 Wings geometry, fee policy, and facet surface, using V3 pool calls?

## 12. Precedence

The older shared remediation PRD still requires a constant-product model for new V3 and V4 vaults, and its 2026-10-15 header still names Wings. Does this PRD govern these two Wings families instead? That is precedence, not a third model. V3 FullSpread stays either way.

## 13. Locked pool

If the V4 pool manager is already unlocked, or the V3 pool is locked, do deposit and redeem revert?
