# Canonical mint-quote domain

Initial arithmetic report for plan task 2. It does not implement the evaluator, close E3, or complete task 2. It does not answer fungible ancestry or TokenStaking.

The frozen credit for one original entitlement is the sum of two user outputs, each evaluated on the same unchanged book. It is not a bond-duration quote, not the gate-closed swap fallback, and not the mint's inventory or liquidity side effects.

## Canonical branch

For a contribution amount `x` of asset `a`, on frozen book `S`:

```text
pairEq   = contribution-to-pair preview on S, or x when x is already that pair
boosted  = floor(pairEq * (W + p) / W)
gross    = hook exact-in quote of `boosted` pair units for DETF, on S
user     = floor(gross * (W - p) / W)
U(a, 0)  = 0
C        = U(ETH, E) + U(DTF, D)
```

`W = 10^18`. `p` is the frozen seigniorage WAD. Both calls read `S` and neither writes it.

Source order:

1. Zero amount returns `(0, 0)` before any quote. `UniswapV4DetfTarget.sol:175-178`.
2. Pair conversion. `UniswapV4DetfCommon.sol:170-182`.
3. Boost. `UniswapV4DetfCommon.sol:259-261`, `Math.mulDiv` at `lib/crane/contracts/utils/Math.sol:178-180`.
4. Hook `previewExchangeIn(pair, boosted, DETF)`. `UniswapV4DetfCommon.sol:262`.
5. That call is a swap, not a join. Join requires `tokenOut == hook`. The output here is the DETF. `UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:20-32`, `UniswapV4BufferHookLiquidityRouteLib.sol:133-134`, `UniswapV4StandardExchangeWeightedBufferHookInQuoteBase.sol:14-29`.
6. The swap applies the trading fee once, maps the net input, then calls weighted math with fee 0. `UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:39-54` and `:136-144`.
7. User split. `UniswapV4DetfCommon.sol:121-127` and `DETFMintSplitLib.sol:19-23`.

`_entryPreviewMint` is not this function. If the live mint gate is closed it returns a swap-fallback output and gross 0 (`UniswapV4DetfTarget.sol:186-190`). `_mintPath` then joins liquidity, mints the user amount, and funds the pot (`:284-308`). Those effects are not inputs to `C`.

Excluded pricing:

- Duration bonus and unboosted self-leg: `_quoteBondPurchase`, `_quoteBondG`, `_splitBond` (`UniswapV4DetfCommon.sol:273-301`, `DETFMintSplitLib.sol:40-51`).
- Opening linear price: `_openingBondQuote` (`UniswapV4DetfCommon.sol:265-269`).
- Half-seigniorage split: `_splitHalfSeigniorage` (`DETFMintSplitLib.sol:8-16`).
- Gate-closed `previewSwapAfterExchange` (`UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol:366-375`). That path also fees a post-exchange asset amount and can scale the inflow again. It is not the mint branch.

## Units and stored constants

| Quantity | Unit | Source |
| --- | --- | --- |
| `W`, seigniorage, swap fee, weights, rates | `10^18` | `DETFMintSplitLib.sol:6`; hook `WAD` / `RATE_PRECISION` at `UniswapV4StandardExchangeWeightedBufferHookMath.sol:28-42` |
| Historical ETH/WETH and DTF contributions | 18-decimal native units | plan section 2.1. The quote consumes the amount it is given; it does not rescale a contribution to 9 decimals before `pairEq` |
| `pairEq`, boosted input, fee, net | pair-token native units | `_pairEq`, `_quoteMintGross`, `applyTradingFeeNet` |
| Rated balances and weighted inflow/outflow | `scaleTo` WAD units | `baseScale = 10^(36 - decimals)` (`UniswapV4StandardExchangeWeightedBufferHookMath.sol:48-51`) |
| `gross` and `user` | DETF native units | hook output token units after `_outputBudget` |
| This DETF package | 9 decimals | `UniswapV4DetfDFPkg.sol:234` |
| Hook LP | 18 decimals | `UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:284`. Not the credit unit |

For a 9-decimal DETF leg, `ratedScale = 10^27`. `scaleTo(10^9, 10^27) = 10^18` and `descale` returns `10^9`. One native unit round-trips: `scaleTo(1, 10^27) = 10^9`, `descale` returns `1`. The loss is not in that power-of-ten scale. It is in the fee, the weighted floors, and any buffer/rate floor.

`scaleTo` and `descale` are raw `(amount * rate) / 10^18` (`UniswapV4StandardExchangeWeightedBufferHookMath.sol:66-67` and `:85-87`). They panic if the product does not fit `uint256`. `baseScaleFromDecimals` reverts `MathDomain` outside decimals 6..36. Package validation is narrower for pair decimals: 6..18 (`UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:404-412`). Share decimals may be 6..36. A frozen evaluator must store the captured scales, not reread `decimals()` later.

Weights are the stored normalized weights. Each weight is at least `10^16`, the sum is `10^18`, and `n` is 2..8 (`UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:398-448`). The swap does not renormalize a subset. Interim `k` is not this quote.

The hermetic weighted fixture binds three sorted tokens, weights `4*10^17`, `3*10^17`, `3*10^17`, a raw DETF leg, and buffered pair legs (`TestBase_UniswapV4Detf_Weighted.sol:119-135`). Predicted DETF decimals are forced to 9 (`HookPkgArgsDecimalsLib.sol:15-16`). That is fixture shape, not a proof of historical wiring. The formula below is the code path, including the buffered-output branch the fixture does not take.

## Equations

`Math.mulDiv(x, y, d)` is full-precision `floor(x * y / d)`. It is not a wrapping 256-bit multiply.

Boost and user split use that function:

```text
boosted = floor(pairEq * (W + p) / W)
user    = floor(gross * (W - p) / W)
pot     = floor(gross * p / W)
```

`user` is not `gross - pot`. The two floors are independent. The residue is not credited. `C` uses `user` only.

The hook fee is raw truncating division, once, on the boosted pair amount (`UniswapV4StandardExchangeWeightedBufferHookMath.sol:100-104`):

```text
fee = floor(boosted * feeWad / W)    // panic if boosted * feeWad does not fit uint256
net = boosted - fee
```

`quoteSwapExactInContext` then calls `quoteExactIn(..., rateIn = W, rateOut = W, feeWad = 0)` (`ClaimLib.sol:141`). A second fee there is not the canonical quote.

Rated input, after that single fee (`ClaimLib.sol:63-73`):

```text
no SE:
  units = pairAmount                         if no rate provider
  units = floor(pairAmount * rate / W)       if a provider is set
  inflow = scaleTo(units, ratedScale)

disabled SE:
  inflow = scaleTo(pairAmount, ratedScale)   // no deposit preview

buffered SE:
  (shares, refund) = SE.previewExchangeIn(pair, net, SE)
  if shares == 0:
    inflow = scaleTo(refund, ratedScale)
  else:
    inflow = scaleTo(refund + ratedPairUnits(shares, rate, invScale, ratedScale), ratedScale)
```

`ratedPairUnits` (`UniswapV4StandardExchangeWeightedBufferHookMath.sol:57-63`):

```text
denom = W * (ratedScale / invScale)    if invScale <= ratedScale
denom = W / (invScale / ratedScale)    otherwise
units = floor(shares * rate / denom)
```

The refund word is pair-token native units, not output units (`ExchangeInAmount.sol:16-22`). `pairEq` discards it (`UniswapV4DetfCommon.sol:179`). The hook input map adds it. Those are different consumptions of the same tuple.

Rated book value of a leg (`ClaimLib.sol:77-90`, then `scaleTo` at `:60`):

```text
no SE, no provider:  raw
no SE, provider:     ratedPairUnits(raw, rate, invScale, ratedScale)
SE balance 0:        raw
SE balance > 0:      raw + ratedPairUnits(seShares, rate, invScale, ratedScale)
rated[i] = scaleTo(that, ratedScale)
```

A zero rate reverts `RateProviderFailed` (`ClaimLib.sol:93-99`). A buffered leg with shares and no provider reverts `RateProviderRequired`. An unknown registry package reverts `BufferFailed` rather than becoming a raw quote (`ClaimLib.sol:401-406`).

Weighted step, only after `inflow > 0` (`UniswapV4StandardExchangeWeightedBufferHookMath.sol:197-216`, `WeightedMath.sol:180-199`):

```text
revert MaxInRatio if inflow > floor(ratedIn * MAX_IN_RATIO / W)
netIn = inflow                         // fee argument is 0
aIn   = floor(netIn * W / W)           // identity if the multiply fits
revert MaxInRatio if aIn > floor(ratedIn * MAX_IN_RATIO / W)
base  = ceil(ratedIn * W / (ratedIn + inflow))
exp   = floor(weightIn * W / weightOut)
power = powUp(base, exp)
out   = floor(ratedOut * complement(power) / W)
revert ZeroAmount if out == 0
```

`MAX_IN_RATIO = 30*10^16` (`UniswapV4StandardExchangeWeightedBufferHookMath.sol:34`). The comparison is `>`, so equality passes. `ClaimLib.sol:140` checks the same predicate before `quoteExactIn`, and `WeightedMath.sol:186-188` checks it again. On this call the three predicates match when the products fit. They are not a 30% check on the pre-fee or pre-buffer amount.

`powUp` (`FixedPoint.sol:124-144`):

```text
y == 10^18:        x
y == 2*10^18:      ceil(x * x / W)
y == 4*10^18:      ceil(square * square / W), square = ceil(x * x / W)
otherwise:         LogExpMath.pow(x, y) + ceil(raw * 10000 / W) + 1
```

`complement(x) = W - x` when `x < W`, else 0 (`FixedPoint.sol:148-155`). `10000` is `MAX_POW_RELATIVE_ERROR`, a source adjustment, not a tolerance an evaluator may substitute. `LogExpMath.pow` reverts `BaseOutOfBounds`, `ExponentOutOfBounds`, or `ProductOutOfBounds` (`LogExpMath.sol:41-48` and `:96-140`). Its natural-exponent window is `[-41*10^18, 130*10^18]`.

The fixture pair-to-DETF exponent is `floor(3*10^17 * 10^18 / 4*10^17) = 750000000000000000`. That is not `10^18`, `2*10^18`, or `4*10^18`. The fixture quote takes the `LogExpMath` branch. Equal-weight and 80/20 shortcut results below do not replace it.

Output conversion (`ClaimLib.sol:146-168`):

```text
revert WouldZeroReserve if budget >= ratedOut
nativeBudget = floor(budget * W / ratedScale)

raw output leg:
  amountOut = nativeBudget
  revert WouldZeroReserve if amountOut >= rawReserves

buffered output leg:
  local = min(rawReserves, nativeBudget)
  deficit = budget - scaleTo(local, ratedScale)     if nativeBudget > local, else 0
  sharesOut = floor(floor(deficit * W / rate) * W / invScale)
  revert WouldZeroReserve if sharesOut > seReserves
  redeem sharesOut; revert UnwrapFailed if refund != 0
  amountOut = redeem.amountOut + local

revert ZeroAmount if amountOut == 0
```

The outer swap `previewExchangeIn` then returns `(amountOut, 0)` (`ExitQueryTarget.sol:32`). A nested refund is not returned to the DETF caller. On a raw DETF leg, `gross = amountOut = descale(budget, ratedScale)`. On a buffered output leg, `gross` is raw local plus redeemed assets, which is not that descale.

`pairEq` (`UniswapV4DetfCommon.sol:170-182`):

```text
if tokenIn == pair: pairEq = amountIn
else: pairEq = vault.previewExchangeIn(tokenIn, amountIn, pair).amountOut
if tokenIn != vault and amountOut == 0: revert InvalidRoute
```

A zero `pairEq` is not the zero-component rule. If the input is the share token, zero output is returned and the later hook quote reverts `ZeroAmount`. If it is another token, zero output reverts `InvalidRoute`. Only contribution amount 0 is defined as `U = 0`.

## Domain conditions

A successful positive quote requires all of the following. Any other result is a revert or the defined zero, as named.

| Condition | Result |
| --- | --- |
| Contribution amount is 0 | `U = 0`. Do not call `pairEq` or the hook |
| `tokenIn` is not a bound hook token | `_indexOf` reverts `"token"` (`UniswapV4StandardExchangeWeightedBufferHookRepo.sol:124-130`) |
| `tokenIn == tokenOut` | `InvalidPair` |
| Rated input or rated DETF balance is 0 | `SwapNotLive` |
| `feeWad >= W` | `InvalidFeeWad` |
| `feeWad == W` stored by the oracle | Setter allows it (`VaultFeeOracleRepo.sol:67-70`). The quote still reverts |
| `p > W` | `W - p` underflows in the user split. The setter allows only `0..W` |
| `p == W` | `Math.mulDiv` boost is exactly `2 * pairEq` when that result fits `uint256`. User is 0. This is a computed zero, not the zero-component short-circuit |
| `boosted * feeWad` exceeds `uint256` | Panic in `applyTradingFeeNet`. `Math.mulDiv` would not panic. The evaluator must not widen this multiply |
| `inflow > floor(ratedIn * 30*10^16 / W)` | `MaxInRatio`. Do not split the input to pass |
| `ratedIn + inflow` exceeds `uint256` | Panic inside `computeOutGivenExactIn` |
| Weighted `out == 0` | `ZeroAmount` inside `quoteExactIn` |
| `budget >= ratedOut` | `WouldZeroReserve` |
| Raw `amountOut >= rawReserves` or buffered `sharesOut > seReserves` | `WouldZeroReserve` |
| Buffered redeem refund is nonzero | `UnwrapFailed` |
| Native `amountOut == 0` | `ZeroAmount` in `_outputBudget` |
| `gross == 0` passed to the split | User and pot stay 0 (`UniswapV4DetfCommon.sol:123`). The swap path reverts before that on a zero output. Do not convert a revert into this zero |
| `floor(gross * (W - p) / W) == 0` for positive `gross` | Successful computed user 0. Distinct from a revert and from `U(a, 0)` |

`feeWad < W` and `amountIn >= 1` cannot make `applyTradingFeeNet` return 0: `floor(amountIn * (W - 1) / W) <= amountIn - 1`. The `netIn == 0` revert in `quoteExactIn` is not reached from that fee. It is reached when the rated inflow itself is 0, including a deposit whose shares and refund are both 0. That revert is not a zero credit.

For 9-decimal raw output, `budget = 10^9 - 1` descales to 0 and reverts `ZeroAmount`. `budget = 10^9` descales to 1. A later user split can still floor that 1 to 0 without reverting.

The live mint gate, synthetic price, and expansion supply are not frozen-quote inputs. Capture reads them only as part of building `S`. A later change must not be reread.

## One book, two components

`C = U(ETH, E) + U(DTF, D)` adds native DETF units. It does not add the pair amounts, and it does not quote `E + D`.

Each `U` is an exact-in swap from that component's pair leg into the DETF leg. The other legs' balances are not arguments. The shared DETF rated balance is an argument of both. Quoting ETH must not reduce it before quoting DTF, and the reverse. Quoting must not add the input to the pair leg before the other quote.

If both contributions convert to the same pair, they still use the unchanged input balance twice. Summing the pair amounts and quoting once is a different function. Merging two already quoted entitlements adds their stored credits. It does not run this function on the combined input.

A partial surrender is `floor(storedCredit * q / Q)`, or the whole remainder when `q == Q` (plan section 5.4). It is not `U(a, floor(x * q / Q))`.

## Noncommuting operations

Checked with JavaScript `BigInt` in the owned temp root. No floating point. `floor(x * y / d)` is full precision. Raw Solidity multiplies are reported as panics when the product does not fit `uint256`.

Hand-checked anchors: boost `1000 -> 1050`; fee `floor(1050 * 3*10^15 / 10^18) = 3`; split of gross 3 at `p = 5*10^17` is user 1, pot 1, residue 1; max-in limit of 1000 is 300 and the equal-weight output at 300 is 230; equal-weight output for balances `10^24` and input `10^21` is `999000999000999000000`; 9-decimal descale of `10^9 - 1` is 0 and of `10^9` is 1; fixture exponent is `750000000000000000`.

| Call | Result |
| --- | --- |
| `mulDivFloor(1000, 10^18 + 5*10^16, 10^18)` | `1050` |
| `applyTradingFeeNet(1050, 3*10^15)` | fee `3`, net `1047` |
| fee `1000` first, then boost | `1046` |
| `mulDivFloor(1050, 10^18 - 5*10^16, 10^18)` | `997`, not `1000` |
| `mulDivFloor(3, 5*10^17, 10^18)` and the pot floor | user `1`, pot `1`, `3 - pot = 2` |
| `mulDivFloor(1, 10^18 - 5*10^16, 10^18)` | user `0` for a positive gross |
| `applyTradingFeeNet(1000, 10^18)` | `InvalidFeeWad` |
| `mulDivFloor(1000, 2*10^18, 10^18)` and user at `p = W` | boost `2000`, user `0` |
| fee 50% on native `1`, then `scaleTo` by `10^30` | `10^12` |
| `scaleTo(1, 10^30)` then fee 50% | `5*10^11` |
| descale `10^9 + 5` by `10^27`, then split at `p = 1` | native `1`, user `0` |
| split `10^9 + 5` at `p = 1`, then descale | user `1` |
| `computeOut(10^18, 5*10^17, 10^24, 5*10^17, 1)` | formula out `0`, so `quoteExactIn` reverts `ZeroAmount` |
| equal-weight `computeOut(10^24, 5*10^17, 10^24, 5*10^17, 10^21)` | `999000999000999000000`, branch `y == 10^18` |
| same function at `5*10^20`, twice, same book | `499750124937531000000` each; sum `999500249875062000000` |
| `floor(full / 2)` | `499500499500499500000`, equal to neither the half quote nor half the sum |
| second half after input balance `10^24 + 5*10^20` and output balance `10^24 - 499750124937531000000` | `499250874063467266483` |
| 80/20 `computeOut(10^24, 8*10^17, 10^24, 2*10^17, 10^21)` | exponent `4*10^18`, branch `y == 4*10^18`, out `3990019965055916000000` |
| 80/20 half input, twice, same book | sum `3995004995628490000000`, not the full output |
| fee once on `10^21` at `3*10^15`, then equal-weight quote | net `997*10^18`, out `996006981039903000000` |
| same fee applied twice | out `993021927267099000000` |
| max-in `computeOut(1000, 5*10^17, 1000, 5*10^17, 300)` | `230` |
| same at `301` | `MaxInRatio` |
| `scaleTo(7 + ratedPairUnits(100, 12*10^17, 10^18, 10^18), 10^18)` | `127` |
| `scaleTo(1000, 10^18)` | `1000` |
| `floor(floor(20*10^18 * 10^18 / 12*10^17) * 10^18 / 10^18)` | `16666666666666666666` shares, greater than `seReserves = 10` |
| `mulDivFloor(2^200, 2^200, 2^200)` | `2^200` |
| raw `2^200 * 2^200` | panic, 401-bit product |
| separate equal-weight quotes of `4*10^20` and `6*10^20`, balances `10^24` | `399840063974410000000` and `599640215870477000000`; sum `999480279844887000000` |
| one quote of `10^21` on that same balance | `999000999000999000000` |
| input balances `7*10^23` and `9*10^23`, shared output `10^24`, each input `10^20` | frozen second `111098766803688000000`; after removing the first output, `111082897818285387803` |

`computeOut` is the `y == 10^18` or `y == 4*10^18` branch of `computeOutGivenExactIn` as read, with `divUp`, `divDown`, `mulDown`, `mulUp`, and `complement`. It is not a float approximation and not the fixture's `750000000000000000` exponent.

## Why a re-quote changes credit

The checked equal-weight and 80/20 branches are strictly non-additive on one book: `U(x) + U(x) > U(2x)`, and `floor(U(2x) / 2) != U(x)`. Moving the reserves between the two half quotes changes the second result again. Two different input legs that share the DETF balance also change when that balance is reduced between quotes.

The fee floor does not distribute over addition. `floor(1050 * fee / W)` is not the same composition as fee-then-boost. Decimal scaling does not commute with the fee. The user split does not commute with `descale`. A buffered `(refund, shares, rate)` tuple does not equal `scaleTo(net)`.

So a partial or merged re-quote is a different credit even before `LogExpMath` rounding. The stored full-input user amount, then integer allocation, is the operation that preserves `C`. Chunking a large input to avoid `MaxInRatio` is also a different function and is forbidden.

## Bare weighted math does not cover the buffered quote

`WeightedMath.computeOutGivenExactIn(rawPair, wIn, rawDetf, wOut, boosted)` is not `gross`.

The canonical input is the post-fee net, then an SE preview tuple, then `ratedPairUnits`, then `scaleTo`. The canonical balances are raw plus rate-scaled shares, then `scaleTo`. The canonical output is `descale` only for a raw leg; a buffered leg redeems shares and reverts on a refund. The fee is applied before that mapping and is not passed into `quoteExactIn`.

Univ3 full-spread and production ERC-4626 `previewExchangeIn` currently return a hardcoded refund of 0 (`UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol:11-15`, `ERC4626StandardExchangeInTargetExt.sol:12-16`). That does not delete the hook's refund addition. A preview that returns a nonzero refund, or a share amount whose rated value is not the net input, changes `inflow`. The `127` versus `1000` vector is that hook function on a supplied tuple. It is not an observed Univ3 receipt, and it is not something `computeOutGivenExactIn` can see.

The hermetic fixture's pair legs are buffered and its DETF leg is raw. Even there, the input side is the deposit/rate map. Two raw balances and the weighted formula do not implement it.

## Proof obligations

A later evaluator matches this branch only if all of the following hold.

1. Zero contribution returns 0 and does not call a zero-input quote.
2. Nonzero ETH and DTF are quoted separately on one captured book. Their user outputs are added. Reserves, rates, fees, and nested preview state do not move between them.
3. `pairEq` is the captured contribution-to-pair `amountOut`, or the amount itself when it is already the pair. Its refund word is not added. A nonzero input with a rejected zero conversion reverts rather than becoming 0.
4. Boost and user split are `Math.mulDiv` floors. User credit is not `gross - pot`, not gross, and not the bond split.
5. The trading fee is `applyTradingFeeNet` on the boosted pair amount, once. The weighted call receives fee 0 and rates `10^18`.
6. Rated inflow and rated balances use the captured scales, rate, raw balance, share balance, and nested preview tuple. Disabled, missing-provider, zero-rate, and unknown-package branches keep the source revert or skip.
7. `MaxInRatio` uses `>` against `floor(balance * 30*10^16 / W)` on the post-fee rated inflow. An out-of-limit input fails. It is not chunked.
8. The weighted power is `powUp`, including `LogExpMath.pow` plus the `10000` error adjustment when the exponent is not `10^18`, `2*10^18`, or `4*10^18`. The fixture exponent `750000000000000000` is in that general branch. A float or a 50/50 shortcut does not satisfy it.
9. Output uses `_outputBudget`: raw descale and reserve check, or buffered share conversion and exact redeem. `WouldZeroReserve`, `UnwrapFailed`, and `ZeroAmount` stay reverts.
10. `gross` is the hook `amountOut` in DETF native units. For this package that is 9 decimals. The 18-decimal hook LP is not credited.
11. `p` and `feeWad` are captured values. `feeWad >= 10^18` reverts. `p == 10^18` is a computed user 0. A positive gross whose user floor is 0 is also a computed 0, not a revert.
12. Overflow panics of the raw fee, scale, and balance addition stay panics. Replacing them with `Math.mulDiv` changes the domain.
13. No duration multiplier, opening linear price, inventory pot, liquidity self-leg, swap fallback, or live gate read enters `C`.

## Checks and limits

Checker: JavaScript `BigInt` in the session kernel, temp root `/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-domains.DKf5Yz`. No Forge process. No product, test, dependency, or plan edit.

Not executed here:

- `LogExpMath.pow`, `exp`, and `ln`. No numeric substitute is given for the fixture exponent.
- A live or fixture hook call. The vectors are the integer operations read from source, not a traced mint.
- The internal curve of each nested SE. The consumption of `(amountOut, amountRefunded)` is fixed above. Univ3 and ERC-4626 preview faces currently hardcode the refund word to 0; other previews and transition redeems need not.
- Historical route identity. Local fixture wiring is not the recovery deployment.

This file does not authorize implementation and does not close task 2.
