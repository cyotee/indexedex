# fz-v3fs-deep-inv1: V3FSInvariantTest INV-1 break from the deep campaign (run 32)

## Verdict
**DUPLICATE (root cause) of `fs-maintenance-at-spot-jit`.** This is a new idle-only trigger for the same bug, and it widens that finding.
Root cause: `_rebalanceLiquidReserveBestEffort()` mints free-sleeve excess at whatever spot the pool is at.
Here the spot is moved by the vault's own unbounded idle zap-out swap: `_swapRemovedOtherPlusFreeShare` calls `_swap(..., 0, ...)` with no price limit (the fs-user-slippage idle-redemption-swap item).
This happens inside `_executeFreeZapOutExactIn` (InBase.sol:245-260), which then runs `_rebalanceLiquidReserveBestEffort()` at the moved spot.
The p2 hypothesis text for fs-maintenance-at-spot-jit already names "right after the caller's own unbounded direct swap".

## Which step creates the free value
Concrete replay: `Replay.t.sol`, exact calldata from slot11 `cache/invariant/failures/V3FSInvariantTest/invariants/invariant_medium`.
It reproduces the break: profit 135.118e18 vs allowance 82.045e18.
- Steps 8-9 (`a_mintExactOut` single-sided token1): the attacker skews the book (free1 = 18,137e18, book 7,100 / 23,818). It loses 1,095e18 to the other holders.
- Step 10 (`a_sandwich`, sub 297 maps to sub 3 = idle zap-out exact-in to token0, then the attacker swaps back to P0): the attacker gains **+1,230e18** in this one step.
`Decompose.t.sol` isolates step 10:
- The push size does not matter. With a 5 bp push (C) the gain is +1,240e18, so the attacker's price push is not the cause.
- Rebalance-only (sub 6) and dual-exit (sub 5) after the same skew give +0.73e18.
- With no skew (D), the same zap-out loses 190e18.

Events in step 10 (`SkewZapOutJit.t.sol` main):
1. The vault burns pro-rata.
2. The vault swaps 9,849e18 token1 for 1,824e18 token0 with no limit, moving sqrtP to 5.40x.
3. Best-effort rebalance runs at that spot: **vault MINT L=946.8e18 (a0=175e18, a1=5,108e18)**.
4. The attacker swaps back to P0 and receives 13,981e18 token1 for 2,603e18 token0.

The new liquidity takes the IL on the way back.

## Standalone PoC (executed): `SkewZapOutJit.t.sol`
- Setup: genesis fixture with honest LPs (passive 1000/1000, 3x300/300, one 200/200), keeper-rebalanced 20% sleeve, external L = 800e18, 0.3% pool.
- Attacker: a plain contract with its own capital (no flash loan, no pranks), in idle mode.
- One call `attack()` does four things: dual deposit 1500/1500, single-sided token1 zap-in 16,000e18, zap out 67% of its shares to token0, swap the pool back to exactly sp0.
- The remaining shares are then exited pro-rata at P0.

| params (dual / skew1 / zap%) | attacker net @P0 | honest LP loss @P0 |
|---|---|---|
| 1500/16000/67% (main) | **+78.65e18** | **91.22e18** |
| 1500/16000/80% | +83.88e18 | 100.43e18 |
| 1500/6000/100% | +69.10e18 | 79.07e18 |
| 1500/8000/100% | +60.89e18 | 73.71e18 |
| 1500/4000/100% | +50.65e18 | 57.94e18 |
| control: no skew | -35.28e18 | -32.90e18 |
| control: skew, no zap-out | -1600e18 | -1600e18 |

Honest loss is about 2.2-2.4% of the roughly 4,200e18 honest TVL per tx.

## Notes
- This widens the known finding. The p3 write-up of fs-maintenance-at-spot-jit says the idle path is not exploitable because one-sided excess plans a zero mint, and it confirmed only the blocked-mode dual-deposit route. That is wrong for the zap-out path:
  - an idle single-sided zap-in builds one-sided excess;
  - the vault's own zap-out swap moves the spot in the direction that makes that excess mintable.
  - So blocking blocked mode or callbacks does not fix it. The fix has to stop rebalance mints at a spot that deviates from a TWAP/oracle, and skip `_rebalanceLiquidReserveBestEffort()` after the vault's own swap in `_executeFreeZapOutExactIn`. Separately, give the idle redemption swap a price limit.
- Harness: INV-1 is correct here. The off-price-mint excuse only covers passive loss, not attacker profit. To keep the campaign hunting, quarantine this class: attribute attacker gain in steps that contain an off-price vault Mint after a vault Swap.
