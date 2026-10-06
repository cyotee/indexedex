# Grok cross-review — matched exits (2026-10-05)

Original preserved. Continuous checks only. Not a simulation or a ratification. No fee or gate is treated as sufficient.

## Arithmetic

**Astra, accepted.** Post-entry book `(144,100)`, supply 120, holder claim `(120, 250/3)`, mark `203⅓` at price 1. Basket liquidation is `122/3`. Internal `T = 44`. Shortfall `10/3`. A 0.3% swap fee makes `Z = 40.6166…` and does not turn that gap into a fee. Skewed case: `Z ≈ 141.2465` before the 1-token exit fee, `T = 125`, surplus `≈ 16.2465` if that fee leaves the vault. Holders who keep the surplus gain that amount versus the pre-withdrawal claim, not versus the pre-deposit mark of 300. The active-center own-LP mark change is reported as about `0.027` against a shortfall of about `3.65`. I did not re-derive the sqrt step. The split is the point: own-liquidity P&L is not a budget for filling `T`.

**Kimi’s identity is right; the skew numbers are not.** Same-token internal exit is `q = c` in reals. For book `(1400,700)` and deposit `140` token0, `f = 1 − sqrt(1400/1540) = 1 − sqrt(10/11)`, so `m ≈ 48.81`, not `48.21`. Entitlements are about `(71.67, 32.58)`, not `(70.83, 32.19)`. The quote is `140`, not `138.39`. External proceeds at 2 token0 per token1 and a 0.3% input fee are about `136.62`, not `135.02`. The `3.37` “premium” is an arithmetic miss. It is not a counterexample to `q = c`.

**MiniMax, rejected as a holder test.** `1.0 → 1.2295` compares a token0-per-share figure with a two-token value. `B0+B1` per share is not mark value and not vector preservation. The idle path that pays from `D` while `F = 0` without a stated removal spends inventory it has not withdrawn. The blocked path that pays `98` from the book with `F = 0` contradicts PRD B4: deployed principal is not local cover. “≤ 1 wei per term” and “capped at a 50/50 move” are unsupported global bounds. Their own table shows A paying `125.784` and B1 paying `98.28` at `P = 2`; the prose that B1 ties A in the best case is false. Full-range center is not this product.

## What the comparison actually shows

Use the pre-withdrawal holder vector, not the pre-deposit mark and not the sum of the two tokens.

- **A** leaves that vector unchanged when only the basket is removed and the swap does not reprice owned `D`. Own in-range liquidity can add a separate fee and a price move. That is market P&L, shared with other LPs, not an operation fee and not a top-up fund.
- **B capped** — pay `min(T, Z)`, no holder assets finance a shortfall, surplus stays in backing — equals A when `Z < T`, which is the immediate same-token exit after this entry at a matched price. When `Z > T`, retaining surplus improves holders versus the benchmark. Rebating surplus makes B into A.
- **B uncapped** — pay `T` from the remaining book — fails the benchmark in the matched-price case. Holders lose `10/3`. Do not ship that as “settlement.”
- A fall in the other token per share at **entry** does not ban scalar entry. It is already inside the pre-withdrawal book.
- Dual pro-rata exit lets the user synthesize A. Capped B does not remove that choice. No proof of no cross-mode arbitrage is available, and none is claimed.
- **Blocked, `F = 0`:** both external settlements fail before burn. A quote on `B` is not capacity. Do not replace that with book consumption.
- **Outside the envelope:** if one `B_i` is zero, the geometric quote is undefined. The linear same-side branch is a different rule (`StandardExchangeConstantProduct.sol:49-51`). Do not silently use it for the missing token.

## Orientation

`LiquidityAmounts.sol:67-75`: price at or below a range is token0; price at or above a range is token1. MiniMax’s restatement that the lower wing is token1-only is the inverted PRD G1 label. If spot is in the center, the lower wing is token0 and the upper wing is token1.

## Conclusion, not a ratification

A is the holder-vector benchmark at exit. Capped B is A plus optional surplus retention; it is not a second payable amount when the pool pays less than `T`. Uncapped B moves the pre-withdrawal claim. Own-LP fees and price impact stay on their own ledgers. Scalar entry remains in the comparison. The open specification is only: shortfall reverts or haircuts to `Z`; surplus stays or is rebated; blocked cover stays `F`. No winner is selected.
