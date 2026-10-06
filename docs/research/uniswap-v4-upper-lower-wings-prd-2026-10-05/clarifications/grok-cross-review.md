# Grok cross-review — wings clarifications (2026-10-05)

Original preserved. Peers untrusted. No PRD edit. No formula is certified safe.

## Corrections to my original

I treated a virtual book conversion as a prohibited zap, and I asked whether exits must also be no-swap. That inference is withdrawn. “No typical zap” forbids an AMM balancing swap of caller credit. It does not forbid pricing a conversion against the vault book, and it does not decide redemption.

I also overstated geometric minting. When the external mark matches the book, the depositor’s loss is second-order impact (my 20-into-100/100 case: about 0.83 before floors). When the mark differs, the first-order transfer can run either way. Astra’s example is the right counterexample to “always subsidizes incumbents.”

## Arithmetic checked

**Astra, accepted.** `B=(100,100)`, `S=100`, external prices `(2,1)`, deposit 125 token1, no fee. `sqrt(100*225)=150`, continuous mint 50. Incumbents’ mark falls from 300 to `100/150*425=283⅓`. Entrant’s claim is worth `141⅔` against 125 paid. Invariant per share stays 1. This is fixed-mark non-neutrality, not a token-quantity proof and not an executed wings exploit.

Same-token continuous identity holds: `q=1-sqrt(B0/(B0+a))`, payout `(B0+a)*(2q-q²)=a`. That is virtual CP redemption with full local cover, zero fees, and fixed reserves. It is not pro-rata redemption and not an AMM swap.

**Kimi exit integers, accepted.** Reserves `1e6/1e6`, `S=1000`, deposit `10000` token0. Forward floors to 4 shares (`StandardExchangeConstantProduct.sol:58-64`). `_singleExit` (`:98-110`) pays `4023+4007=8030` token0. Incumbents gain the impact. This does not prove a profitable cycle, and it does not prove mark neutrality.

**Kimi sleeve window, not accepted as a bound.** The pool move to `4e6/2.5e5` and the vault book `(3.4e6, 4.17e5)` are not the same state. The later `sqrt(5e6*2.5e5)` uses the pool, not that book. Concentrated `D` does not track spot like a full-range CP pool: wings outside the active tick do not re-ratio until crossed (`LiquidityAmounts.sol:66-76`). A static `F` can open a mark gap. The gap is not sized by “sleeve × price move” alone.

**MiniMax, rejected in the value column.** Path A’s `m=floor(100*50/150)=33` uses post-contribution reserves in the denominator. Pre-state min-ratio on 50/50 added to 100/100 is 50 shares, not 33. The “25.6 slippage” is that inconsistency, not AMM loss. Path B’s “loss of 41.84” counts only the token0 claim (`41*200/141≈58`) and ignores about 29 token1. At mark 1 the claim is about 87, not 58. “Fair 50% of new K” is not the CP rule. Collapsing `R=F=balanceOf` drops the credit exclusion. “Full-range center” is not this product. “No economically fair way” is too strong: mark-neutral issuance at a trusted fixed mark is fair in that mark, and virtual CP is fair in geometric-mean units. Neither is fair in token quantities.

## Distinctions

- **Token quantities:** any `m>0` on a one-sided deposit against `B1>0` cuts incumbent token1 per share. Min-ratio zero is this constraint, not a usable scalar credit.
- **Invariant per share:** virtual CP mint can preserve `sqrt(B0*B1)/S` in reals. Integer ceil/floor favors incumbents. This is not mark neutrality.
- **Fixed-mark value:** `m=S*v/V` preserves incumbent mark at the prices inside `V`. It needs those prices. It does not preserve quantities, later value, or cash.
- **Local cover:** `F` is what a blocked exit can pay. `B` is the ownership book. A correct valuation can still revert for insufficient `F`. Do not price over `D` alone; that drops `F` and `E`. Backing remains `B=F+D+E`.
- **Virtual pricing versus AMM:** the CP helper never swaps the pool. An AMM zap is a different operation. Do not describe virtual pricing as the prohibited zap.

## Wing orientation

PRD G1 puts token1 in the lower wing and token0 in the upper. If spot is in the center, the lower range is below spot and must be token0; the upper range is above spot and must be token1 (`LiquidityAmounts.sol:66-76`). The historical sentence and Slipstream budgets (`SlipstreamStandardExchangeCommon.sol:322-350`) have the same inversion. Executable placement should use the range rule, not that sentence.

## Questions

1. For ordinary single-sided entry, which unit is “preserve value”: geometric-mean per share on `B=F+D+E`, or mark value at a named price source? State that the other unit is not preserved.
2. Which redemption pairs with that mint: virtual conversion against the same book, pro-rata payment of both tokens, or an actual AMM swap? Virtual conversion is allowed by the current clarification; it is not selected.
3. When one `B_i` is zero, name the rejection, or write the one-leg rule. Do not inherit the CP linear branch (`:50-51`) by silence.
