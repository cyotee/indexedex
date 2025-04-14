# Task IDXEX-055: Fix VaultFeeOracleRepo Internal Function Typo

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Priority:** LOW
**Dependencies:** IDXEX-032 ✓
**Worktree:** `feature/fix-fee-oracle-repo-typo`
**Origin:** Code review suggestion from IDXEX-032

---

## Description

The internal function `_setDefaultSeigniorageIncentivePerecetageOfTypeId` (line 334 of `VaultFeeOracleRepo.sol`) has a typo: "Perecetage" instead of "Percentage". The public-facing wrapper at line 343 has the correct spelling. This is a pure rename with no behavior change.

(Created from code review of IDXEX-032, Suggestion 3)

## User Stories

### US-IDXEX-055.1: Fix Function Name Typo

As a developer, I want internal function names to be correctly spelled so that the codebase is consistent and searchable.

**Acceptance Criteria:**
- [ ] `_setDefaultSeigniorageIncentivePerecetageOfTypeId` renamed to `_setDefaultSeigniorageIncentivePercentageOfTypeId`
- [ ] All call sites updated
- [ ] Build succeeds
- [ ] No test regressions

## Files to Create/Modify

**Modified Files:**
- `contracts/oracles/fee/VaultFeeOracleRepo.sol` - Rename internal function

## Inventory Check

Before starting, verify:
- [ ] IDXEX-032 is complete
- [ ] Locate the typo'd function and all call sites
- [ ] Confirm the public wrapper already has correct spelling

## Completion Criteria

- [ ] Function renamed correctly
- [ ] All call sites updated
- [ ] Build succeeds
- [ ] No test regressions

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
