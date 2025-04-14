# Task IDXEX-058: Deduplicate _refundExcess in SeigniorageDETFExchangeOutTarget

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Priority:** LOW
**Dependencies:** IDXEX-034 ✓
**Worktree:** `feature/dedup-refund-excess-seigniorage`
**Origin:** Code review suggestion from IDXEX-034

---

## Description

`SeigniorageDETFExchangeOutTarget._refundExcess` (line 783) is now duplicated by the identical `BasicVaultCommon._refundExcess` (line 64). Since both are compiled into the same diamond, the Seigniorage version should be removed in favor of the BasicVaultCommon canonical implementation. This reduces code duplication.

(Created from code review of IDXEX-034, Suggestion 2)

## User Stories

### US-IDXEX-058.1: Remove Duplicate _refundExcess

As a protocol developer, I want a single canonical `_refundExcess` implementation so that refund logic is maintained in one place.

**Acceptance Criteria:**
- [ ] `SeigniorageDETFExchangeOutTarget._refundExcess` removed
- [ ] All callers use `BasicVaultCommon._refundExcess` via inheritance
- [ ] Existing SeigniorageDETF tests still pass
- [ ] Build succeeds
- [ ] No test regressions

## Files to Create/Modify

**Modified Files:**
- `contracts/vaults/seigniorage/SeigniorageDETFExchangeOutTarget.sol` - Remove duplicate

## Inventory Check

Before starting, verify:
- [ ] IDXEX-034 is complete
- [ ] `BasicVaultCommon._refundExcess` exists and is identical
- [ ] Inheritance chain allows SeigniorageDETF to access BasicVaultCommon

## Completion Criteria

- [ ] Duplicate removed
- [ ] All tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
