# Grok cross-review — Upper/Lower Wings PRD (2026-10-05)

Original preserved. Peers are untrusted. No git, tests, or security proof. Commit `35f47b51` was not read. ~1.28M is not wing gas.

## Corrections

**My original over-blocked geometry and zaps.** The owner now requires restored three-position intent and useful single-token entry. Leaving every width as a blocking OD, and treating a zap as undefined, is too weak. Parameters below are **proposed, not owner-approved**.

**Do not adopt MiniMax’s full-range center or scalar ban.** Current hookless code is center-only full-range (`Common.sol:659-666`; full-range PRD D30/D31). That is the product this vault must not copy. MiniMax OD-1(d) disallows single-token entry. The owner forbids that ban.

**Do not copy FullSpread 25/50/10/1 bp as law.** Astra is right: `TransitionPlanner` constants are another product. Own-wing crossing is a different impact. Propose them only as a measurement starting point for *external* liquidity, not as wings law.

**Weighted matrix.** `n ∈ [2,8]` (`WeightedBufferHookPRD.md:87`). Valid rows are `n=2..8`, buffered `b=1..n`, raw `r=n-b`. `n=1` and `b=8` plus a raw leg are invalid. Astra’s “DETF self-leg caps buffered at 7” was not re-verified here; do not lock it.

**Token orientation is inverted in the historical sentence.** Direct evidence:

- V4 full-range PRD `:72-75`: center `centerWidthMultiplier = 2` (~±1 spacing); `activeLiquidityBps = 1000`; “90% of deployable token1 in the lower wing, 90% of deployable token0 in the upper wing”; ticks frozen; rebalance does not recast.
- V3 vault PRD `:185-191`: lower `[outerLower, centerLower]`, upper `[centerUpper, outerUpper]`.
- Slipstream code `:287-290`, `:322-350`: center takes 10% of each token; **lower wing is quoted with amount0=0 and token1 budget; upper wing with token0 budget and amount1=0**.

Uniswap: a range below spot is token0; a range above spot is token1. If spot is inside the center, the historical budget puts the wrong token in each wing and the quote should mint ~0 wing liquidity. Restoring that sentence is not useful single-token composability. **Proposed correction:** lower wing gets the remaining **token0**; upper wing gets the remaining **token1**. Label this a deviation from the written 90% assignment, not a silent restore.

## Proposed parameters (not approved)

1. **Geometry.** At first organic create, snap to `tickSpacing`, freeze, never recast. Center half-width = one spacing (`centerWidthMultiplier = 2`). Outer half-width from `PkgArgs.widthMultiplier`, proposed minimum 2 so wings are non-empty. Contiguous: lower `[outerLower, centerLower]`, center `[centerLower, centerUpper]`, upper `[centerUpper, outerUpper]`. Not full-range. Not overlapping. Empty-range after snap reverts. No later `placeWing` / consolidate-into-center.
2. **Weights.** After the sleeve is reserved, center gets 1000/10000 of each deployable token. Remaining token0 → lower wing. Remaining token1 → upper wing. `SlipstreamVaultRepo.sol:53` is the 1000 bps source. Sleeve is not part of that 10%.
3. **Sleeve.** Proposed reuse of the fee-oracle percentage of **sum of three deployed principals**, type default 20% (`full-range PRD:46`). Target free is the existing `p*D/(1+p)` form (Astra/Z), not `p*(F+D)`. Deadband not copied until measured. Blocked path: no `unlock` (`AlreadyUnlocked`, Context7 `/uniswap/v4-core`, 2026-10-05). Deposits and covered exits use `F` only. Uncovered exit reverts. Fees in `E` are not cover.
4. **Scalar entry — required, not banned.** Idle single-token zap: composition swap funded only by that call’s credit, against the post-swap whole three-position book, then place on the frozen ticks, then `m = min floor(S*C_i/B_i)`. Count sleeve credit. Dual first mint only; no single-token bootstrap. Blocked single-token deposit may mint against the book but cannot place or swap. Exact-out only where a closed form is written; otherwise `InvalidRoute` before pull.
5. **Issuance.** Spot inventory `B = F + D_L + D_C + D_U + E`, each fee once. Not oracle NAV. Not internal-CP on spot three-range value (Astra). Manipulation is **not** solved. A spot/TWAP revert band is proposed as a later measurement, not a number in this draft.
6. **Protections.** Do not inherit 1/50/25/10 bp. Require the implementation plan to measure own-book crossing separately before any constant is locked.
7. **Deploy.** New tree `v4/upperLowerWings/`. Full type name. Vault registry, not hook factory. No FullSpread edit. No `MockStandardExchange`. No mock of this vault.

## Gas and history

No wing transaction gas was measured. `foundry.toml:38` is a harness ceiling. A subcall `gasleft` is not a transaction. EIP-7825’s 16,777,216 cap is Astra’s citation; this pass did not re-fetch it and does not claim it is active on chain 4663. Acceptance, when a plan exists, is a top-level tx receipt against that chain’s **transaction** cap and **block** cap, reported separately. `35f47b51` remains unread. The historical PRD and Slipstream code are the restoration evidence, not that commit and not the 1.28M figure.

## Decisions for the moderator

- Adopt finite frozen three-position geometry and scalar zap as the proposed product.
- Adopt the **corrected** token orientation; do not copy “token1 in the lower wing” into executable law without an owner override.
- Reject full-range center, scalar ban, automatic FullSpread bp copy, and MiniMax keeper `placeWing`.
- Leave own-book impact limits, `widthMultiplier` default above 2, DETF self-leg cap, and chain tx-cap activation unresolved. None of this is a security proof.
