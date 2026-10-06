# Grok — wings clarifications (2026-10-05)

Independent. PRD `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` read, not edited. No tests. No claim that any formula is economically safe.

## Settled, not reopened

**Local reserve is custody, not the pool and not deployed liquidity.** `R_i` is the vault diamond’s own token `i` balance snapshot. `F_i` is the spendable part of that local balance after removing this call’s credit, payouts, and refunds (`InventoryMath.sol:45-48`). Neither includes `D` or pool reserves. A price move that changes deployed amounts must not create inbound credit (PRD C1).

**Sleeve percentage is of vault-owned deployed reserves.** `D_i = sum_j D_ij` over the vault’s own positions, not Uniswap pool TVL. Clarified target: `F_i = p * D_i`. With `T_i = F_i + D_i` and `p` in WAD, `targetFree_i = floor(T_i * p / (1e18 + p))` (`InventoryMath.sol:50-51`; PRD S1). At `p = 0.20e18` and `D = 100`, target `F = 20`, `T = 120`. That is not 20% of `T` (24) and not 20% of the pool. `E` is not sleeve cover until collected into `F`.

**No typical zap.** A single-sided deposit must not swap caller credit into the other token to manufacture a balanced basket. An internal “virtual swap” that rewrites incumbent claim ratios as if that trade happened is the same economic operation and is outside this intent.

## What “preserve value” cannot mean all at once

One fungible share is a claim on both tokens. After a deposit of `(c, 0)` and mint `m > 0`, supply becomes `S' = S + m` and backing `(B0 + c, B1)`.

**Incumbent token quantities.** Old shares must keep `B1/S` of token1. Their aggregate token1 claim is `S * B1 / S'`. That is at least `B1` only if `S' <= S`, so `m <= 0`. **Proof:** any positive mint against a positive `B1` reduces incumbent token1 per share. No rounding choice fixes this. Min-ratio `m = min_i floor(S * C_i / B_i)` is 0 when `C1 = 0`. It preserves incumbent quantities by refusing the depositor a share. It does not compensate the depositor.

**Geometric invariant per share.** `K = sqrt(B0 * B1)`, mint `m = floor(S * (K' - K) / K)` with `K' = sqrt((B0+c)*B1)` holds `K/S` for incumbents. It does **not** hold token quantities or spot market value.

**Market value.** At prices `(p0, p1)`, incumbent value is preserved only if `m <= S * p0 * c / (p0*B0 + p1*B1)`. That bound depends on a price. Spot is movable. It is not a quantity identity.

**Payout capacity.** `F` can pay a redemption. `D` and `E` cannot, especially while unlock is blocked. A share minted on `B` is not a promise of local same-token cash.

## Numerical counterexample

Assumptions: two-sided book, spot price 1 for the value column only, no fee, no swap, integers shown after an exact square root. `B0 = B1 = 100`, `S = 100`. Deposit `C0 = 20`, `C1 = 0`.

| Rule | `m` | Depositor claim `(token0, token1)` | Incumbent token1 left | Spot value in vs claim |
|---|---:|---|---:|---|
| Min-ratio | 0 | none, unless the 20 is refunded | 100 | 20 in, 0 out if booked without refund |
| Token0-only ratio `floor(S*20/B0)` | 20 | `(20, 16.666…)` of the new 120/100 book | 83.333… | depositor gains 16.666 token1 from incumbents |
| Geometric | `floor(100 * (sqrt(12000)-100) / 100)` = 9 | about `(9.908, 8.257)` of 120/100 | 91.743 | depositor put in 20, claim value about 18.17; incumbents gain the difference |

Exact root: `sqrt(12000) = 109.544…`, so the uncapped geometric mint is `9.544…` shares, not 9. Floor makes the depositor’s loss larger, not smaller. Incumbent `K/S` stays 1 before the floor; after `m = 9`, `K'/109 > K/100`, so incumbents gain invariant as well as spot value.

**Round-trip.** Those 9 shares, redeemed pro-rata with no swap, return both tokens, not 20 token0. A same-token exit of their full claim needs a conversion swap, which is the typical zap-out. Paying 20 token0 from the sleeve for those shares would spend other holders’ local token0. Burning the 9 shares and paying only pro-rata token0 confiscates the token1 claim.

**Zero leg.** If `B1 = 0`, `B1` in the denominator is undefined. Do not treat that as min-ratio zero and do not mint from token0 alone against an empty token1. A later deposit of the missing token is a different domain.

**Sleeve placement does not create the missing claim.** Parking the 20 token0 in `F0`, or in the token0 wing, increases `B0` only. It does not add `B1`.

## PRD consequence

PRD B3 correctly says a one-token input cannot earn positive min-ratio shares against a two-token book without another economic operation. The clarified no-zap intent removes candidate 1 (caller-funded composition swap) for the ordinary path. Candidate 2 (local invariant growth) preserves `K/S` and transfers spot value, as the table shows. It is not value preservation for the depositor or for incumbent quantities.

Useful scalar service without a balancing swap is therefore: **admit and mint only when both `C_i` are positive enough for `m > 0`, or when the owner defines a non-fungible / one-sided claim that this share token is not.** Rejecting a one-sided deposit and refunding `C` preserves value. Booking `C` and minting 0 does not.

PRD G1 still labels the lower wing token1-only and the upper token0-only. `LiquidityAmounts.getLiquidityForAmounts` (`:66-76`) uses token0 below the range and token1 above it. That is a placement bug if spot is inside the center. It does not change the admission proof.

## Owner questions

1. On a two-sided book, a one-token deposit with no balancing swap: **revert and refund**, or is some other non-fungible claim wanted? Minting fungible shares from geometric growth is a value transfer, not a third neutral option.
2. Does the no-zap rule also forbid the **exit** conversion swap? If yes, single-token redemption cannot return the spot value of both entitlements from `F` alone.
3. When price has left the envelope and one `B_i` is zero, is a deposit of **only the missing token** admitted under a written one-leg formula, or rejected until both legs are positive again?
