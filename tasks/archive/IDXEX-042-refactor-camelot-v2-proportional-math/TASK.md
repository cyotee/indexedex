# Task IDXEX-042: Refactor Camelot V2 Proportional Math

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Dependencies:** IDXEX-014
**Worktree:** `feature/refactor-camelot-v2-proportional-math`
**Origin:** Code review suggestion from IDXEX-014

---

## Description

`CamelotV2StandardExchangeDFPkg.sol` has the same duplication pattern that was fixed in IDXEX-014 for Uniswap V2. Both `_calculateProportionalAmounts()` and `previewDeployVault()` contain inline proportional math. The same extraction into a shared `_proportionalDeposit()` function should be applied.

This follows the pattern established in IDXEX-014 where `UniswapV2StandardExchangeDFPkg` was refactored to extract the shared function.

(Created from code review of IDXEX-014)

## Dependencies

- IDXEX-014: Refactor Shared Proportional Math (parent task) - Complete

## User Stories

### US-IDXEX-042.1: Extract shared proportional math in Camelot V2

As a developer, I want the Camelot V2 DFPkg to use a shared proportional calculation function so that the math in `previewDeployVault()` and `_calculateProportionalAmounts()` cannot drift out of sync.

**Acceptance Criteria:**
- [ ] Create shared `_proportionalDeposit()` function (or equivalent) in CamelotV2StandardExchangeDFPkg
- [ ] `previewDeployVault()` uses the shared function
- [ ] `_calculateProportionalAmounts()` uses the shared function
- [ ] Preview results still match execution results exactly
- [ ] Tests pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol`

## Inventory Check

Before starting, verify:
- [ ] IDXEX-014 is complete (reference implementation exists)
- [ ] `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol` exists
- [ ] Reference: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol` for pattern

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
