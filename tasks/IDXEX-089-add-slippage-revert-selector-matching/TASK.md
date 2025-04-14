# Task IDXEX-089: Add MinAmountNotMet Selector Matching in Revert Tests

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-049 (completed)
**Worktree:** `feature/IDXEX-089-add-slippage-revert-selector-matching`
**Origin:** Code review suggestion from IDXEX-049

---

## Description

Update slippage protection revert tests to use precise error selector matching instead of bare `vm.expectRevert()`. Currently, the tests use unqualified `vm.expectRevert()` which would pass even if the function reverts for a different reason (e.g., arithmetic overflow). Using `abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, ...)` ensures the tests validate that the correct slippage error is thrown.

(Created from code review of IDXEX-049, Suggestion S-1)

## Dependencies

- IDXEX-049: Enforce minAmountOut Slippage Protection (completed - parent task)

## User Stories

### US-IDXEX-089.1: Add Precise Error Selector Matching to Slippage Revert Tests

As a developer, I want slippage revert tests to match the exact error selector so that tests don't pass silently when a function reverts for an unrelated reason.

**Acceptance Criteria:**
- [ ] All `vm.expectRevert()` calls in `CamelotV2StandardExchangeIn_SlippageProtection.t.sol` use `abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, expectedMin, expectedActual)`
- [ ] All `vm.expectRevert()` calls in `UniswapV2StandardExchangeIn_SlippageProtection.t.sol` use the same pattern
- [ ] Tests still pass with the more precise assertions
- [ ] No other tests broken
- [ ] Build succeeds

## Technical Details

The pattern to apply:
```solidity
// BEFORE (less precise):
vm.expectRevert();

// AFTER (precise):
vm.expectRevert(abi.encodeWithSelector(
    IStandardExchangeErrors.MinAmountNotMet.selector,
    expectedMinAmount,
    expectedActualAmount
));
```

## Files to Create/Modify

**Modified Files:**
- `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchangeIn_SlippageProtection.t.sol`
- `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeIn_SlippageProtection.t.sol`

## Inventory Check

Before starting, verify:
- [ ] IDXEX-049 changes are on main (slippage tests exist)
- [ ] `IStandardExchangeErrors.MinAmountNotMet` error is importable
- [ ] Test files exist and have bare `vm.expectRevert()` calls

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] `forge test` passes (full suite)
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
