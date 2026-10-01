# Grok — Adjudicated FullSpread plan

**Date:** 2026-09-27. Peers read in full: Astra, MiniMax M3, Kimi K3 originals. Untrusted evidence. No cross-reviews. `GROK_ORIGINAL.md` unchanged. This file is the adoptable plan.

Pons identity is `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` (`ROBINHOOD_MAIN.sol` 441). Official docs and graduated pools using that hook are sufficient. No runtime-bytecode gate. Equivalence is not claimed.

## Corrections

| Claim | Verdict |
|---|---|
| Grok E6 radical `f = 1 - sqrt(1 - out/X)` plus two forward checks is the closed form of `_singleExit` | **Withdrawn.** `_singleExit` (`StandardExchangeConstantProduct.sol` 98–111) is nested floors, not the real quadratic. Two checks do not prove every integer. Source-only policy: do not adopt the radical or `UniswapV4FullSpreadClosedFormCandidate.sol`. |
| Kimi DER-1..5, including a `while` adjust and tick-walking as closed form | **Not adopted.** DER-1’s loop is search. DER-2..5 are new derivations, not designated helpers. `UniswapV4Quoter` tick traversal is evaluation, not an inverse (PRD line 214). |
| Astra 32 bisection probes find the integer root | **Not a precision claim.** Thirty-two probes do not exhaust a `uint256` bracket. Bound the work and revert if no probed candidate meets the 1 bp test. |
| MiniMax `_singleExit` denominator `reserveOther + entitlementOther` | **False.** Source adds `floor((reserveOut - entitlementOut) * entitlementOther / reserveOther)` (lines 107–109). |
| MiniMax collect-before-credit / sync-first accounting | **Reject.** PRD line 160: credit before fee collection. |
| MiniMax path count “40 entries” as the deletion set | **Directory entries, not files.** Recursive read: protocol tree **49 files** (44 Solidity + 5 docs). Unsegmented tree **38 files** (36 Solidity + PRD + `.DS_Store`). Kimi’s 36 Solidity undercounts the protocol tree. |
| Grok original mint-then-place | **Withdrawn.** D4 is composition, then allocation, then mint. |
| `LiquidityAmounts` or one unlock proves a combined quotation | **False.** Placement is algebraic only as the certificate below. |

## Adopted arithmetic

**Mint.** `m = min(floor(S*C0/B0), floor(S*C1/B1))` (`StandardExchangeConstantProduct.sol` 52–56). Idle alignment: `10000*m*B_i >= 9999*S*C_i` for both legs. No dust waiver.

**Blocked exact-share mint.** Existing inverse only (`78–95`): `A = K + ceil(m*K/S)`, `c = ceil(A*A/Bother) - Bin`, linear `ceil(m*Bin/S)` if the other reserve is 0. Test `forward(c) >= m` and `forward(c-1) < m`. Not an idle substitute.

**Blocked exact-in redemption.** Forward `_singleExit` only. Two-leg exact-output inverse is **not** adopted. `InvalidRoute`. Exact-in remains.

**One-leg exact-output.** `b = ceil(out*S/Bout)` only when the other reserve is 0. Source linear branch.

**Pool exact-out.** One `SwapMath.computeSwapStep` exact-output branch (`SwapMath.sol` 52–105) and `getNextSqrtPriceFromOutput` (`SqrtPriceMath.sol` 156–175). Fee `ceil(net*f/(1e6-f))` with `swapFee = calculateSwapFee(directional pf, lpFee)` (`ProtocolFeeLibrary.sol` 39–45). Reject if the step reaches the next initialized tick or `swapFee >= 1e6`. Multi-tick walking is not this equation.

**Pons.** `h(n) = floor(n*hookFeeBps/10000) + floor(n*creatorTaxBps/10000)` from `launches` words 10 and 7. Exact-in: output minus `h(output)`. Exact-out: input plus `h(input)`. Not the global setter.

**Sleeve.** `target = floor(T*p/(1e18+p))`. Band `max(10^max(decimals-6,0), floor(target*5/100))`.

**Rho.** At price `s` and range ends `a,b`, use cross-products of `T0*(s-a)` and `T1*(1/s-1/b)` in Q96, not a rounded one-unit probe. `rho = abs(X-Y)/max(X,Y)`. Stop trades when `rho <= 1/10000` and both sleeve deviations are inside band.

## CPPlace certificate

After a closed-form user leg, fees already collected, and user payout reserved:

`budget_i = D_i + F_i - target_i`. `L* = LiquidityAmounts.getLiquidityForAmounts` on both budgets and the fixed ticks. Try `L*` and `max(L*-1, L0)` only. Pick the highest affordable. No second pass and no holder swap inside this function.

**Certificate passes** only if that evaluated terminal state has `rho <= 1 bp` and both sleeve deviations inside band, or both thresholds already held and placement liquidity delta is 0. Otherwise the combined quotation does not exist.

## Adjudicated matrix

Both families. Pons applies `h` on external swaps. Blocked paths do not call the hook.

| Route | Idle | Blocked | Maintenance |
|---|---|---|---|
| `exchangeIn` token→shares | Bounded composition (max 8 forward probes, 64 quote steps). If none meet 1 bp, revert `AlignmentNotAchievable`. Then CPPlace, then mint. | Source one-sided mint. No unlock. | Placement is required allocation, not holder repair. |
| `exchangeIn` shares→token | Proportional removal and Q4 conversion. Then one public-style repair step that may no-op. | `_singleExit` if locally covered. | Repair after the user leg. |
| `exchangeIn` token↔token | Forward pool swap, finite quote steps. Then one repair step or no-op. | `UnsupportedRoute` before pull. | Not a sleeve route. |
| `exchangeOut` token↔token | One-step exact-out **only if CPPlace certificate passes**. Else `UnsupportedRoute` before funding. | `UnsupportedRoute`. | No D19. Exact-in sibling remains. |
| `exchangeOut` token→shares | `UnsupportedRoute`. No adopted inverse of idle composition. | Source CP inverse. | No D19. Idle exact-in remains. |
| `exchangeOut` shares→token | One-leg / no conversion: `ceil(out*S/Bout)` plus CPPlace certificate. Else `UnsupportedRoute`. | One-leg inverse only. Two-leg `UnsupportedRoute`. | Exact-in `_singleExit` remains. No radical. No bisection. |
| `exchangeInManyToOne` | Dual `min()`. Surplus booked. Then CPPlace. | Same mint, no unlock. | Not the 1 bp zap gate. |
| `exchangeOutOneToMany` | **D19 row.** If CPPlace certificate fails, still execute algebraic equal-ceil burn and required removal. Do not holder-swap. Document the omission. If the certificate passes, include that placement. | Local cover or `InsufficientLocalReserve`. No unlock. | Only mode of this vector. Do not treat dual join as its exact-in twin. |
| `rebalanceLiquidReserve` | Place first. If still off target, one holder swap sized to the 25 bp or next-tick boundary, then one CPPlace. If terminal `(rho, sleeve)` is not strictly better, no swap. | `PoolManagerInteractionBlocked`. | Not an exact-output cell. |
| `importPosition` | Existing dual-funding import. Hook must match the package. | Reject before import. | Not exact-output. |

Product `InvalidRoute` is implemented as `UniswapV4Exchange_UnsupportedRoute()` (`Common.sol` 307) unless a shared `InvalidRoute()` selector is already on the SE interface used by previews. Previews revert that same error. They do not return zero.

## Work bound

Exact-in composition: at most 8 evaluated quotes. Public repair: at most one boundary-sized swap plus one placement. Neither bound is a root certificate. Failure is revert or truthful no-op, not a claim that the last probe was optimal.

## Tests that must be written

1. Preview amount equals execution amount on every supported cell at the same state, including SY `deposit`/`redeem` versus `exchangeIn`/`exchangeOut` and transition quotes versus direct previews.
2. Blocked exact-share mint: forward of `c` mints at least `m` and forward of `c-1` does not. Source helper only.
3. Two-leg blocked exact-out and idle token→exact-shares revert `UnsupportedRoute` before balances change.
4. One-step exact-out that fails the CPPlace certificate reverts before pull. Dual exact-out that fails the certificate still pays the algebraic basket and does not swap.
5. `h` uses launch words 10 and 7. Changing global `hookFeeBps` does not change a registered pool.
6. Credit is measured before `collect`. Post-success `reserveOfToken == balanceOf` for both pool tokens and the self-share.

## Families and files

Separate HP and PP trees as Astra §5. Pons may import only `HPInventoryMath`, `HPProtectionMath`, and `HPRouteTypes`. No shared quote, callback, or execution type. Package salts are the new contract names. Do not reuse the current FullSpread facet salt.

**Deletion counts, after the readiness record:** protocol tree 49 files (44 Solidity listed by Astra §7.1 plus the five PRDs). Unsegmented tree: delete the 36 Solidity files Astra listed; deprecate the constant-product PRD; leave `.DS_Store` out of the vault deletion; preserve `fullSpread/hookless/**` and `fullSpread/ponsFamilyV2Hook/**`. Do not delete `StandardExchangeConstantProduct.sol` or Crane v4 core.

Old buffer, full-range, vault-plan, and V4 constant-product PRDs are deprecated with the code. Do not reconcile them into current law.

## Irreducible gap

No source helper inverts idle composition-plus-`min()`, and the radical does not equal integer `_singleExit`. Those exact-output cells stay `UnsupportedRoute` until a later owner-approved formula. That is a domain limit, not a proof that no formula could exist, and not permission to search.

**Saved:** `docs/research/uniswap-v4-plan-specification-2026-09-27/GROK_CROSS_REVIEW.md`
