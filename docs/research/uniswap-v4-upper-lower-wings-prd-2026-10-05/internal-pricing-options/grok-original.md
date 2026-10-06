# Grok — internal pricing options (2026-10-05)

Research only. Preferences are not ratified. Settled: `R` is local custody; `B = F + ΣD + ΣE`; sleeve `F = p·D` on vault-owned deployed reserves only. No PRD edit. No test run. No formula is certified safe.

## Path under the preferences

Single-sided entry: invariant-growth mint on `B`, no AMM balancing swap. Idle single-sided exit: burn, realize pro-rata `B`, then one underlying swap of the other token. The initiator bears the swap’s pool fee. That fee is not a second vault toll.

V4 takes the swap fee from specified input before the step output (`SwapMath.computeSwapStep`, Context7 `/uniswap/v4-core`, 2026-10-05). LP fee accrues to in-range `feeGrowthGlobal`; protocol fee, if any, is separate. https://github.com/uniswap/v4-core/blob/main/_autodocs/api-reference/sqrt-price-math.md

## Consistent round-trip

Start: `B0 = B1 = 100`, `S = 100`, `E = 0`, internal ratio equals external price 1. Deposit 44 token0. No entry swap. Exact roots.

`K' = sqrt(144·100) = 120`. Mint `m = 20`. Post-book `(144, 100)`, `S = 120`.

Pro-rata claim: token0 `24`, token1 `50/3`. At price 1 the claim is worth `122/3 ≈ 40.667`. The `10/3 ≈ 3.333` gap stays with incumbents. That is inventory impact, not unbacked credit. Tokens in `B` increased by exactly 44.

Then swap `50/3` token1 to token0. Assumptions: price was 1; fee `3000/1e6`; vault’s share of in-range liquidity `ρ = 0` (fee does not return to this vault); burn already done.

Infinite depth: output `= (50/3)·0.997 = 49.85/3 ≈ 16.617`. User receives `24 + 16.617 = 40.617` token0. Loss versus 44 is `3.383`: `3.333` to incumbents, `0.050` to external LPs.

Finite external pool `X = Y = 1000`, same fee: input after fee `16.617`; output `1000·16.617/(1000+16.617) ≈ 16.345`. User receives `40.345`. The extra `0.272` is price impact paid to that pool’s LPs. Still not an invention of tokens.

If `ρ > 0` and the burn is first, the vault’s slice of that fee becomes `E` for **remaining** holders only. The withdrawer does not get it back. That is ordinary LP income. If the swap is executed before the burn and `E` is inside `B`, the withdrawer rebates themselves a slice. Pick one order. Do not also take a vault usage fee equal to the same `0.050` on the same notional: that is a double charge. Gas is paid to the chain, not to holders. A later sleeve rebalance is a later call. Charge its rounding and gas there, not again here, unless this call itself places liquidity.

## What this is not

Matched-price loss above is paid impact plus a disclosed fee. It does not drain the vault.

Unbacked credit would be minting shares without adding the tokens those shares claim, or paying out of booked `R` that belongs to incumbents. This path does neither if the 44 is booked before the mint and the exit pays only the burned claim.

Mark extraction is different and real. Same book, external prices `(2, 1)`, deposit 125 token1, continuous mint 50. Claim mark value `141⅔` against 125 paid. Incumbents’ mark falls by `16⅔`. The tokens exist. The loss is bounded by the deposit and by how far `B`’s ratio sits from the pool. It is not infinite. A divergence gate can cap it. No particular basis-point figure is asserted to be enough.

Concentrated `D` does not track the pool like a full-range CP position. Wings outside the active tick keep their amounts until crossed (`LiquidityAmounts.sol:66-76`). `F` does not reprice. So `B` can diverge from spot without an attack. Virtual CP on `B` is then not the pool’s price.

## Other compatible shapes

1. **Virtual entitlement, external settlement.** Quote the same-token amount from the book curve (continuous identity returns the deposit before fees). Settle it by pro-rata removal plus one pool swap. Gross the swap fee once into a smaller output or a larger burn. Do not add a second fee on that notional.
2. **Pro-rata only.** Vault pays both tokens. The user may swap outside. Cleaner attribution. Weaker if the product must deliver one token.
3. **Do not price the curve on `D` alone.** That drops `F` and `E`. Ownership book stays `B`.
4. **Do not import oracle NAV** unless the owner replaces this preference. A reference price may be a gate (reject if internal ratio diverges too far). It is not a second mint formula.
5. **One-sided `B`.** `sqrt(B0·B1)` is zero if either leg is zero. Name the rejection. Do not silently use the linear branch in `StandardExchangeConstantProduct.sol:50-51`.

## Blocked and mixed states

An exit swap needs `unlock`. While blocked, pay only from `F`, or revert before burn if cover is short (`PRD` B4). Idle entry plus blocked exit cannot finish the external swap. That is capacity, not a license to pay one token and delete the other claim. Blocked entry leaves the deposit in `F` until a later idle placement. Do not charge placement cost until placement runs.

## Wing orientation

If spot is in the center, the lower range is token0 and the upper range is token1. PRD G1 and the historical “token1 in the lower wing” line are inverted.

## Choices, not ratifications

1. Mint on geometric mean of `B`, and exit by pro-rata plus one pool swap, with the pool fee borne once by the initiator.
2. Same mint, but the vault pays both tokens and does not swap.
3. Add a divergence **gate** before single-sided mint or the exit swap. The owner must name the source and the bound. This note does not.

Dual-sided entry remains min-ratio. None of these is approved by this research.
