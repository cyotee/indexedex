# dry-econ-weighted-partial-dust-seed — CONFIRMED (execution, t4 worker, HEAD 2ba07631)

File: WeightedPartialDustSeedV2.t.sol. Suite result: ok. 3 passed; 0 failed.

Setup: an n=3 UniswapV4WeightedSwapHook with weights 0.4/0.3/0.3. An honest LP does the PRD D36 partial first mint: 4000e18 A + 3000e18 B, C = 0. All prices are 1.

Attack, run by an unprivileged attacker who holds only C, with no cheatcodes mid-attack:
1. Call joinProportional([0,0,1e9]). The attacker gets 424,322,503 shares and isFullBook becomes true.
2. Make 80 router swaps C -> A/B, each 29% of reserve C. The loop runs while previewSwapExactIn(out) > in.
3. Exit the dust shares.

Results:
- test_dustSeedThenDrain: attacker net profit is +6997.94e18 at price 1, with all 1000 C spent counted. The victim LP paid 7000e18 in and gets 2.06e18 out (-99.97%). Final reserves are A 1.11e18, B 0.249e18, C 0.703e18.
- test_frontrunHonestSeed: an honest seeder previews a fair 3000e18 C seed and expects 1.273e21 shares. The attacker front-runs it with the same attack and makes the same +6997.9e18. The honest seed tx then reverts on slippage (DoS). The LP loses 99.97%.
- test_control_fairSeed: a fair 3000e18 seed gives C->A 1e18 -> 0.9967e18 (normal).

Root cause:
- _partialJoin (LiquidityTarget.sol:186-193) accepts a seed for a zero leg at any size: used=amount, with no min, no price/ratio check, and no gate.
- Swaps go live once both reserves are > 0.
- WeightedMath prices the dust leg at (w/b), which is absurd. The 30% MAX_IN_RATIO grows geometrically, so it does not bound the drain.

Not a duplicate:
- The FullSpread first-mint-ratio finding is about the first mint into an empty pool. This attack hits a pool that is already live and funded.
- coverage/b02.md covers the orbital partial join, which is capped by the radius.
- APEX-007 is about the dust refund.

Deployment: the plain UniswapV4WeightedSwapHook is not in the live census, so this is a code-level finding. It applies to any partial-book (n>=3) deployment. The sibling StandardExchangeWeightedBufferHook partialJoin was not executed. That path is exposed when ownerOnlyLiquidity=false.

Fix options:
- Gate seeds (owner/factory only).
- Require a seed to be priced against an oracle or rate, or require a minimum value relative to the book (NAV-consistent).
- Or keep swaps on a newly seeded leg disabled until a minimum-depth seed lands.
