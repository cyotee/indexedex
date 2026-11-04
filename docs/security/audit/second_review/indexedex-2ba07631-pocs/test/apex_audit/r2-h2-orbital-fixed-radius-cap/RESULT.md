# r2-h2-orbital-fixed-radius-cap: CONFIRMED (DoS/griefing). Low severity; the behaviour is documented design.

File: OrbitalFixedRadiusCap.t.sol. Result: 3/3 PASS on the the audit runner audit profile.

Run command:
`forge test .../OrbitalFixedRadiusCap.t.sol -vvv --skip "*/apex_audit/[a-q]*" "*/apex_audit/[s-z]*" "*/apex_audit/r[a-z]*" "*/apex_audit/r2-h2[!-]*" "*/apex_audit/r2-h2-[!o]*"`

The skip globs are needed because other agents' unrelated WIP files in the remote slots fail to compile with stack-too-deep.

## Mechanism (code-confirmed)
- `R` is written only in `Common._applyAdd`, in the `supply == 0` branch: `R = 10 * max(first-mint leg)` (`R_SAFETY_MULTIPLIER = 10`, Repo:24).
- `MINIMUM_LIQUIDITY` (1000 wei LP) goes to `address(0)` and is never burned. Supply therefore never returns to 0, so `R` can never be re-set.
- Every later join and swap calls `_requirePostUnderRadius`, which reverts if any effective leg is `>= R`. The sphere math also reverts near `R`.
- The PRD says this explicitly:
  - D21: "Set once on first successful addLiquidity ... Later ops with any 1e18 effective reserve >= R revert".
  - Non-goal #9: "Growing R after first mint; resetting R after full liquid exit."

## Executed results
1. **test_fill_to_R_grief_accounting.** An honest LP seeds 1,000 per leg, so R = 10,000.
   - Baseline: the largest 0->1 swap that succeeds is **1,185 tokens**. A 100-token swap returns 94.02, and an honest 100/leg join succeeds.
   - Attack: an unprivileged attacker calls addLiquidity with 8,950 per leg. Legs move to 9,931 / 9,950 / 9,950.
   - After the attack:
     - The largest swap that succeeds drops to **68 tokens** (about 17x less depth).
     - A 100-token swap reverts with V4 `WrappedError` (0x90bfb865).
     - The honest 100/leg join reverts with `ReservesExceedRadius` (0x13e5fe33). `_capFaceUnderRadius` does not prevent this, which is a minor secondary bug.
     - A 1/leg join still succeeds.
   - Attacker exit after 1 day: puts in 26,850 and gets back 26,841.97. Net cost is **8.03 tokens (0.03%)**, with no profit. The test asserts that swaps work again once the attacker exits.
2. **test_R_survives_full_exit.** The honest seeder exits completely. Afterwards R is still 10,000, supply is 1000 wei, and about 333 wei of dust remains per leg. A later 10,000/leg join reverts with `ReservesExceedRadius`. The pool stays capped at 10x the original seed for its whole life.
3. **test_dust_first_mint_caps_pool_forever.** If an unprivileged account makes the first mint (`ownerOnlyLiquidity = false`) with 0.001 per leg, R becomes 0.01. Every honest 1,000/leg join then reverts with `ReservesExceedRadius`. That hook instance is unusable for good, for a cost of 0.001 token per leg.
   - The instance is immutable, and the CREATE3 salt is built from the args, so the deployer must redeploy with different args (for example a different owner).
   - Deploy and seed are separate transactions, so a front-run is possible.

## Assessment
- Profit: none. A round trip near the cap loses money to fees (see h2-dos-stuck probe).
- Victims: swaps above a small size and honest joins are blocked while the attacker stays in. This is a temporary DoS that costs the attacker about 0.03% of the capital parked.
- Variant 3 is a cheap, permanent brick of a single instance. It is recoverable only by redeploying.
- Live exposure: none. The census shows no orbital hook deployed on Robinhood mainnet.

Severity: **Low**. Both the capacity cap and the fill-to-R lockout follow from the documented design (D21 / non-goal #9).

Recommendations:
- Let R grow on proportional joins (scale R by supply growth), or let the owner raise R.
- Seed the first mint atomically at deploy, or require `ownerOnlyLiquidity` until seeded.
- Make the capped join path reliably succeed instead of reverting with `ReservesExceedRadius`.
