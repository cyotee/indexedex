# MiniMax member response

## Identity

- Member: minimax, council-member for run `v4-v2-lp-wrap-20261026-01a177b3`. Route `minimax/MiniMax-M3`. Not the coordinator; this is not a vote.
- Scope performed: read of admitted local files, and writing of this owned file only. No project code, tests, configuration, or Git were touched. No sub-agent was launched. No private source was sent to a search or fetch service.
- Authority: this is research. It is not implementation authority, and nothing below authorizes a patch.

## Question

1. Does the Uniswap V2 Standard Exchange mint vault shares from LP tokens received, and liquidate a holder's LP portion into one token, in a way that eliminates spot-price share manipulation?
2. If so, can an internal wrapper make a Uniswap V4 position play that LP-token role for the Wings vault?

The user's sentence ("the V2 vault mints from LP tokens and withdraws by liquidating the LP, therefore spot-price share manipulation is eliminated") is the hypothesis under test, not a finding.

## Sources

| Source | What was taken from it |
| --- | --- |
| `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol` | `_redeemLpSharesFrom`: share-to-LP conversion, the LP burn plus single-token sale, the `minimum_` check, `_checkpointVaultReserves`, `_calcVaultFee` inputs |
| `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol` | All seven routes in `_previewExchangeIn` and `_exchangeIn`: direct LP deposit, zap-in vault deposit, zap-out vault withdrawal, LP withdrawal |
| `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol` | `previewExchangeOut` and `exchangeOut` exact-out variants, `_exchangeOut_zapInVaultDeposit`, `_exchangeOut_passThroughZapIn`, the LP-backing check |
| `lib/crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol` | `_swapDeposit` (swap plus balanced `addLiquidity`), `_withdrawDirect` (pair burn), `_withdrawSwapDirect`, `_swap` with `minAmountOut = 1` |
| `lib/crane/contracts/utils/math/BetterMath.sol` | `_convertToShares` / `_convertToAssets` exact formulas and rounding directions |
| `lib/crane/contracts/utils/math/ConstProdUtils.sol` | `_calculateFeePortionForPosition`: the price-normalised fee-yield baseline |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol` | `Inventory.principal`: what a V4 position's principal is and that it depends on `sqrtPriceX96`; `earnedFee` is separate from principal |
| `.../UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol` | `issue` and `entitlement`: the current Wings mint and payout equations |
| `.../UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` | `_deposit` (target-only pull, harvest, quote, issue, place), `_redeem` (entitlement, `_fund`, `_changeTarget`, `HolderValueLoss`), `_fund`, `_swapDeficit`, `_pull`, `_changeTarget` |
| `.../UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol` | `getRate` as whole-book quote times `1e18` over supply |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | Held-reserve valuation rule (APEX D60): a hook values a held reserve as raw balance, or balance times a rate provider; never a rate derived from the Standard Exchange it holds |
| `docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md` | The prior three mechanisms (quote manipulation, executed-price allocation, vault self-fill) and the prior finding that a deposit swap plus an exit swap is not a fix. Cited, not rerun. |

## Observations

### 1. The V2 LP-to-share conversion is genuinely price-free in form

Direct LP deposit, `UniswapV2StandardExchangeInTarget._exchangeIn`, route "Underlying Pool Vault Deposit" (`tokenIn == pool`, `tokenOut == vault`):

```
liveBefore   = pool.balanceOf(vault)
reserveBefore= pretransferred ? liveBefore - amountIn : liveBefore
amountIn     = LP actually received (delta-checked transfer)
shares       = BetterMath._convertToSharesDown(amountIn, reserveBefore, vaultTotalShares, d)
             = floor( amountIn * (S + 10^d) / (reserveBefore + 1) )
```

`S` is the vault share supply after `_calcAndMintVaultFee` in the same call, `reserveBefore` is the vault's LP-token balance in raw LP units, `d = _decimalOffset()`.

The units on both sides are LP tokens. `getReserves()` is called in this branch, but only through `_loadIndexSourceReserves`, and the reserve values it returns feed `_calcAndMintVaultFee` only. They do not enter the share count. The user's narrow claim holds here: **the LP-to-share leg does not read a spot price.**

Two secondary observations on the same leg:

- The denominator is the vault's *live* LP balance, so an LP donation raises the denominator and dilutes the next depositor rather than inflating their share of the book. The zap-in route instead reverts when the live LP balance does not equal the booked reserve (`if (indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve) revert()`), so it refuses an unbooked surplus outright.
- The fee leg is price-normalised by construction. `ConstProdUtils._calculateFeePortionForPosition` rebuilds the "no-fee" baseline at the *current* reserve ratio (`sA = initialA * initialB * reserveA / reserveB`) and clamps impermanent loss to zero, so the fee yield is measured against fee growth rather than against price change. The fee share mint is therefore not a meaningful spot-price channel, though it does read live reserves.

### 2. The V2 single-token deposit (zap-in) does consume the spot price, through the quantity

`UniswapV2StandardExchangeInTarget._exchangeIn`, route "ZapIn Vault Deposit":

```
lpReceived = router._swapDeposit(pool, tokenIn, amountIn, opToken)   // live-price swap, then addLiquidity
shares     = floor( lpReceived * (S + 10^d) / (vaultLpReserve + 1) )  // vaultLpReserve = booked LP, pre-zap
```

`_swapDeposit` reads the pool reserves at execution (`_sortReserves(pool, tokenIn)`), computes the swap portion from those reserves, swaps `tokenIn` for the opposing token at the live price, and calls `addLiquidity`. `addLiquidity` mints `min(a * totalSupply / reserve0, b * totalSupply / reserve1)`, so the LP quantity received per unit deposited scales with the pool's reserve ratio, that is, with the spot price.

The share *formula* has no price term, but its *input* does. A depositor who is routed into this branch while the pool price has been pushed against their token receives fewer LP units, and therefore fewer shares, for the same nominal deposit. The price has been relocated from the formula into the quantity. This is the same relocation the prior report identified for the swap-based designs, one level down.

### 3. The V2 single-token exit sells the withdrawn opposing token at the live price

`UniswapV2StandardExchangeCommon._redeemLpSharesFrom`:

```
lpOwed    = floor( shares * (R + 1) / (S + 10^d) )        // R = vault LP reserve, price-free
(amount0, amount1) = pool.burn(lpOwed)                   // proportional to CURRENT reserves
amountOut = targetLeg + router._swap(opposingLeg -> target)   // live-price sale
```

`_withdrawSwapDirect` burns the LP into `amount0`/`amount1` proportional to the pool's current reserves, keeps the requested token's leg, and sells the other leg into the same pool with `swapExactTokensForTokens(..., minAmountOut = 1, ...)` at the router level. The vault-level `minimum_` check applies to the final `amountOut`.

Two properties of this exit:

- The quantity the holder redeems is price-free (LP units), but the composition of the withdrawal is proportional to live reserves and the opposing leg is sold at the live price. So the holder's proceeds are price-dependent at execution time.
- The tokens being sold come out of the vault's own LP. If the vault is a large share of the pool's liquidity, the holder's exit is substantially filled by the vault itself, and the price impact that the sale creates lands on the vault's remaining LP and on the pool's other LPs.

### 4. What a V4 position is, for this comparison

`Inventory.principal(sqrtPriceX96, lower, upper, liquidity, roundUp)` returns `amount0` and `amount1` computed from the square-root price clamped into the range. The principal of a V4 position is therefore a *price-dependent* quantity: it changes as the pool price moves, with no trade. `Inventory` also states that fees are never treated as converted principal, and `composition` explicitly allows a one-sided position.

The price-free quantity a V4 position offers is its **liquidity** `L` (and a count of positions). `L` does not change when the price moves; the tokens it can withdraw do. This is the same shape as V2's LP token: in V2 the LP unit does not change when the price moves, and the tokens it can burn out do.

### 5. The current Wings mint and payout, for contrast

`UniswapV4UpperLowerWingsStandardExchangeVaultMoney._deposit`: pull the target token, `_harvest()`, read `Quote.quote(...).value`, `shares = Accounting.issue(supply, value, credit) = floor(S * D / V)`, then `_changeTarget` and `_place()`. The entrant's deposit is not traded. `_redeem` pays `Accounting.entitlement(supply, value, shares) = floor(shares * V / supply)` from the same whole-book quote, funding it with `_fund`, which closes positions and, if the sleeve is short, `_swapDeficit` sells the whole local opposing balance rather than only the redeemer's slice.

The structural difference from V2 is not the presence or absence of a swap. It is that the Wings vault prices a *marked book value* `V` and issues against it, whereas the V2 vault issues against a *quantity* of a claim token and pays out by *executing* the claim. That is the part of the V2 pattern worth copying.

### 6. What an internal V4 wrapper would have to emit

For the outer conversion to be the same kind of object as a V2 LP token, the wrapper must emit a **quantity of a claim**, not a mark of the position:

1. **A fungible unit whose meaning is price-free.** The unit must be liquidity-denominated (`L`) or a count of position units. It must never be `principal.amount0 + principal.amount1`, nor any price-weighted scalar, nor the `Quote.quote` value. A wrapper that marks at the sqrt price reintroduces exactly the defect the V2 pattern removes, and does it with two price-dependent legs instead of one.
2. **A wrapper reserve the outer vault can book in the same units**, so the outer conversion is a single ratio: `shares = floor( units * (S + 10^d) / (W + 1) )`, `W` = wrapper units held. This is structurally identical to the V2 equation with LP tokens replaced by wrapper units.
3. **A redemption path that executes.** Burn wrapper units, remove the corresponding liquidity, receive the two token legs at the then-current sqrt price, and sell the opposing leg into the pool. The payout must be the executed result, not a marked value. This is what the V2 exit does and what the Wings `entitlement` does not.
4. **Fees handled separately and by quantity.** V2 LP tokens accrue fees automatically because the pair's `totalSupply` grows. A V4 position does not: `Inventory.earnedFee` is deliberately outside principal. The wrapper must either allocate harvested fees per unit (a pure quantity split, price-free, feasible) or accept that a unit's meaning drifts relative to principal.
5. **A book the unit can honestly represent.** A V2 LP unit is a proportional claim on one pool's two reserves, so the composition is always defined by one curve. The Wings book is a core position plus an upper and a lower wing over different ranges, plus idle balances of both tokens, and wings can be one-sided. A single fungible unit across heterogeneous ranges has no fixed per-unit composition; it either restricts the book or drifts into being a mark.
6. **Compliance with the held-reserve valuation law.** If the Wings vault becomes a reserve held by a buffer hook, the hook's rate must come from a rate provider or the raw balance. A hook must not derive a rate from the Standard Exchange it holds, so the wrapper cannot be used as a price source for a holder of the vault.

### 7. Mint equation and exit execution of the adapted design

Deposit, target token in, wrapper units out (the shape the wrapper forces):

```
units  = wrapper.mintFromLegs(targetLeg, opposingLeg)   // tokens -> L at the current sqrt price
shares = floor( units * (S + 10^d) / (W + 1) )           // W = wrapper units held; no price term
```

Exit:

```
unitsOwed = floor( shares * (W + 1) / (S + 10^d) )
legs      = wrapper.redeem(unitsOwed)                    // remove L; (amount0, amount1) at current sqrt price
amountOut = targetLeg + pool.swap(opposingLeg -> target) // executed at the live price
```

`getRate` under this design must be the one-whole-share preview of that execution, which is price-dependent by construction. It stays a withdrawal-and-sale preview and is not a NAV. The wrapper does not change what `getRate` is.

### 8. Where the price can sit in the adapted design

Three placements are possible, and the choice decides who bears the price:

- **Price in the entrant's conversion.** The entrant's target tokens are converted into `L` at the current sqrt price, so the entrant gets fewer units, and fewer shares, for the same deposit. This is the V2 shape: the price is on the entrant.
- **Price in the vault's placement.** The entrant's tokens are booked as idle target and credited at a price-free quantity ratio; the vault converts idle balances into `L` later, as a vault operation. The share count stays price-free, but the placement's slippage is borne by the vault, that is, by all holders. This creates a dilution channel on the vault side that the V2 pattern does not have, because in V2 the depositor's swap risk is the depositor's.
- **Price nowhere on issuance.** This is the pure idle-token case, with no position and no yield. It is price-free end to end and needs no wrapper, but it is not the Wings product.

### 9. Triage of the prior three mechanisms

| Mechanism (prior report) | V2 pattern | Adapted V4 wrapper |
| --- | --- | --- |
| Quote manipulation | Removed from the share formula. **Relocated** to the zap input, where the LP quantity scales with the live price, and to the exit, which is executed rather than marked. | Same, on condition the wrapper unit is price-free. If the wrapper marks principal, this returns in full and worse. |
| Executed-price allocation | **Removed on the deposit leg** for the swapped route: the entrant's own token is traded and the minted LP is pro-rata, so the vault's per-unit book is unchanged and there is no acceptance-time ownership distortion. **Remains on the exit leg**, where the burn-plus-sell moves the pool price and the vault's remaining LP absorbs the impact. | Same, with the extra caveat that a design that places on the vault's behalf reintroduces a dilution channel on the vault side. |
| Vault self-fill | **Remains on the exit leg.** The exit sells tokens withdrawn from the vault's own LP back into the pool the vault sits in. If the vault is a dominant LP, the holder's exit is largely filled by the vault, and the impact lands on remaining holders. | Same, and sharper: a V4 wing can be one-sided, so the exit may have to close a wing and sell in order to raise the target, which is more sale dependence, not less. |

The prior report's finding stands unchanged and is not rerun here: a deposit swap plus an exit swap is not a fix on its own. What the V2 pattern contributes is narrower and different. It shows that the mint can be made quantity-proportional rather than value-marked, and that the payout can be made an execution rather than a quotation.

## Conclusions

**Verdict: yes-only-if**, and the "if so" premise of the second question does not hold.

1. **Does the V2 pattern eliminate spot-price share manipulation? No.** It removes the spot price from the LP-to-share conversion, and that is the whole of what it removes on that leg. The mint equation `floor(lp * (S + 10^d) / (R + 1))` reads no price, so that leg is price-free. But the manipulation is not eliminated from the product; it is moved to two places. On the single-token deposit, the LP quantity the depositor receives is produced by a live-price swap plus `addLiquidity`, so the share count per unit deposited still scales with the manipulated price. On the single-token exit, the LP burn returns a composition proportional to live reserves and the opposing leg is sold into the same pool at the live price, so the holder's proceeds and the remaining holders' LP are both exposed to a price move at exit. The accurate statement is the one the brief anticipates: **the V2 pattern avoids spot on the LP-to-share leg.** It does not deliver elimination.

2. **Can an internal wrapper make a V4 position play the LP-token role? Yes-only-if.** It can, under these conditions: the wrapper emits a price-free quantity (liquidity or position units) and never a priced mark of the position; the outer vault books wrapper units as its reserve and converts with the same single-ratio equation; the redemption removes liquidity and sells the opposing leg at the live price rather than paying a marked value; and the fee accounting is rebuilt, since V4 fees are not converted principal. Under those conditions the adapted design reproduces the V2 issuance-leg property, namely a price-free share formula with no acceptance-time ownership distortion, and a redemption that is executed rather than quoted. It does not reproduce an elimination of spot-price manipulation, because none exists in the V2 pattern to reproduce.

3. **Which prior mechanisms remain.** Quote manipulation is removed from the share formula and relocated to the quantity input and to the exit; it survives for the single-token deposit and for every exit. Executed-price allocation is removed on the deposit leg for a swapped deposit and remains on the exit leg. Vault self-fill remains on the exit leg, and the one-sided V4 wing makes the exit more dependent on executed sales than the V2 exit, not less.

4. **What the adaptation does not provide.** It provides no independent price. It provides no protection against a sandwich on the single-token deposit, whose price dependence is unchanged in kind. It provides no protection for remaining holders against exit-time price impact, and no removal of self-fill. It does not restore the V2 property of a single proportional claim on one curve, because a core-plus-wings book has no homogeneous unit; the wrapper either restricts the book or lets the unit's meaning drift, which is a mark by another name. It does not carry fees as converted principal. It does not change `getRate`, which stays the one-whole-share withdrawal-and-sale preview and is not a NAV. And it is a proposal, not implementation authority.

## Coverage

| Target | Status | Reason |
| --- | --- | --- |
| V2 LP-to-share mint equation and whether a spot price enters it | examined | Direct LP deposit and zap-in routes in `UniswapV2StandardExchangeInTarget`, `BetterMath` formulas |
| V2 single-token deposit path and whether a spot price enters the zap | examined | `_swapDeposit` in `UniswapV2Service`; `addLiquidity` mint rule; the pre-zap reserve guard |
| V2 single-token exit path and what is sold | examined | `_redeemLpSharesFrom`, `_withdrawSwapDirect`, `_withdrawDirect`, `_swap` |
| Fee leg sensitivity | examined | `_calculateFeePortionForPosition` in `ConstProdUtils` |
| Whether the pattern eliminates or moves the prior manipulation | examined | Triage against the prior report's three mechanisms; the prior report is cited, not rerun |
| What a V4 wrapper must emit | examined | `Inventory.principal` and `earnedFee`; Wings book shape in `_fund` and `_oneSided`; held-reserve valuation law |
| Mint equation and exit execution of the adapted design | examined | Derived from the V2 equations with the wrapper unit substituted; no code written |
| V4 liquidation quote internals (`Quote.quote`, `Projection`) | not examined | The prior report already documents that path; the conclusion here does not depend on its internals |
| Foundry execution, forge tests, adversarial suite, audit PoC | not examined | Out of scope for a research member; no test was run and no number here is a measured profit |
| `ConstProdUtils._quoteSwapDepositWithFee` and `_quoteZapOutToTargetWithFee` internals | not examined | Read at call-site level only; the reserve dependence is visible from the arguments passed |

## Uncertainty

- **Direction and size of the zap-in quantity sensitivity** is argued from the structure of `addLiquidity` and the reserve-sorted swap, not from a numeric trace. The qualitative claim, that LP received per unit deposited scales with the pool's reserve ratio, is solid; the elasticity is not measured here.
- **Whether the fee leg is fully price-neutral** is a reading of `_calculateFeePortionForPosition`'s intent, which rebuilds the no-fee baseline at the current reserve ratio and clamps IL to zero. Residual sensitivity at extreme price ratios is possible and was not measured.
- **The self-fill comparison between V2 and V4** is structural. Whether the vault is a dominant LP in either case is a deployment fact I did not check, and the sign of the effect on remaining holders depends on it.
- **The multi-range unit problem** is the least settled part. I am confident that `L` is the only price-free quantity a V4 position offers, and that a single fungible unit across a core plus two wings has no fixed composition. Whether a wrapper can maintain a defensible unit across range changes, harvests, and closures is a design question I did not answer.
- **Whether the adapted design's `getRate` can be made an accurate execution preview** for one whole share, given a one-sided wing that must be closed to raise the target, is untested here.

## Limits

- This is a source-reading result. No contract was compiled, no test was run, no deployment was made, and no profit figure in this document is measured. The prior report's numbers are cited as prior evidence, not re-executed.
- Line-level claims are from the tree opened for this session and may drift.
- The conclusion is about the V2 pattern as it exists in this repository and about the shape an adapted V4 design would have to take. It is not a statement that the Wings vault is currently exploitable, and it is not a specification.
- The prior report's three mechanisms are treated as the named mechanism set. A mechanism outside that set is not addressed by this response.
- No proposal here is implementation authority, and no defect identifiers, severities, or patches are included.
