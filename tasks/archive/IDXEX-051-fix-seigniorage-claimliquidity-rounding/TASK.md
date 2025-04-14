# Task IDXEX-051: Fix Seigniorage claimLiquidity Rounding Tolerance

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Priority:** HIGH
**Dependencies:** None
**Worktree:** `feature/fix-seigniorage-claimliquidity-rounding`

---

## Description

The Seigniorage DETF `claimLiquidity` flow fails with `AmountOutBelowMin` during `redeem()` due to a 1-wei rounding discrepancy between the locally computed `minAmountsOut` and the actual amounts returned by Balancer V3's proportional exit math. The test `testFork_Underwrite_ThenRedeem_ReturnsRateTarget` reliably reproduces this failure.

**Root cause:** `_removeLiquidityFromPool()` computes `expectedExitAmounts` using `(balance * bptIn) / totalSupply` and passes the result directly as `minAmountsOut` to `prepayRemoveLiquidityProportional()`. Balancer V3's internal proportional exit can round down by 1 wei differently, causing the strict `>=` check to revert.

**Error:** `AmountOutBelowMin(0x24F2..., 999999999999842475353, 999999999999842475354)` — off by exactly 1 wei.

## User Stories

### US-IDXEX-051.1: Add Rounding Tolerance to minAmountsOut

As a protocol user, I want the redeem flow to succeed even when Balancer V3's proportional exit rounds down by 1 wei.

**Acceptance Criteria:**
- [ ] `_removeLiquidityFromPool()` subtracts 1 from each non-zero `expectedExitAmounts` element before passing as `minAmountsOut`
- [ ] The subtraction is safe (does not underflow for zero amounts)
- [ ] NatSpec comment explains why the 1-wei buffer exists

### US-IDXEX-051.2: Fork Test Passes

As a developer, I want the existing fork test to pass after the fix.

**Acceptance Criteria:**
- [ ] `testFork_Underwrite_ThenRedeem_ReturnsRateTarget` passes
- [ ] All other Seigniorage fork tests still pass
- [ ] Build succeeds with no new warnings

## Technical Details

**File to modify:** `contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol`

**Function:** `_removeLiquidityFromPool()` (approx line 541-591)

**Current (broken):**
```solidity
uint256[] memory expectedExitAmounts = BalancerV38020WeightedPoolMath.calcProportionalAmountsOutGivenBptIn(
    currentBalances,
    poolTotalSupply,
    lpAmount
);

// ... later:
uint256[] memory amountsOut = layout.balancerV3PrepayRouter.prepayRemoveLiquidityProportional(
    address(reservePool_),
    lpAmount,
    expectedExitAmounts,  // <-- used directly as minAmountsOut
    ""
);
```

**Fixed:**
```solidity
uint256[] memory expectedExitAmounts = BalancerV38020WeightedPoolMath.calcProportionalAmountsOutGivenBptIn(
    currentBalances,
    poolTotalSupply,
    lpAmount
);

// Apply 1-wei rounding tolerance for Balancer V3 proportional exit math.
// Balancer's internal mulDivDown can round differently from our calculation,
// producing amounts up to 1 wei below our local estimate.
uint256[] memory minAmountsOut = new uint256[](expectedExitAmounts.length);
for (uint256 i = 0; i < expectedExitAmounts.length; ++i) {
    minAmountsOut[i] = expectedExitAmounts[i] > 0 ? expectedExitAmounts[i] - 1 : 0;
}

// ... later:
uint256[] memory amountsOut = layout.balancerV3PrepayRouter.prepayRemoveLiquidityProportional(
    address(reservePool_),
    lpAmount,
    minAmountsOut,  // <-- 1-wei tolerant
    ""
);
```

## Files to Create/Modify

**Modified Files:**
- `contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol` - Add 1-wei rounding tolerance to `_removeLiquidityFromPool()`

**Tests (existing, should pass after fix):**
- `test/foundry/fork/base_main/seigniorage/SeigniorageFork_DETFIntegration.t.sol` - `testFork_Underwrite_ThenRedeem_ReturnsRateTarget()`

## Inventory Check

Before starting, verify:
- [ ] Locate `_removeLiquidityFromPool()` in `SeigniorageDETFUnderwritingTarget.sol`
- [ ] Confirm `expectedExitAmounts` is passed directly as `minAmountsOut`
- [ ] Check for similar patterns in other `removeLiquidity` call sites

## Completion Criteria

- [ ] `testFork_Underwrite_ThenRedeem_ReturnsRateTarget` passes
- [ ] All existing Seigniorage tests pass
- [ ] Build succeeds
- [ ] No other `removeLiquidityProportional` call sites have the same issue

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
