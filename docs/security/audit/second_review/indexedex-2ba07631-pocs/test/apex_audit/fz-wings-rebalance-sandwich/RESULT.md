# fz-wings-rebalance-sandwich: CONFIRMED (distinct from wings-forced-dump-rebalance)

## Is it a duplicate?
No, the root cause is distinct.
- wings-forced-dump-rebalance (confirmed in p3) covers the redeem path. `_fund -> _swapDeficit` sells the vault's whole opposing balance exact-in. It needs a large exit that forces a core close. The same RESULT.md tested the permissionless `rebalance` sandwich half of the hypothesis and marked it REFUTED (WingsForcedDump.t.sol::test_sweep). That sweep only covered a settled vault.
- This finding is on that previously refuted path: `RebalanceTarget.rebalance -> Planner.bestSwap -> Swap`, with no exit needed. When the vault holds pending target cash that has not been rebalanced yet (any deposit since the last keeper run), an attacker can push the price with target-token-in, call the permissionless `rebalance`, and restore p0. The vault sells its pending target token at the manipulated price. Two things let this through:
  - `bestSwap` sets the swap's price limit from a quote at the current (manipulated) state.
  - `_validate` compares `Quote.quote()` before and after, both taken at the manipulated pool state. That quote inflates the before value (1.79e17 against a fair 1.48e17), so the measured loss is about 0.06% and passes the 1% `progress/100` cap.
- There is overlap: the "same-state liquidation quote as loss oracle" weakness is also listed in forced-dump's fix. But the trigger, code path and fix location (RebalanceTarget/Planner, not `_swapDeficit`) are different, and the earlier execution called this path refuted.
- It is not wings-spot-nav either. That finding manipulates deposit/redeem NAV pricing. This one manipulates the vault's own maintenance swap.

## PoC (FzWingsRebalanceSandwich.t.sol). Fixture: real V4 PoolManager wings fixture, external full-range L=1e18, sleeve 20%
- Setup: an honest anchor deposits 1e17 and a keeper settles at fair price. An honest depositor then deposits X token0, which stays pending.
- Attack, one tx from a fresh unprivileged contract that holds no shares, with all capital counted: swap token0-in by `push`, call `rebalance(0, ts)`, swap back so the price is exactly p0.
- Profit is the attacker's net token0+token1 at p0 (1:1), with all swap fees included.
- Victim loss is measured against the honest baseline: a keeper rebalances the same pending cash at p0, then an independent arb restores p0.

| pending | push | attacker profit | push+restore without rebalance | honest holders' fair value (baseline -> attack) | loss |
|---|---|---|---|---|---|
| 5e16 | 4e17 | +9.086e15 | -2.07e15 | 1.4737e17 -> 1.3676e17 | 720 bps |
| 5e16 | 1e17 | +3.323e15 | -5.7e14 | 1.4737e17 -> 1.4393e17 | 233 bps |
| 2e16 | 2e17 | +1.393e15 | -1.10e15 | 1.1781e17 -> 1.1542e17 | 202 bps |

- In every case the vault's own Rebalanced(before, after) check reports less than 0.1% loss, and the rebalance is accepted.
- Sweep (test_sweep): with a settled vault (pending 0), every push in both directions loses money for the attacker, which matches the earlier refutation. With pending cash, token0-in (target-token-in) pushes are profitable at every size from 5e16 to 4e17. Token1-in pushes are not profitable.

## Fix
- Give `rebalance` a reference-price guard: a TWAP or oracle deviation bound on sqrtP before the swap, or a price limit tied to a reference price instead of the current spot.
- Make `_validate` measure loss against a fair or reference mark, not a liquidation quote taken at the manipulated state.
- Optionally restrict who can call `rebalance` (keeper role), or have it revert when spot deviates from the reference by more than N ticks.

## Caveats
- The family is new in this diff and not deployed on any network in the manifest, so this is a pre-deployment, design-level finding.
- Profit scales with how much pending cash there is relative to external depth.

Run:
forge test .../fz-wings-rebalance-sandwich/FzWingsRebalanceSandwich.t.sol -vv --match-test test_PoC   (4/4 pass)
forge test ... --match-test test_sweep
