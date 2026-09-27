# Grok round-2 original — sleeve fixed point and mint-last attribution

**Date:** 2026-09-26. **Author:** Grok (`xai/grok-4.7`). Research only. Prior originals and cross-reviews are unchanged.  
**Owner, resolved:** (1) change existing idle `exchangeIn`; (2) swap only this call’s input.  
**Owner, new:** (3) sleeve is 20% of **vault-owned deployed principal**, not total pool liquidity and not combined vault total; (4) swap the input to a proportional split, place to the fee-oracle sleeve, then mint shares on deployed + sleeve.

Draft PRD G3 (`docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` lines 58–64) still says `targetFree = total * p`. That draft is superseded on this point by the owner. No new one-token NAV. No DETF issuance formula. No new Uniswap API claim; prior unlock evidence stands. Compiler observed: solc 0.8.35, `via_ir=false` (`foundry.toml` 29–36).

## Sleeve definition

Literal reading: `F_i = p * D_i`, where `D_i` is this vault’s position principal at the post-swap price (`_deployedAmounts` / `SqrtPriceMath`), not external pool reserves and not other LPs’ liquidity.

`T_i = F_i + D_i` implies the non-chasing target

```text
F*_i = floor(p * T_i / (1e18 + p)) = p/(1+p) * T_i
D*_i = T_i - F*_i
```

Compute `T` after the swap and fee assignment, then place once. Do not set the target to `p * current D` and redeploy: deploying raises `D` and the target, so the move chases itself.

| `p` (resolved WAD) | `F*/T` | Meaning |
|---|---|---|
| stored `0` | fall through | `liquidReservePercentageOfVault` treats stored 0 as unset, then type, then global (`VaultFeeOracleQueryFacet.sol` 322–330). Not an explicit 0% policy. |
| resolved `0` | 0 | Fully deploy. Same endpoint as today’s `p * T = 0`. |
| `0.20e18` | `1/6 ≈ 16.67%` | `F = 0.2 D`. Old law was 20% of total (`F/D = 25%`). |
| `1e18` | `1/2` | Sleeve equals deployed. Old law held 100% free. **100% sleeve is inexpressible** for `p` in `[0,1]`. |

**Fee component.** `D` is principal only. Uncollected fees are not in `D` (do not inflate `F*`) and not in `F` until collected. Collect preexisting fees before the snapshot so D58 counts them once, in incumbent free. They raise `T` and therefore `F*`, but are not multiplied again inside `D`. Protocol fee leaves with the swap; the caller’s basket is smaller. Self-LP fee growth from the caller’s swap is incumbent income, not caller principal.

**Blast radius.** Do not change oracle storage or staking-SE math. Reinterpret `p` only in V4 SE placement. The same stored `0.20e18` remains 20% of total for other vault types and becomes 20% of deployed here. Keep the type default number; do not silently store `0.25e18` to preserve the old 20%-of-total economics. Deadband stays `max(10^max(0,decimals-6), 5% of F*)`, applied to `F*`, not widened by a fraction of `T`. Public add/remove rebalance uses the same `F*` and still does not swap.

## Order and formula

Preserve: one-sided activation reverts (D59); imports convert to managed full range; WETH face, unwrap only to settle, no payable ETH; blocked `exchangeIn` sleeve-mints with today’s single-token invariant growth and does not swap.

Idle route, mint last:

1. Collect preexisting fees into incumbent free.
2. Pull only this call’s input. Caller tranche is the secure-pull amount, then the PoolManager swap delta of **that** amount. Donations and `pretransferred` balances already on the diamond stay in `R`. A callback donation is not `c`.
3. Swap only that tranche so the resulting basket `c` matches the **post-swap incumbent owned book**, not external pool reserves and not raw 50/50 units.
4. `R_i` = post-swap deployed principal + free excluding `c` + fees assigned to incumbents. Each asset once. Use this `R`, not the pre-swap snapshot: trading against the vault’s own position moves `D`.
5. Place add/remove only so free meets `F*_i` on `T = R + c`. No second swap. No incumbent liquidation.
6. Mint, then check `minSharesOut`.

Once `c` is aligned to `R` and both incumbent reserves are positive, the existing dual branch is the proportional allocation of deployed + sleeve (`Common.sol` 700–704). It is not a new formula:

```text
sharesOut = min(floor(c0 * supply / R0), floor(c1 * supply / R1))
```

Alignment makes the two arguments equal up to 1 wei; `min` keeps the existing dust rule. Do not use sum-of-assets, invariant growth, or a price NAV on this path. Placement does not change `T`, so mint-last and mint-before-place match if fees were already assigned to `R`.

Blocked and empty-supply paths do not use this equation.

## Examples (fees ignored unless stated; price 1:1)

**Aligned book, `p = 0.2`.** `T = (120,120)`, so `F* = (20,20)`, `D = (100,100)`. Deposit 12 token0. Book ratio 1:1. Swap 6→6. `c = (6,6)`, `R = (120,120)`, `shares = 6/120 * supply`. After place, `T' = (126,126)`, `F*' = (21,21)`, `D*' = (105,105)`. Liquidity increases. Caller bears a 30 bps pool fee: about 6.009 token0 buys 5.991 token1, `c ≈ (5.991, 5.991)`, shares `5.991/120 * supply`. Incumbent token totals are unchanged if external depth absorbs the trade.

**Naive chase.** `T0 = 120`, start `D = 90`. Target `0.2 * 90 = 18` deploys 12, `D` becomes 102, target becomes 20.4, free is now short. Fixed point is `F* = 20`, `D* = 100`. One shot from `T`.

**Skewed sleeve — why the ratio matters.** `D = (80,80)`, free `(50,20)`, so `R = (130,100)` before the call. Deposit 10 token0.

- Book-align (recommended): `c` matches 130:100. Existing `min` does not donate. New tokens are token0-heavy versus the 1:1 position, so not all of `c` can be deployed. Incumbent excess token0 is not swapped (owner rule 2). Issuance is still fair. This is partial deployment, not an unsolved formula.
- CL-align to 1:1, then today’s `min`: `c = (5,5)` gives `5/130` versus `5/100`. Shares bind on token0 and the extra token1 is donated to incumbents. Reject as the default.

**`p = 1`.** `T = (120,120)` places `F* = D* = (60,60)`, not all-free. An operator who set 100% to disable deployment will now deploy half.

## Remaining owner choices

1. **Confirm literal `0.20e18`.** Sleeve becomes 1/6 of owned total, not a recalibration that keeps 20% of total. Recommendation: literal.
2. **`p = 1` means half/half.** 100% sleeve cannot be expressed. Recommendation: accept that; do not add a sentinel unless the owner still needs an all-sleeve mode.
3. **Swap target.** Recommendation: post-swap owned-book ratio so the existing `min` formula applies. Alternative: CL ratio, which deploys more of this call but donates on a skewed book unless a different formula is written. Do not leave this implicit. It is the only issuance choice left.
4. **Price-bound source** and whether non-Pons hooks fail closed. Still open. They do not block the formula. DETF price gates do not impose TWAP here.

Incumbent price impact from self-LP is inventory risk, disclosed by using post-swap `R`. It is not an issuance subsidy if `c` is the PoolManager delta of the caller tranche only.
