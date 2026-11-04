# Member response

## Identity

- Run ID: v4-swap-capture-evidence-20261026-01a177b3
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/v4-swap-capture-evidence-20261026-01a177b3/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

Companion witness: `docs/research/v4-swap-capture-evidence-20261026-01a177b3/members/grok/model.py`. It is standalone integer arithmetic. It is not a Foundry test, a transaction script, or a deployment procedure. Public search was not used.

## Question and targets

- Question: When the target token's only liquidity is the underlying pool, and the only reference is this project's TWAP of that pool, do actual swaps during deposit and during exit eliminate APEX-2026-012? If a stated mint equation, fee cutoff, inventory cutoff, and execution rule makes incumbent ownership conservation hold, state that invariant and its domain. If it does not, exhibit a closed token ledger, or a precise limit of the rule. Do not assume an independent price, and do not treat a price move alone as proof.
- Required targets: `CLAUDE.md`; Wings Money, Accounting, LiquidationQuote, Inventory, Geometry, Harvest, ExecutionDelegate, EconomicTarget; audit APEX-2026-012 and, as context, 024, 025, 026, 040, 050; `UniswapV4MultiPoolTwapOracleTarget.sol`; `UniswapV4TruncatedTwapOracleLib.sol`; vendored Uniswap V4 `SwapMath` and `SqrtPriceMath`.
- Optional context: Wings PRD and owner rulings were not read. They are not a source for this pass.
- Admitted read scope: the repository source and the named audit text. No peer response, no other `docs/research/v4-*` artifact, no secrets.

Direct answer: no. Adding a real swap on deposit, on exit, or on both does not eliminate APEX-2026-012 while the mint or the payout still reads the live whole-book liquidation quote, and it does not eliminate it when the mint price is the execution price or the same-pool TWAP of inventory that swap did not trade. One rule conserves incumbent token balances, and it does not use a swap: price-free proportional claims, with exit paying the same vector and no sale. That rule refuses the single-sided target deposit the finding uses. Its domain is stated below. It is not a repair of the production mint equation.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Production mint | `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` `_deposit` | source observation | After `_pull` and `_harvest`, and before `_changeTarget`, `value = Quote.quote(Common.quoteRequest()).value` when `supply != 0`. `shares = Accounting.issue(supply, value, assets)`. |
| Production payout | same file, `_redeem` | source observation | After `_harvest`, `assets = Accounting.entitlement(supply, Quote.quote(...).value, shares)`. While `manager.isUnlocked()`, payment is local target only. Otherwise `_fund` may close positions and `_swapDeficit` sells the whole opposing local balance. |
| Issue and entitlement | `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol` `issue`, `entitlement` | source observation | `S == 0` mints `credit`. Otherwise `floor(S * credit / value)` and `floor(shares * value / S)`. Both revert on zero shares or on `S != 0 && value == 0`. |
| getRate | `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol` `getRate` | source observation | `supply == 0 ? 1e18 : floor(quote.value * 1e18 / supply)`. `issue` does not call `getRate`. |
| Integrator quote | `UniswapV4UpperLowerWingsStandardExchangeVaultQueryTarget.sol` `liquidationValue`; `QuoteBase._liquidationValue` | source observation | Same `Quote.quote(Common.quoteRequest())`. |
| Quote equation | `UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol` `_quote`, `_prepare`, `_removeOwned`, `_sell` | source observation | Read live `slot0` and `getLiquidity`. Subtract only this vault's active liquidity. Collect owned principal at floor plus `Inventory.earnedFee`. `value` starts as the target total. Sell opposing through `SwapMath.computeSwapStep` into remaining liquidity. Add `proceeds` only. Unsold opposing is not marked. `quoteRequest` sets `stepLimit = 512`. |
| Harvest | `UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol` `harvest` | source observation | Ordinary harvest closes a converted wing and places residuals. It does not swap. Deposit and redeem skip harvest when `manager.isUnlocked()`. |
| Exit swap already in production | `Money._swapDeficit` | source observation | If local target is short, sell `opposing` exact-in, not the shortfall, at `MAX_SQRT_PRICE - 1` or `MIN_SQRT_PRICE + 1`. `HolderValueLoss` re-quotes the same state and allows `costBound`. |
| Geometry | `UniswapV4UpperLowerWingsStandardExchangeVaultGeometry.sol` `ranges` | source observation | Core is full usable range. Upper and lower wings are the nearest strictly separated ranges. Token0 inventory is placed on the upper wing when target is token0. |
| Execution | `UniswapV4UpperLowerWingsStandardExchangeVaultExecutionDelegate.sol` | source observation | The callback applies `modifyLiquidity` or `swap`, then settles the actual caller delta into `local0` / `local1`. A view does not trade. |
| Inventory principal | `UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol` `principal` | source observation | `getAmount0Delta` / `getAmount1Delta`, floor on removal, ceil on addition. Fees are not converted principal. |
| Swap step | vendored `SwapMath.computeSwapStep`, `SqrtPriceMath` | source observation | Exact-in fee is taken first: `floor(remaining * (1e6 - fee) / 1e6)`. Input to a boundary rounds up. Output rounds down. Fee on a capped step is `ceil(amountIn * fee / (1e6 - fee))`. |
| Swap fee composition | `ProtocolFeeLibrary.calculateSwapFee` | source observation | `protocolFee + lpFee - floor(protocolFee * lpFee / 1e6)`. The witness sets protocol fee to 0, so the swap fee is the LP fee. |
| TWAP write | `UniswapV4TruncatedTwapOracleLib.write` | source observation | If the timestamp differs, `recordedTick = truncate(liveTick, prevTick)` with cap 9116. The cumulative credits `recordedTick * delta`, not the tick that held during the gap. `update` is permissionless and has no `isUnlocked` check. |
| TWAP read | `observeSingle`, `transform`, `consult` | source observation | A read with `secondsAgo == 0`, or a target inside the idle gap, calls `transform(last, time, liveTick)`. The live tick passed into `consult` fills the gap. |
| APEX-2026-012 | audit diff review, that heading | source observation | The reported shape is `m = S * D / V0`, then payout `m * V1 / (S + m)`. The reported PoC output was not rerun. |
| APEX-2026-024 | same audit, context | source observation | A large redeem can dump the whole opposing balance. The payout is still the quote. |
| APEX-2026-025 | same audit, context | source observation | The rebalance loss cap re-quotes live spot after the vault's own swap. |
| APEX-2026-026 | same audit, context | source observation | `stepLimit = 512` can freeze the quote. Not exercised. |
| APEX-2026-040 | same audit, context | source observation | Zero-supply issue is 1 share per target wei. The witness starts at `S > 0`. |
| APEX-2026-050 | same audit, context | source observation | One poke after an idle gap of at least `W` can set the mean to `prevTick + 9116`. The identity below is that formula, not a rerun of the PoC. |
| Closed ledgers | `members/grok/model.py`, executed in this pass | static analysis | Integer pool with one range, conservation checked after every mutation. Results below. A finite parameter list is not a universal proof. |

## Assumptions

- Token0 is the target. Token1 is opposing. There is no second venue and no external fair price. A raw token1 balance is not marked as target profit.
- Protocol fee is 0. LP fee is 3000 pips except the named zero-fee case.
- The pool has one initialized range, `sqrtLower = 2^95`, `sqrtUpper = 2^97`, initial `sqrtPrice = 2^96`. Active liquidity is `lower <= sqrt < upper`. A sale that reaches the boundary stops. This is the quote's external-sale equation after owned liquidity is removed. It is not a both-wings lifecycle.
- Default book, unless a case says otherwise: external liquidity `10^18`, vault idle target `5 * 10^17`, vault idle opposing `10^17`, supply `5 * 10^17`, deposit `10^17`, JIT liquidity `10^19` when used. The attacker is endowed 1000 target wei, not debt, so a 1-wei rounding shortfall can repay a flash principal. Profit is end target minus that 1000.
- Flash principal is debt. A result is closed only when debt, shares, JIT liquidity, and attacker token1 delta are all zero.
- No outside arbitrageur trades against a displaced price. Capital locked across a TWAP window is not treated as a token loss.
- `getRate` is not substituted into `issue`.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `CLAUDE.md` | required | examined | Router only. It names the Wings path as the supported V4 standard-exchange family. It does not define the mint equation. |
| Money | required | examined | Deposit, redeem, fund, and whole-book deficit swap. |
| Accounting | required | examined | `issue`, `entitlement`. `liquidTarget` is sleeve arithmetic, not the share price. |
| LiquidationQuote | required | examined | Quote, owned-liquidity removal, sale step. |
| Inventory | required | examined | Principal and fee units. |
| Geometry | required | examined | Three ranges. The witness does not place them. |
| Harvest | required | examined | No swap. Skipped while unlocked. |
| ExecutionDelegate | required | examined | Actual deltas settle into local balances. |
| EconomicTarget | required | examined | `getRate` uses the same quote and is not the mint. |
| QueryTarget / QuoteBase | required by the audit locator | examined | `liquidationValue` is the same quote. |
| APEX-2026-012 | required | examined | Question source. PoC not rerun. |
| APEX-2026-024, 025, 026, 040, 050 | required context | examined | Used only to bound the quote, the existing exit swap, and the TWAP formula. |
| TWAP target and library | required | examined | Write, consult, truncate, permissionless `update`. |
| Vendored swap and sqrt-price math | required | examined | Copied into the witness with the same rounding. |
| Wings PRD and owner rulings | optional | not examined | Not needed to state the production equation. Not used as a veto. |

## Conclusions

### Production equation, stated before any proposed swap

For `S > 0`:

```
m = floor(S * D / V0)
E = floor(m * V1 / (S + m))
```

`V0` is `Quote.quote` after harvest and before the deposit is credited. `V1` is `Quote.quote` after harvest on redeem, which already includes the credited deposit. `getRate = floor(V * 1e18 / S)`, or `1e18` at zero supply. It is not an input to `issue`.

Fee cutoff: none on mint or payout. The LP fee is inside `SwapMath.computeSwapStep`. With protocol fee 0, `swapFee = lpFee`.

Inventory cutoff: none. The sale offers the whole opposing total, idle plus removed principal plus earned fees, into liquidity that remains after this vault's positions are subtracted. Unsold opposing adds nothing.

Execution: the entrant does not swap. If local target cannot pay `E`, `_fund` may close positions and `_swapDeficit` sells the entire opposing local balance at a MIN/MAX sqrt limit. That swap funds `E`. It does not set `E`. `HolderValueLoss` compares two quotes of the same state.

Let `P(L)` be proceeds of selling the same opposing quantity into external liquidity `L` at a fixed price. If the deposit does not change opposing or price, `V1 = V0 + D + P(L1) - P(L0)`. Then, ignoring the two floors:

```
E - D = D * (P(L1) - P(L0)) / (V0 + D)
```

`P` is increasing in `L` while the sale still has slippage and has not already reached the boundary. A depth increase between the two quotes therefore pays more target than `D` whenever the sleeve can pay `E`. A price move is not required. The audit's reported PoC was not used as this derivation.

### Rule 1. Current production rule

Mint equation: the production equation above.

Fee cutoff: none beyond the fee inside the simulated sale.

Inventory cutoff: none. Unsold opposing is not marked.

Execution: no entrant swap. Payout is the live whole-book quote. The witness pays from idle target, which is the in-unlock path when local target covers `E`, and the settled path when `_fund` is not needed.

Control, same book, no JIT, fee 3000. Closed.

| Quantity | Value |
| --- | --- |
| `V0` | 590661089388014913 |
| `V1` | 690661089388014913 |
| minted | 84650912169963821 |
| paid | 99999999999999999 |
| attacker target delta | -1 |
| attacker token1 delta | 0 |
| debt, shares, JIT | 0 |
| incumbent idle target delta | +1 |
| incumbent idle opposing | unchanged at `10^17` |

The 1 wei is floor division in `entitlement`. It is not incumbent loss.

JIT witness, fee 3000, external `L = 10^18`, JIT `L = 10^19`, price unchanged. Closed target profit.

| Step | Attacker target | Attacker opposing | Shares | Vault target | Vault opposing | Quote |
| --- | --- | --- | --- | --- | --- | --- |
| before credit | flash principal plus 1000 | flash JIT opposing | 0 | `5 * 10^17` | `10^17` | `V0 = 590661089388014913` |
| after deposit | flash principal minus `D`, plus 1000 | unchanged | 84650912169963821 | `6 * 10^17` | `10^17` | `V0 + D` |
| after JIT add | rounding dust | rounding dust | same | same | same | `V1 = 698804472192942151` |
| after redeem | paid `101179070738173910` plus dust | dust | 0 | 498820929261826090 | `10^17` | post-payout quote |
| after JIT remove and repay | 1000 + 1179070738173910 | 0 | 0 | 498820929261826090 | `10^17` | — |

`V1 - (V0 + D) = 8143382804927238`. The floor formula gives `1179070738173910`, and that equals both the attacker target delta and the negative of the incumbent idle-target delta. Lender delta is `(0, 0)`. Pool claim dust is `(0, 0)`. JIT liquidity ends at 0. Opposing is unchanged in the vault and closed in the attacker wallet. No price was used to mark a leftover.

The same shape at fee 0 pays `1185395922238027`. At external `L = 10^17` and fee 3000 it pays `7508646972852965`. Both close. A larger haircut pays more. The zero-fee case separates the haircut from fee drag: the profit is the quote gap, not a fee.

Vault-only LP, view only: with the vault as the only liquidity, the quote's external sale has proceeds 0 and unsold opposing `5 * 10^17`. Adding JIT liquidity `10^19` raises the quote by `474829737581559270`. That is the same equation. A reduced `_fund` that closes the vault position and swaps its opposing into that JIT did not close: the attacker was left long opposing and short target debt after removing the only remaining liquidity. That leftover is not profit. The closed profit above is the sleeve-sufficient idle book, which is the quote after owned liquidity has already been removed. It is reachable when local target can pay `E`. It is not a both-wings, harvest, or hook result.

Rule 1 does not eliminate the finding.

### Rule 2. Real swaps added; mint and payout still use the live whole-book quote

Mint equation: unchanged. `m = floor(S * D / V_postswap)` and `E = floor(m * V_redeem / (S + m))`, both `V` from `Quote.quote` of the whole book.

Fee cutoff: the pool fee on the mandated swap only. No extra haircut on `V`.

Inventory cutoff: none.

Execution: before `issue`, sell `q = floor(f * D)` of the entrant's own target through the pool, zero-for-one. The opposing output stays with the entrant. It is not vault inventory. The credit is still `D` target. Between mint and redeem the attacker adds the same JIT liquidity, redeems at the live quote, removes the JIT, and sells any opposing still held, through the pool, until token1 debt is repaid.

| `f` | Attacker target delta | Incumbent idle-target delta | Closed |
| --- | --- | --- | --- |
| 1 wei / `D` | 1179070738173909 | -1179070738173910 | yes |
| 1/100 | 1176199817602483 | -1182187847473902 | yes |
| 49/100 | 1050391271528511 | -1337143440743998 | yes |
| 50/100 | 1048013426478537 | -1340482642339122 | yes |
| 51/100 | 1045645242896000 | -1343826364480276 | yes |

49, 50, and 51 percent are not thresholds. The 1-wei swap matches the no-swap JIT profit within 1 wei. The larger mandated swaps reduce attacker profit by the round trip against external liquidity and increase incumbent target loss by the quote's price move. Attacker token1, shares, JIT, and debt close in every row. Incumbent opposing is unchanged. The gap `P(L_jit) - P(L_ext)` is still inside `E`. A swap that does not replace the quote does not remove it.

This is also why the production `_swapDeficit` does not eliminate the finding. APEX-2026-024 describes that whole-book sale. It funds a quote-priced payout. Rule 2 keeps that pricing.

### Rule 3. Executed-price mint

Define the mandated swap as the entrant's own zero-for-one sale of `q` target. The output stays with the entrant.

```
p_exec = floor((amountIn + fee) * 1e18 / amountOut)
```

`amountIn + fee` is the target spent. `amountOut` is opposing received. If `amountOut = 0`, `p_exec` is undefined and this rule reverts.

Post-swap book `(A_T, A_O)` is vault inventory after the swap, including fees accrued to vault liquidity. The entrant's swap output is not part of that book. On the idle book the swap does not change `(A_T, A_O)` because the vault has no liquidity.

Mark-all mint and mark-all exit:

```
V = A_T + floor(p_exec * A_O / 1e18)
m = floor(S * D / V)
E = floor(shares * V_exit / supply)
```

`V_exit` uses a second mandated swap of the same `q` after the attacker has restored the push. Fee cutoff: the fee is inside `p_exec`. It is not subtracted again. Inventory cutoff: none. Every opposing unit is marked, including units that did not trade.

Cutoff variant: replace `A_O` with `min(A_O, amountOut)`. Strict variant: the vault's inventory did not trade, so `V = A_T`.

Execution for the mark-all sandwich: sell `10^17` opposing into the pool, run the mandated swap, mint at post-swap `V`, buy the pushed opposing back, run the exit mandated swap, pay `E` from idle target, close token1 to debt through the pool.

| Case | `q` | Attacker target delta | Incumbent idle-target delta | Closed |
| --- | --- | --- | --- | --- |
| no push, mark all | `D/2` | not closed; token0 debt 580785993164416 | -4153399455467 | no |
| push, mark all | `floor(49 D / 100)` | 1738873256249023 | -2599422051909098 | yes |
| push, mark all | `D/2` | 1734135406883615 | -2600401325641226 | yes |
| push, mark all | `floor(51 D / 100)` | 1729402438092909 | -2601380340349917 | yes |
| push, attacker-chosen | `10^12` | 1977318502629048 | -2551119172835856 | yes |
| push, `min(A_O, amountOut)` | `D/2` | not closed; token0 debt 866265918756612 | +1 | no |

The no-push rows are failed attacks at those parameters. They are not a proof that no size works. The push rows close with more target, zero opposing, zero shares, zero JIT, and zero debt. The smaller attacker-chosen swap pays more than 49, 50, or 51 percent. Those percentages are not safety thresholds. Incumbent target loss is larger than attacker profit by the amount the push and the mandated swaps paid external liquidity. That difference is fee drag. The remainder is incumbent target loss.

Strict cutoff, then slice exit. `V = A_T = 5 * 10^17`, so `m = D = 10^17`. Exit removes `shares/supply` of idle and sells only the opposing just removed. No top-up.

| Quantity | `q = 10^12` | `q = D/2` |
| --- | --- | --- |
| attacker target delta | 16345060256774282 | 16057216531210318 |
| incumbent idle target | unchanged at `5 * 10^17` | unchanged |
| incumbent idle opposing | `10^17` to 83333333333333334 | same shape |
| opposing taken from incumbents | 16666666666666666 | the unpaid slice |
| closed | yes | yes |

The attacker ends with more target, opposing closed, shares 0, debt 0. The target was paid by external liquidity in exchange for incumbent opposing the mint did not charge for. That opposing loss is the incumbent vector. It is not converted at an outside price. The attacker's target increase is a closed balance, not a mark.

Fee-aware residual, vault liquidity `10^18` in the same range plus the idle book, entrant sells `10^17` target. Post-swap vault inventory is `(1049999999999999999, 552517026241844072)`. Swap output is `94965947516311854`. `p_exec = 1053009027081243732`. Marking all retained opposing at that price gives `1631805416248746237`. The liquidation quote of the same book is `1434680630207761058`. The difference is `197124786040985179`. The traded quantity is smaller than the retained opposing. The swap price does not price the residual. Using it for the residual can overstate the quote, as here, or understate it, as in the push rows. Neither direction is an invariant.

Rule 3 does not eliminate the finding. The hypothesis holds as a limit: the execution price is a price of the quantity that traded. It is not, by itself, a price of inventory that did not trade.

### Rule 4. Price-free proportional position vector

Mint equation, one scalar fraction applied to each component, components not summed:

```
m = 0 if any positive component is unfunded
m = min over positive components i of floor(S * d_i / c_i) otherwise
use_i = floor(c_i * m / S)
```

Unmatched `d_i - use_i` is refunded. A position's component is its liquidity, not a token amount and not the sum of liquidity in another range. Funding a position requires the ceil principal of the added liquidity in both tokens. A target-only deposit leaves the opposing component unfunded.

Fee cutoff: none. There is no swap.

Inventory cutoff: a component that is not funded is not minted. There is no residual mark.

Execution of the invariant: burn `shares` and pay `floor(c_i * shares / S)` of each component in kind. No sale. No top-up.

Invariant: after that mint, each incumbent's absolute claim on each component is the pre-mint component, up to the floors in `use_i` and the exit floor. Domain: the depositor funds every positive component; exit pays the vector; no swap; no revaluation; `S > 0`.

Witness, idle book, no positions, depositor supplies one fifth of each idle balance, rounded up, and the rule consumes `floor`. `m = 10^17`. Consumed and returned vectors are both `(10^17, 2 * 10^16)`. Incumbent idle ends at `(5 * 10^17, 10^17)`, equal to the start. Attacker target delta 0, token1 delta 0, debt 0. Single-sided target against positive idle opposing mints 0.

Disjoint ranges are not one scalar. At `sqrtPrice = 2^96` and liquidity `10^18` in each range, a range entirely below the price and a range entirely above it have principals that sum to `(10^17, 2.5 * 10^17)`. A fake position that adds those liquidity units into one spanning range has principal `(1.2 * 10^18, 1.5 * 10^18)`. Those vectors are not equal. A mint against summed liquidity would assign a claim that is not the sum of the claims.

This invariant does not extend to an exit that sells the slice. That sale is a different execution rule. The quote-mint plus slice-sale case below is not this rule. Rule 4 does not eliminate APEX-2026-012 inside the production equation. It refuses the entry that equation prices. It does so without a swap and without a TWAP.

### Rule 5. Same-pool TWAP as a gate or as the mint reference

Implementation consult, idle gap at least the window, no write in the gap:

```
cumulative(now) - cumulative(now - W) = liveTick * W
meanTick = liveTick
```

The identity witness uses last write at tick 0, time 0, cumulative 0, `now = W = 1800`, live tick 9116. As-written consult returns 9116. An idealized consult that fills the gap with `prevTick` returns 0.

As-written write credits `truncate(liveTick, prevTick) * gap`. Cap is 9116 ticks. `1.0001^9116 = 2.488187224469886...`, which is greater than `2.25`. The pool push used below, sqrt price to `1.5 * 2^96`, is inside one truncated poke. After that write, a write one second later at the restored tick records 0 for that second only. The 1800-second mean remains 9116. `update` is permissionless and does not check `isUnlocked`. This is the APEX-2026-050 formula. No consumer of this oracle was assumed to exist. The question is what happens if the vault uses it.

Gate, mint still the live quote. JIT does not change `sqrtPrice`. The quote still increases. A spot-versus-TWAP gate does not see depth. As written, an idle consult equals the live tick, so the gate compares the spot to itself after one read. The gate does not eliminate the finding.

Mint reference, as written, after an idle gap: `V = A_T + floor(A_O * 2^192 / sqrtLive^2)`. No fee. No depth walk. Inventory cutoff: none; all opposing is marked. Execution: the attacker sells `10^17` opposing, deposits at that mark, buys the opposing back, redeems at the restored mark, and closes debt.

| Case | Attacker target delta | Incumbent idle-target delta | Paid | Closed |
| --- | --- | --- | --- | --- |
| no push | -1 | +1 | `D - 1` | yes, loss |
| push, as-written live backfill | 1970597147462162 | -2544391826671940 | 102544391826671940 | yes, profit |

Idealized historical reference inside one transaction: both reads use the pre-push sqrt price. `V_entry = 6 * 10^17`, `V_exit = 7 * 10^17`, minted `83333333333333333`, paid `D - 1`. The push fee is the attacker's own capital, not debt. Closed target delta `-573794679209779`, token1 delta 0, debt 0. Same-transaction JIT does not enter this `V`, because `V` does not read liquidity. Same-transaction spot does not enter it either. That closes only the in-transaction discrepancy, and only for this idealized reference.

Idealized reference after the attacker holds the pushed price for the window, with no outside arbitrageur: the reference becomes the pushed price. The token ledger is the push row above, closed profit `1970597147462162`. Holding the price is not an extra token cost beyond the swap fees already in that ledger. The implementation does not require the hold: one poke backfills the gap.

Rule 5 as written does not eliminate the finding. The idealized oracle eliminates the same-transaction quote gap and leaves the cross-window gap open under this premise.

### Swaps on deposit and on exit, as the question asks

The proposed pair is: swap some of the entrant's target, then mint; on exit remove only that holder's fraction of each position and both idle balances, sell only that slice's opposing, and pay the target received. No top-up. A view does not trade.

If the mint is still the production quote, the exit rule above does not save it. No push, quote mint, then slice sale, fee 3000. Closed attacker target delta `1103316364600005`. Vault target ends at `513126711607330946` and vault opposing at `85521118601221825`. Incumbents have more idle target and less opposing. The attacker's extra target was paid by external liquidity for the opposing slice. Shares, debt, and attacker opposing close. A push of `10^17` opposing before the quote mint raises the closed attacker delta to `2231288269068756`, with vault target `511188568123052542` and vault opposing `85198094687175424`.

If the mint is the strict executed-price cutoff, `V = A_T`, the slice exit is the larger closed profit in Rule 3: `16345060256774282` target, incumbent target unchanged, incumbent opposing down by `16666666666666666`.

If both mint and payout stay on the live quote, Rule 2 is the result. The mandated swap does not close the JIT gap.

So the pair of actual swaps does not eliminate the finding. Exit-slice payment stops the redeem quote from being the payout. It does not stop a mint that hands the exiter a claim on inventory the entry price did not charge for. Deposit-swap payment stops nothing unless the mint equation stops using the live quote and stops marking untraded inventory at a same-pool price the attacker can move.

### What would be an invariant, and what is not

Incumbent ownership conservation holds for Rule 4 on the stated domain: funded vector in, same vector out, no swap. It does not hold for any tested rule that prices a single-sided target deposit from this pool alone.

Separately, ordinary rounding in the production floors moved 1 target wei to incumbents in the no-manipulation controls. That is not the finding. Fee drag is the excess of incumbent target loss over attacker target profit in the rows where the attacker also round-tripped against external liquidity. The closed attacker profit that remains after that drag is incumbent loss, or, in the slice-sale rows, incumbent opposing delivered to external liquidity. Those are different vectors. Both are closed. Neither is a price move offered as proof.

## Limits

- Runtime or extraction proof: no Foundry run, no audit PoC rerun, no deployment. The ledgers are integer checks of the quote and swap formulas. `model.py` exits 0 on its control and primary JIT assertions.
- The model is one range. Both-wing activation, harvest placement, hook callbacks, nonzero protocol fee, donation, and `stepLimit` exhaustion are unmodeled. A frozen quote (APEX-2026-026) is a different failure.
- The closed JIT profit is the sleeve-sufficient path. The reduced zero-sleeve `_fund` path did not close; its leftover opposing and target debt are not profit. That does not shrink the quote gap.
- A finite list of swap sizes is not a proof that every size loses. The rows that fail to close are labeled failed parameters.
- Idealized TWAP safety inside one transaction does not extend to a window the attacker can occupy. No outside arbitrageur was assumed.
- Rule 4's invariant was checked on an idle book. It was not checked as a Wings placement. Slice sale is outside that invariant.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
