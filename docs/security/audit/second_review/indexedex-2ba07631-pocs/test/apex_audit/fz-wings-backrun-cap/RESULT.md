# fz-wings-backrun-cap (P4 p4-wings R1): status confirmed_user_loss, severity medium

## Duplicate check: this is a distinct finding
- **wings-forced-dump-rebalance (p3, confirmed)** is a different path. It goes through the redeem path (Money._swapDeficit dumps the whole opposing balance). Its *rebalance* half was **refuted** in p3, and that sweep only used adversary pushes against vaults with no pending cash.
- **wings-spot-nav** needs JIT liquidity or spot manipulation around share ops. **wings-quote-step-cap-dos** is a DoS. Neither applies here.
- **R2 (p4 new_break, not yet a confirmed id)** shares the measurement weakness: `_validate` quotes at a spot price that is not fair. R2 needs the attacker to push the price before the rebalance. R1 needs **no manipulation at all**. The displacement is the vault's own `bestSwap` swap, so a fix limited to an oracle or TWAP for external pushes leaves R1 open.

## Root cause
`RebalanceTarget.rebalance` takes `before.value = Quote.quote(...)` at p0, runs `_reshape()`, then `_validate` takes `valueAfter = Quote.quote(...)` **at the post-swap spot, which the vault itself moved**.

Here `bestSwap` sells target (token0) for opposing (token1) to grow the core. The liquidation quote values the new opposing inventory by selling it back into the pool at that displaced price. That reverse sale undoes the vault's own price impact, so the realised slippage of the rebalance swap is almost invisible to the check. `maximumLoss = progress/100`, the designed "proportional loss cap", therefore never binds on price impact.

The impact is real: after anyone moves the price back to p0, holders' fair mark and even the liquidation value re-quoted at p0 drop by multiples of the cap. Whoever restores the price captures it. Because `rebalance()` is permissionless, an attacker triggers it at fair price and back-runs in the same tx.

## PoC
File: FzWingsBackrunCap.t.sol. Run with `forge test .../fz-wings-backrun-cap/FzWingsBackrunCap.t.sol -vvv`. Result: 3/3 PASS.

Setup:
- Real TestBase Wings fixture: hookless 0.3% pool, spacing 60.
- External full-range LP with L = 1e18.
- 20% sleeve.
- Anchor holds 1e17 in each vault, settled by an honest keeper and an independent arb at p0.

Steps:
1. Honest alice deposits D token0 into wings0. The price stays at p0.
2. BackrunAttacker is an unprivileged contract holding no shares, funded with its own capital (fully counted). In one tx it calls `rebalance(0,ts)` at the fair price, then swaps the pool back to p0.

| deposit D | vault-measured loss | designed cap | holders fair loss @p0 | liq-value loss @p0 | attacker net @p0 | loss/cap |
|---|---|---|---|---|---|---|
| 2e16 | 4.58e13 | 1.82e14 | 8.40e13 | 8.30e14 | +3.83e13 | 0.46x |
| 5e16 | 1.14e14 | 4.64e14 | 4.47e14 | 2.53e15 | +3.34e14 | 0.96x |
| 1e17 | 2.26e14 | 9.46e14 | 1.69e15 | 6.55e15 | +1.46e15 | 1.78x |
| 2e17 | 4.44e14 | 1.93e15 | 6.55e15 | 1.89e16 | +6.11e15 | 3.4x |
| 4e17 | 8.62e14 | 3.91e15 | 2.57e16 | 5.97e16 | +2.48e16 | 6.6x |
| 8e17 | 1.63e15 | 7.79e15 | 9.93e16 | 1.94e17 | +9.77e16 | 12.75x |

- At D = 8e17, alice's fair value goes from 8.017e17 to 7.130e17 (-11%), and the anchor loses proportionally.
- The contract's own check sees only 1.6e15, which is within its 7.8e15 cap.

`test_control_keeperThenArb`: an honest keeper rebalance followed by an independent arb gives the identical holder loss (1.688e15) and arb profit (1.463e15). The leak is therefore inherent to every rebalance swap. The attacker just guarantees it captures the leak and picks the moment (largest pending cash).

The pretransferred (pushed) deposit variant reverted with 0xb18c67ea in this fixture. It was not needed.

## Fix
Measure `valueAfter` against the pre-reshape price, or charge the swap's realised impact (`input - proceeds` valued at the pre-swap spot or a TWAP) against `maximumLoss`. Alternatively, bound `bestSwap`'s `priceLimit` so the cap is enforced on actual price impact, and split large rebalances.
