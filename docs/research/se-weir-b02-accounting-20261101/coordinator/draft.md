# Coordinator draft

## Draft identity

- Draft ID: draft-se-weir-b02-accounting-20261101-r1
- Path: docs/research/se-weir-b02-accounting-20261101/coordinator/draft.md
- Run ID: se-weir-b02-accounting-20261101
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md. Coordinator re-ran the four owned Python scripts and re-read `WeirVaults.sol` at the cited functions, plus FS-OWN-33.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

Does WeirVaults' own internal accounting resolve the B-02 losses, or does a caller-moved pool price still leave that loss with the other holders?

## Proposed text

Weir does not resolve B-02. It resolves one narrow quantity error and leaves the live-price placement loss in place. Selecting the Weir model is not a new rule. The full-spread PRD already copies the live-price placement and the absolute swap limit. It does not copy the one Weir rule that stops the whole-balance dump.

The owner chose Weir because it seemed to close this. The source does not do that. No member found a read of a pre-operation price, a TWAP, or any other reference. The only price Weir uses to size liquidity is the pool's live `slot0`. The binding premise holds: nothing in this result assumes an independent pricing source.

### What the source does

Coordinator-checked, not taken from a member locator where they differ.

`compound` is external. The notice on line 206 says anyone can call it. `unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`. It does not call `_compound` after the withdraw swap.

`_compound` harvests fees, takes `perfFeeBps` of those fees only, then sizes `remainder + idle` with `getLiquidityForAmounts` at the live `slot0` (`WeirVaults.sol:355-367`). If that liquidity is positive, it adds it and does not mint shares (`:370-376`). One-sided idle that cannot form liquidity is left idle. The executed scripts report that a pure one-sided amount adds zero liquidity in the infinite-range fixture.

`_deposit` sizes the caller's post-balance amounts at the live `slot0`. For an existing supply, shares are `liq * totalShares / liquidity` (`:269`). Idle is not in that denominator. The depositor is credited those shares. Unplaced input is refunded.

`_withdraw` removes the exiting fraction of liquidity and of each idle balance (`:290-296`). If `zapTo` is set, `_swap` receives that withdrawn net, `uint256(net1)` or `uint256(net0)` (`:314` and `:318`). It does not receive the vault's remaining opposing balance.

`_balance` swaps half the caller's excess so the caller's own input matches the live pool ratio (`:387-410`). It does not touch idle. It does not compare the live price with an earlier price.

`_swap` uses `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1` (`:413-424`). That limit is not a check against the pre-operation price.

### External push

Not resolved for vault-owned idle or harvested fees.

Any caller can move the pool price and call `compound`, or can call `deposit` or `withdraw`, which compound first. Vault-owned tokens are then placed at that price. No new shares are minted. After the price returns to `P0`, the shortfall is in the position the existing holders own.

The comparable fixture used by Astra, Kimi, and MiniMax places a 100/100 budget that was balanced at `P0 = 1`. At `P' = 2` the placement shortfall is about 8.578644 token1. At `P' = 4` it is 25. Those three scripts print that the direct amount formulas match the audit approximation `IL(dL) = dL * (sqrtP' - sqrtP0)^2 / sqrtP'`. Grok used a 1e17-scale budget and printed the same identity at that scale. The coordinator re-ran all four scripts. Each exited 0.

A caller-funded deposit is a different ownership case. The share formula assigns the new liquidity to the depositor. In that fixture the other holders' value change at `P0` is zero, and the depositor bears the shortfall. That isolation does not remove the maintenance loss. MiniMax calls the external-push result "partly resolved" because of this deposit case. Astra, Grok, and Kimi call the maintenance path unresolved and state the deposit case separately. Those are the same split, not two mechanisms.

One-sided idle is not this loss. The scripts report that it is not placed.

This is an accounting identity. It is not a re-run of the audit's profitable attack. Astra states that the push and the return are not funded in the experiment. Grok infers that a same-pool round trip extracts the shortfall whether or not outside liquidity is present. The draft adopts the identity. It does not adopt a profitability claim. The audit's profit depended on the vault's share of pool depth. This run did not re-execute those proofs.

### Self-moved trailing placement

The old same-call trailing mint is absent. The price risk is not closed.

`unlockCallback` compounds, then withdraws, then returns. There is no second compound after the zap. That removes the automatic trailing placement the audit found in the old FullSpread redeem path.

A later `compound` is still permissionless. If the withdraw zap moved the only available pool price, and two-sided idle or fees remain, the later call sizes that inventory at the moved price and mints no shares. The exiting shares are already burned, so the shortfall belongs to the remaining holders. Astra's fee-bearing example and the other three scripts agree on that allocation. Their trailing amounts differ because the fixtures differ. The draft does not pick one fixture's number as the council figure.

A later compound of only one-sided idle and no fees does not mint. Astra is right to keep that limit visible. It does not make the two-sided case safe.

The withdrawn-net cap does not close this path. A smaller swap can still move the price that the next compound reads.

### Whole-balance redemption dump

Resolved in Weir, as a quantity rule. Not resolved by the price limit.

`_withdraw` swaps the exiting slice's unwanted net. It does not sell the vault's whole opposing balance. All four responses reach that conclusion. The coordinator read the swap arguments at lines 314 and 318. Grok cited 316 and 320. That citation is off by two lines. The original is not rewritten. The operation is the one the coordinator read.

The absolute limit remains. It can slip the exiting slice. That slippage is the exiting holder's, not a sale of the stayers' inventory. Grok's fixture left staying-holder value unchanged after a return to `P0` on the Weir path, and showed a stayer loss on the whole-balance path. The amount is the distinction. The shared limit is not.

FS-OWN-15 says a redemption may swap through the pool for volume. It does not cap that swap at the withdrawn net. FS-OWN-30 pays the caller's fraction. It does not state the swap amount. The withdrawn-net cap is a Weir source fact. It is not a sentence in those locks. Copying "the Weir model" does not, by itself, add that cap.

### Half-excess balance

`_balance` does not protect existing holders from a displaced spot. It ratio-matches the caller's own input at the live price. The following placement uses the post-swap live price. Existing holders are unchanged because the new liquidity is assigned to the depositor, not because the price was checked.

FS-OWN-33 already says a one-sided share mint swaps about half of the excess so the deposit matches the pool ratio. That is the same shape. It is not a price guard.

### What selecting Weir does not change

FS-MONEY-01 already copies the absolute entry-swap limit, the liquidity-only share denominator, compound before deposit and before withdraw, reinvestment of remainder plus idle, and pro-rata removal. FS-OWN-14 already makes `compound` permissionless and says it deploys booked idle. FS-OWN-10 forbids a replacement zap tick bound. It does not install a maintenance price check.

FS-OWN-14 also says a no-fee compound returns with no state change. Weir still places idle when the fee harvest is zero, if the idle can form liquidity. That conflict is B-03. This draft does not pick a winner.

No PRD edit is proposed. B-02 stays open. This draft does not authorize a TWAP, a tick bound, a fee cap, or an implementation.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| External-push wording | MiniMax: partly resolved, because a caller-funded deposit isolates the other holders. Astra, Grok, Kimi: maintenance unresolved, and the deposit case is separate. | The maintenance loss is unresolved. The deposit isolation is real. Neither wording is erased. |
| Attacker profit | Grok: a same-pool round trip extracts the shortfall with or without outside liquidity. Astra: push and return costs were not simulated, so the shortfall is not an attacker profit. | The accounting identity is adopted. Profitability is not. |
| Trailing-mint emphasis | Astra and Grok: the same-call trailing mint is absent. Kimi and MiniMax: a later compound still uses the moved price. | Both statements stand. The same-call path is absent. The later path is not closed. |
| Fixture numbers | Astra, Kimi, and MiniMax print about 8.578644 and 25 for the 100/100 case. Grok prints the same identity at 1e17 scale. Trailing-loss figures differ by fixture. | No single trailing-loss number is the council result. |
| Withdraw-swap line numbers | Grok cites 316 and 320. Coordinator read 314 and 318. Grok cites the share assignment at 272. Coordinator read 269. | Originals stay. The draft uses the coordinator-checked lines. |

## Evidence gaps

- No member re-executed the audit proofs of concept. Profitability at a stated vault share of pool depth is not a result of this run.
- The swap legs that move a price use a constant-product approximation. Each response that uses one labels it. The placement identity does not depend on that approximation.
- Finite usable ticks and integer rounding were not the comparable fixture. Grok ran them as a side case and did not mix them into the fixture totals.
- The deleted FullSpread and Wings sources were not reconstructed. The audit text is the finding record.
- Public search was not required and was not used by the coordinator.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| WeirVaults deposit, withdraw, compound, unlock callback, and the four internal money functions | examined | all four; locators checked by the coordinator | Grok's withdraw and share line numbers are off as recorded above. The operations match. |
| LiquidityAmounts | examined | all four | Infinite-range limit used for the comparable totals. Not mixed with unevaluated usable ticks. |
| APEX-2026-023 and APEX-2026-024 | examined | all four | Finding text only. PoCs not re-run. |
| B-02 and FS-OWN-10, FS-OWN-12, FS-OWN-14, FS-OWN-15, FS-MONEY-01 | examined | all four | FS-OWN-15 does not state the swap amount. |
| FS-OWN-33 | coordinator-checked | grok | The half-excess sentence is present. It is not a price guard. |
| Four Python scripts | coordinator re-ran | all four | Each exited 0 on the coordinator re-run. |

## Limits

- Static source reads and executed standard-library simulations stay distinguished. The coordinator re-run is supplied runtime for the exit status. It is not a Uniswap V4 tick walk.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- This draft is not the final report, does not lock B-02, and does not authorize a PRD edit.
