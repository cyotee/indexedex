# Grok replacement original: mandatory scalar routes and one-sided wings

**Date:** 2026-10-03. **Author:** fresh Grok (`xai/grok-4.7`), retained replacement session. Independent first pass for this question. Prior-round history is acknowledged, not treated as a peer reading and not erased. No peer artifact was read. Not consensus. No implementation, measurement, or gas claim. Basket-only is rejected because the owner now requires scalar entry and exit.

## 1. Ranked recommendation

**Yes, without a sizing search, if valuation and placement are split.** A one-sided wing deploys token A with closed-form liquidity. It does not price A against an existing A+B book. Fungible synchronous shares still need an admission rule. The rule that keeps `exchangeIn(token→shares)` and share→one-token exact-input working while PoolManager is already unlocked is the existing internal constant-product settlement, not the wing.

**Rank 1 — adopt if the owner accepts an internal market.** Value scalar entry and the matching scalar exit on the complete book with the current integer constant-product helpers. Credit the token locally first. While unlocked, stop there: no nested unlock, pay exits only from actual local cover. While idle, optionally place leftover token into one aggregated out-of-range wing. Consolidate a wing that has entered range by a swap-free limiting-leg add to the existing full-range core. Residuals stay booked.

**Rank 2 — same valuation, wing placement on the idle user path** when the canonical wing is still strictly one-sided. Same economics as rank 1. More of the deposit is deployed immediately. Same unlocked fallback. More position-state risk.

**Rank 3 — owner-approved external valuation, still search-free.** Mint as if the missing leg were notionally purchased at a frozen TWAP or independent price minus an explicit spread, then place the real token in a wing or in `F`. This is a new oracle policy, not a silent use of the pool spot. Wings do not make the oracle safe.

**Do not adopt as the share rule:** wing liquidity units across unequal ranges; async wing receipts; basket-only; spot NAV of this pool; a quadratic-plus-one-check treated as an integer identity. The quadratic remains an unproved candidate, not a proof that no direct external formula exists. It also cannot run while the manager is unlocked, so it misses the buffered-pool case even if later proved.

Removing only binary search, while leaving `zapSplitWad`, `_faceForClaim`, or `_invertBufferForEffective` in ordinary quotes, does not meet the preferred bar. A fixed set of at most three positions is not a sizing search. A loop that tries wing widths until one fits would be.

## 2. Why a wing does not price the book

V4 position key is `keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))` (Context7 `/uniswap/v4-core`, `Position.calculatePositionKey`, accessed 2026-10-03). Out of range, principal is one-sided: price at or below the range holds only token0; price at or above the range holds only token1 (`LiquidityAmounts.getAmountsForLiquidity`; `modifyLiquidity` delta is amount0-only below the range and amount1-only above it).

So a token0 wing must sit strictly above the current tick, and a token1 wing strictly below it. Adding liquidity there consumes only that token. That answers placement. It does not answer `m` when `B1>0` and the caller supplied no token1. `min(floor(S*C0/B0), floor(S*C1/B1))` is then zero. Liquidity in a far wing is not interchangeable with liquidity in the full-range core, so `L_wing/L_core` is not a value. An in-range wing already holds both tokens in that wing's ratio, which is not the core's ratio and not a license to add one token.

The owner's consolidation step is real and can be search-free. It happens after admission. It cannot be the admission formula.

## 3. Rank 1 equations and domains

Raw units. Complete book, fees once:

```text
B_i = Dcore_i + Dwing0_i + Dwing1_i + F_i + E_i
```

Caller credit is excluded. Collection is `(F,E)→(F+E,0)` per position touched, once. `E` is not local cover. No new entry fee. Internal settlement is fee-free. A later pool swap, if any, pays protocol and LP fees; own LP recovery belongs to the book once.

**Scalar exact-input deposit, both manager states, `S>0`, both legs positive.** Other amount is zero. Use `StandardExchangeConstantProduct.sol:58-64`:

```text
K = ceil(sqrt(Bin*Bother))
A = floor(sqrt((Bin+c)*Bother))
m = A>K ? floor(S*(A-K)/K) : 0
```

Reject `m=0`. Conservation: `B'=B+c*e_in`, `S'=S+m`. No invented opposite transfer. The fixed-state branch is built so rounding surplus stays with holders. That does not prove safety after a donation, a pool move of `D`, or a later consolidation. It is the admission rule, not a claim of external-market fairness.

**Exact-share input, both states.** `_amountInForShares` (`:78-95`):

```text
Areq = K + ceil(m*K/S)
c = ceil(Areq^2/Bother) - Bin
```

Mint exactly `m`. Surplus wei stays in the book. This is arithmetic, not a probe. Extend `quoteInputForExactShares` to idle as well as blocked. Today it reverts when idle (`InQueryTarget.sol:29-31`).

**Scalar exact-input exit, matching curve.** `_singleExit` (`:98-110`):

```text
u = floor(Bout*r/S)
v = floor(Bother*r/S)
y = u + (v==0 ? 0 : floor((Bout-u)*v/Bother))
```

Require `0<r<S` when the other leg is positive. Pay `y` of the requested token only. The other entitlement stays in the book. That is the internal swap against holders.

**Exact-output share redemption** of a requested token amount stays `InvalidRoute` when both legs are positive. `_sharesForSingleExit` (`:113-128`) bisects. A radical inverse is not adopted; the plan already has a hand counterexample where it misses (`plan:95`). Zero opposite backing keeps the linear inverse `ceil(y*S/Bout)`. Do not widen that cell silently.

**Empty.** Dual F0 only. `raw=floor(sqrt(C0*C1))`, caller `raw-minimum`, dead-sink unchanged. No unilateral activation.

**One positive leg.** Linear `floor(S*c/B)` and `floor(r*B/S)` on that leg only. Reject a deposit into the empty leg.

**Unlocked domain.** `PoolManager.unlock` reverts `AlreadyUnlocked` (upstream `main` `PoolManager.sol`, accessed in the prior pass of this session; not a deployment pin). No wing mint, wing burn, core placement, or swap. Deposit increases `F` and mints `m`. Exit pays `y` only if `F_out>=y`, else `InsufficientLocalReserve`. Wings are not cover in this state. This is the path Orbital uses inside a hook callback on the same manager (`TestBase_UniswapV4Detf_Orbital_Univ4Se.sol:49-55` binds hookless vaults to one manager).

**Idle exit funding, after `y` is known.** Spend `F_out`, then remove liquidity from the output-token wing only if that wing is still strictly one-sided. Removal amount is `getLiquidityForAmount0` or `getLiquidityForAmount1` of the shortfall, capped by wing liquidity. Settlement must match `modifyLiquidity`'s round-down proceeds, not the floor helper alone. If still short, revert. Do not search a swap size. Do not pool-swap this exit: entry was internal, so exit must be internal.

## 4. Wing geometry, cap, consolidation

Current vault stores one center range and one salt (`PositionRepo.sol:121-135`; full-range usable ticks at `Common.sol:834`). Rank 1 keeps that core. Wings are additional.

Spacing `s`. Current tick `t`. Usable bounds `tMin`, `tMax`, already multiples of `s`.

```text
token0 wing: tickLower = nextSpacingAbove(t), tickUpper = tMax
token1 wing: tickLower = tMin, tickUpper = spacingAtOrBelow(t)
```

`nextSpacingAbove` is the least multiple of `s` strictly greater than `t`. `spacingAtOrBelow` is the greatest multiple of `s` less than or equal to `t`, and the wing is token1-only while `sqrtPrice >= sqrt(tickUpper)`. If `tickLower >= tickUpper`, the side is unavailable; leave the token in `F`.

Salts: `core`, `wing0`, `wing1`. Hard cap **three** positions. Dust adds to the canonical wing; it does not open a fourth. If the canonical wing is no longer strictly one-sided, freeze adds to it and leave new tokens in `F` until consolidation clears the slot. Do not scan alternate widths.

**Idle placement, after mint.** Budget is the deposited token now in `F`, minus the sleeve target `floor(T_i*p/(1e18+p))` on placeable `T_i=D_i+F_i`, if the owner still wants a reserved sleeve. `L = getLiquidityForAmount0(lower, upper, budget)` or the amount1 twin. Debt is the round-up one-sided delta. Unspent wei stays in `F` and is booked. If `L` would exceed `maxLiquidityPerTick` at either boundary, place nothing and leave `F`. No second candidate range.

**When a wing enters range.** Token0 wing is tainted once `t >= tickLower`. Token1 wing is tainted once `t < tickUpper`. It then holds both tokens. Do not add the original token as if it were still one-sided. Do not assume its ratio matches the core.

**Consolidation, separate call, no swap.** Remove all wing liquidity. Proceeds are round-down principal plus that position's fees, collected once. Add to the full-range core with `getLiquidityForAmounts` of both proceeds. Excess of the non-limiting token stays in `F`, or returns to a fresh one-sided wing of that token if the slot is free and still out of range. If the core add is unfunded, book the proceeds in `F` and return deferred. Rounding loss is `before(F+D)-after(F+D)` and must be non-negative. Costs and rounding hit the book. No share mint. Keeper failure leaves a fragmented in-range position; valuation still includes its amounts, so the vault is not insolvent. Price reversal before consolidation converts the wing back toward one token; do not "undo" a completed consolidation. Because consolidation does not swap, a one-tick touch cannot force a bad trade. It can force a residual. That is accepted.

Out-of-range wings earn no swap fees until price enters them. State that in the preview. Fungible shares mean those later fees belong to the book, not to the original depositor.

## 5. Fees, protections, conservation

Touch at most the core and two wings per idle call: collect, maybe one add or one remove-plus-core-add. Blocked calls touch none. That is the gas/liveness bound. It is not a measured gas figure.

Keep 25 bp and 10 bp for any future pool swap. Rank 1 consolidation does not swap, so those bounds are idle. Do not relabel the 50 bp pool-impact bound as movement of `B1/B0`. Internal settlement needs a new owner constant if a bound is wanted. Apply the 1 bp test to integer loss versus ideal invariant issuance, and say that this is a meaning change from basket alignment. D25 stays fixed constants; the new meaning is an amendment, not a setter.

Exact-in refunds nothing. Residuals and sleeve balances are booked. Prepaid exact-output may refund only `credit-used`, never booked inventory (`OutExecuteTarget.sol:138-142`). Dual activation and the dead sink stay.

Donation of booked surplus changes `B` before mint. Freeze credit before collection. Protocol fee and other LPs' fees are not `E`.

## 6. Orbital, SY, and outer searches

**Callable and search-free under rank 1.** `exchangeIn(token, amount, shares, minShares, …)` and `previewExchangeIn`, idle or unlocked, using the internal mint. `quoteTransition(DepositExactIn, amount)`. `quoteTransition(RedeemExactIn, shares)` using `_singleExit`, reverting if unlocked cover is short. `quoteInputForExactShares(state, m)` on both states. `ReceiveShares`. `sharesForNativeUp` / `ratedNative` (Orbital addendum `:828-835`; do not value reserves by an SE quote). `depositFlexible` when amounts are already SE shares. SY `deposit` / `redeem` are aliases of these routes, not a second formula. Minima stay meaningful: `minShares` on entry, `minAmountOut` on exit. Zero minted or rated output rejects; do not substitute the face amount (`ClaimLib.sol:309`).

**Invalid or unchanged limits.** Exact-output two-leg share redemption. Unlimited blocked withdrawal. Nested unlock. A router-supplied swap amount.

**Outer loops.**

| Loop | Disposition |
|---|---|
| Hookless `_composition` and quote/deposit calls to it | Remove from scalar routes. Replaced by the CP mint. |
| `_maintenance` / `_rebalanceLiquidReserveBestEffort` on user and quote paths | Remove. Idle dual join currently calls it (`InBase.sol:361-362`). Public repair may remain, but must not be required for scalar success. |
| `_faceForClaim` | Replace with `sharesForNativeUp` then one `quoteInputForExactShares`, one validation, no retry. The `while (low<high)` continues after the 8 interpolation attempts (`ExitQuoteLib.sol:357-372`). Those 8 attempts are not the probe bound. |
| `_invertBufferForEffective` | Same replacement. Its `while` also continues after interpolation (`ClaimLib.sol:264-274`). |
| `zapSplitWad` | **Retained.** Up to 64 residual probes (`Math.sol:332-360`). Wings do not remove it. `planDeposit` is not end-to-end search-free until Orbital replaces or proves that split. Disclose it. Do not hide it inside a Hookless claim. |
| `_sharesForSingleExit` | Stays off the exact-output path. |
| Crane `UniswapV4ZapQuoter` | Not used. |

Pons fees and orchestration do not change. No Hookless planner is shared into Pons.

## 7. Comparison

Local-inventory-first plus later placement is rank 1. It is what the unlocked buffer can actually do. Wings are a productivity layer, not the valuation.

A properly specified internal market is that valuation. The economic objection stands: holders are the counterparty. A depositor can buy the cheap internal leg and redeem the other up to cover, or wait until consolidation and pool trades move `D`. Rank 1 refuses the pool-priced exit so that particular hedge is not inside the SE. It does not stop an external hedge against later keeper consolidation or against the pool moving the core.

Controlled TWAP admission can also be search-free. It fails if the owner does not approve the oracle, the staleness bound, and the spread. Same-pool spot is the worst case of that family, not a proof that every external price is impossible.

Restricted analytic conversion remains unproved as an integer identity and is unavailable while unlocked. It is not a substitute for rank 1.

Separate epochs fail Orbital: the buffer needs fungible SE shares in the same call, not a claim on a private wing.

## 8. Attacks

Internal-price donation before the snapshot. Wing freeze: a one-tick move taints the canonical wing and forces new deposits to stay in `F`. That is liveness grief, not extraction, if mint uses `B` rather than "whatever the wing accepted." Dust cannot multiply positions under the three-position cap. Consolidation residuals can be donated to the book; they must not be credited to the keeper. If a later design adds a consolidation swap, the 25 bp bound applies and MEV returns; rank 1 does not add that swap. Counting wing token amounts and also their fee growth double-counts. Removing an in-range wing and adding to the core at a different ratio leaves a residual by construction; booking it is required, swapping it is the old search.

## 9. Amendments

Amend D1, D4, and D5: scalar `exchangeIn` remains, but it does not swap to the post-swap incumbent ratio. Amend D6 so the positive two-leg scalar path is the one-sided CP branch, not min-ratio, and min-ratio remains for true baskets. Amend D8: wings and `F` are retained placement, not forced full-range deployment of both tokens. Amend D9 and D18 so user and quote paths do not call swap repair. D17 stays closed-form only; it now includes the blocked and idle CP inverse for exact shares, and still excludes the two-leg exact-output bisection. D20/D25: do not migrate 50 bp onto `B1/B0` without a new approved constant. Keep 1 bp only with the invariant-loss meaning written down. D3 stays, as a placement target, not a deposit revert. Keep D2 for any remaining pool swap, D7, D10–D16, D22–D26, D28, D29, D31. Refresh D27 and D30. Core stays full-range; wings are the permitted non-full-range placement. Orbital held-rate and B6 stay. DETF rate-provider law stays. Pons unchanged.

## 10. Later gates

Do not run them here. Owner accepts the internal market, the three-position cap, and unlocked cover limits first.

Then: CP helpers match execution on both manager states; `quoteInputForExactShares` matches idle and blocked; unlocked exit reverts when `F<y` even if a wing holds the token; idle exit may consume a still-one-sided wing and must not swap; tainted wing rejects further one-sided adds; consolidation is swap-free, residuals booked, `F+D` does not increase; dust does not create a fourth position; donation and deposit-then-other-leg cycles are measured against the internal curve and against the external pool, and the second is reported rather than assumed safe. Orbital: `_faceForClaim` and `_invertBufferForEffective` make one inverse call; `zapSplitWad` is either gone or explicitly still a search. Preview equals execution. No gas claim until a later pinned measurement. No cap raise.

## 11. Evidence

Access date 2026-10-03. Local `foundry.toml:29-36`: Solidity 0.8.35, optimizer runs 1, `via_ir` false. Context7 `/uniswap/v4-core` for position key, one-sided `modifyLiquidity` deltas, and `LiquidityAmounts`. Upstream `main` is not a deployed pin. Charm and similar range-order vaults are leads only; they do not prove this vault's fungible accounting. No ordinary path read failed this pass. `V4FundedBindings.t.sol` was not opened. Gaps: no execution of the CP inequality, no proof that `zapSplitWad` has a closed form, no fresh trace. **Stop for the owner. This memo does not authorize implementation.**
