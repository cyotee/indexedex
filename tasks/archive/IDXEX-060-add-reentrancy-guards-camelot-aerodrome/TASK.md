# Task IDXEX-060: Add Reentrancy Guards to CamelotV2 and Aerodrome ExchangeOut Targets

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Priority:** LOW
**Dependencies:** IDXEX-034 ✓
**Worktree:** `feature/add-reentrancy-guards-camelot-aerodrome`
**Origin:** Code review suggestion from IDXEX-034

---

## Description

`UniswapV2StandardExchangeOutTarget` uses `ReentrancyLockModifiers` and the `lock` modifier on `exchangeOut`. `CamelotV2StandardExchangeOutTarget` and `AerodromeStandardExchangeOutTarget` do not. Since all three targets perform external calls (router swaps, token transfers, `_refundExcess` safeTransfer), reentrancy protection should be consistent across all implementations.

Note: The diamond pattern may provide reentrancy protection at a different layer. This task should first verify whether diamond-level reentrancy guards exist before adding target-level guards.

(Created from code review of IDXEX-034, Suggestion 4)

## User Stories

### US-IDXEX-060.1: Consistent Reentrancy Guards

As a security auditor, I want consistent reentrancy protection across all ExchangeOut targets so that no target is more vulnerable than others.

**Acceptance Criteria:**
- [ ] Investigate if diamond-level reentrancy guard exists
- [ ] If not: add `ReentrancyLockModifiers` + `lock` to CamelotV2 and Aerodrome targets
- [ ] If yes: document the finding and close task
- [ ] Build succeeds
- [ ] No test regressions

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol`
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol`

## Inventory Check

Before starting, verify:
- [ ] IDXEX-034 is complete
- [ ] Check if Crane diamond framework includes reentrancy guards
- [ ] Check `ReentrancyLockModifiers` import path

## Completion Criteria

- [ ] Reentrancy protection consistent across all ExchangeOut targets
- [ ] Build succeeds
- [ ] No test regressions

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
