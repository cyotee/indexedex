# Progress Log: IDXEX-051

## Current Checkpoint

**Last checkpoint:** Implementation complete
**Next step:** Code review / merge
**Build status:** PASSING
**Test status:** PASSING (41/41 seigniorage tests)

---

## Session Log

### 2026-02-07 - Implementation Complete

- **Modified:** `contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol`
  - In `_removeLiquidityFromPool()` (line ~565), applied 1-wei rounding tolerance to `expectedExitAmounts` in-place before passing as `minAmountsOut` to `prepayRemoveLiquidityProportional()`
  - Used in-place mutation with `unchecked` block instead of new array to avoid stack-too-deep error (function already at EVM stack limit)
  - Added NatSpec comment explaining the Balancer V3 mulDivDown rounding difference
- **Audit of other call sites:** Confirmed only this call site is affected — all other `prepayRemoveLiquidityProportional` callers either use `[0, 0]` minAmountsOut or only set a minimum for the desired token
- **Build:** Passes (no new warnings)
- **Tests:** All 41 seigniorage tests pass including `testFork_Underwrite_ThenRedeem_ReturnsRateTarget`

### Acceptance Criteria Status

- [x] `_removeLiquidityFromPool()` subtracts 1 from each non-zero `expectedExitAmounts` element before passing as `minAmountsOut`
- [x] The subtraction is safe (uses `> 0` guard, `unchecked` is safe because value > 0)
- [x] NatSpec comment explains why the 1-wei buffer exists
- [x] `testFork_Underwrite_ThenRedeem_ReturnsRateTarget` passes
- [x] All other Seigniorage fork tests still pass (41/41)
- [x] Build succeeds with no new warnings
- [x] No other `removeLiquidityProportional` call sites have the same issue

### 2026-02-06 - Task Created

- Task designed via /design
- Root cause identified: 1-wei rounding discrepancy in `_removeLiquidityFromPool()` minAmountsOut
- Error trace: `AmountOutBelowMin(actual: 999999999999842475353, min: 999999999999842475354)`
- Fix: subtract 1 from each non-zero expectedExitAmounts before passing as minAmountsOut
- Ready for agent assignment via /backlog:launch
