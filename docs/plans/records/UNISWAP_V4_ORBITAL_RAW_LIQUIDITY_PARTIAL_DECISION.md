# OD-1 partial pricing decision note

**Date:** 2026-10-04  
**Status:** OD-1 unresolved. No partial formula was installed.  
**Executable scope already completed:** subsequent full-book and flexible full-book joins, and zap terminal admission, use raw inventory. Partial sphere-NAV paths are unchanged.

This note does not authorize a rated-NAV exception. It does not claim full raw-law compliance while this branch remains open.

## Why raw shares cannot be dropped into rated `R`

Sphere spot weight is `p_i = R - r_i`, with `R` and `r_i` in effective WAD. The partial mint is

`m = floor(S * sum((R - r_i) * u_i) / sum((R - r_i) * r_i))`

`R` is fixed at first mint from the maximum post-buffer **rated** coordinate times the radius safety multiplier. `r_i` is the rated reserve. `u_i` is the accepted used amount in that same rated coordinate.

A raw SE share count is not a rated WAD. Substituting `seBalance` for `r_i` while leaving `R` in rated WAD compares a share integer to a face-valued radius. That is a new unit mismatch, not a repair. A raw leg with no provider is already in face units; a buffered leg's share decimals need not match the face token. One substitution cannot serve both.

## Current formulas and units

All line pointers are navigation aids against the 2026-10-04 sources. Partial callers still use these formulas.

| Function | Units in | What it does | Who calls it |
|---|---|---|---|
| `_partialSharesUsed` | Face offers. Incumbent is `_effectiveNativeAt` (rated native). | Does **not** preview-buffer the offer. Passes face offers and rated native reserves to `_partialUsed`, then `_partialNavShares`. | Direct face `_computePartial`, and `_singleSidedPlan`. |
| `_partialUsed` | Native offers and native effective reserves. | Zero-reserve offered legs provisionally take the whole offer. Minimum candidate is only over legs with both positive reserve and positive offer. Unoffered positive-reserve legs do not force the minimum to zero. A zero minimum clears the result, including zero-leg offers. Positive-reserve used amount is `fromWadFloor(fullBookUsedWad(minShares, toWad(reserve), liveSupply))`. | `_partialSharesUsed` and `_fillPartialFlexible`. |
| `_partialMinShares` | Same native units, WAD-normalized per leg. | `min floor(toWad(offer) * liveSupply / toWad(reserve))` over positive pairs. No radius. Uses live `_totalSupply()`, not the post-fee supply later passed to NAV. | `_partialUsed` only. |
| `_partialNavShares` | Rated native incumbent and used amounts, then face-token WAD. | Zero used, zero supply, or zero `R` returns 0. Any incumbent coordinate `>= R` returns 0. Otherwise `sphereNavShares`. Does not itself prove the post-deposit coordinate stays under `R`. | Direct and flexible partial. |
| `_singleSidedPlan` | One face amount. | Places it on one leg. Uses preview post-fee supply. Calls `_computePartial`. No zap sales. | `_planZap` fallback when a coordinate is near `R`, the input would drain, a coordinate is zero, `R == 0`, input WAD `< 3`, or the ratio plan returns 0 shares. |
| `_partialDepositAtState` | Projected `legs[i].effective` and a face amount. | Separate from the Common partial helpers. Returns 0 if `R == 0`, input effective WAD is 0, or input coordinate `+ 1 >= R`. Caps face by rated room. Pro-rata is `toWad(amount) * supply / effectiveWad` on the **input leg only**, then `fullBookUsedWad`, then `sphereNavShares` against all three projected rated coordinates. A zero input incumbent returns 0 rather than accepting a zero-leg contribution. Another leg `>= R` can revert `MathDomain` inside the spot weight. | `_depositAtState` when the projected book is missing a coordinate, near radius, or the oversized-input predicate holds. Share-input and external-deposit previews reach this after a projected redeem. |

`fullBookUsedWad(shares, rWad, supply) = (shares * rWad) / supply` is unchanged. Partial and projected partial still pass rated WAD into it. Raw ownership uses `rawRequiredInventory` instead.

## Route predicates

| Route | Partial? | Changed by this remediation? |
|---|---|---|
| Face `addLiquidity` / `joinProportional` / all-face flexible, all three effective reserves and offers positive | No. Full-book raw ownership. | Yes. |
| Same entry, any leg unoffered or any effective reserve zero | Yes. Common partial. | No formula change. Full-book no longer reads rated offers, so the partial branch now computes rated offers itself. The values are the same. |
| Share or mixed `depositFlexible` / `joinUnbalanced`, all three raw books and offers positive and all effective reserves positive | No. Raw flexible ownership. Share input counts as shares. Face input uses the share-mint preview. Zero mint is zero credit. | Yes. |
| Share or mixed flexible otherwise | Yes. `_partialUsed` still receives rated effective offers. | No formula change. |
| Face `depositSingle` when the ratio plan returns shares | Zap terminal raw ownership after rated swaps. | Yes, terminal only. Swap split stays rated. |
| Face `depositSingle` fallback | `_singleSidedPlan` → Common partial. | No. |
| SE-share single-asset execute | Unwrap to face, then the face zap path. | Terminal raw only if the ratio plan is selected. |
| SE-share / external-deposit preview | `_depositAtState` → raw terminal or `_partialDepositAtState`. | Terminal raw only. Partial projected NAV unchanged. |

Zero-leg behavior is not uniform. Common partial can accept a zero-reserve offer. Projected partial returns 0 if the input effective coordinate is 0. Full-book raw mint returns 0 if any raw incumbent or any raw contribution is 0. That last case is the full-book gate's complement, not a partial-price change.

## Candidate raw-inventory policies (not selected)

1. **Raw spot weights.** Define a raw radius in each leg's own units and a raw weight. This needs a new radius rule, a decimal policy, and a decision for fee-bearing SE deposits whose share mint is not linear in face. It changes every partial route's price. Price-manipulation surface moves from the rate provider to the SE share mint and to donations into raw reserves.
2. **Face-normalized raw NAV.** Convert buffered shares to face through the SE's own redeem preview, then price in face units. This uses the SE quote the held-reserve rule forbids for valuation. A fee-bearing redeem is path-dependent. Not a default.
3. **Keep rated partial NAV as an explicit exception.** Owner would have to waive the raw-ownership rule for composition-changing joins only. A silent exception is not authorized. Fee-bearing deposits would keep today's rated dilution. Rate manipulation would keep today's partial-price surface.
4. **Disable partial routes until a rule exists.** Removes a supported path. Not authorized.

No candidate is implemented. Ask the owner for the partial policy before changing `_partialSharesUsed`, `_partialUsed`, `_partialMinShares`, `_partialNavShares`, `_singleSidedPlan`, or `_partialDepositAtState`.

## What this remediation did not do

- No stale cache, scaled last reserve, rate=1 substitution, skipped protocol mint, or omitted radius check.
- No new recovery entrypoint. OD-2 remains deferred. A provider failure still reverts the whole exit, including when usage fees are off.
- Raw ownership does not make entrypoint execution rate-independent. Fee mint, radius, L2, and reserve sync still read rates.
