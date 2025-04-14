# Task IDXEX-079: Use stdError.arithmeticError in Fuzz Revert Tests

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Type:** Testing / Code Quality
**Dependencies:** IDXEX-046 ✓
**Worktree:** `feature/IDXEX-079-use-stderror-arithmetic-in-fuzz`
**Origin:** Code review suggestion from IDXEX-046 (Suggestion 2)

---

## Description

Replace bare `vm.expectRevert()` with `vm.expectRevert(stdError.arithmeticError)` in `test_sqrt_maxUint256_reverts` to make the expected revert type explicit and self-documenting. The sqrt of `type(uint256).max` produces a Solidity 0.8.x arithmetic panic; the test should assert the specific panic code rather than catching any revert.

(Created from code review of IDXEX-046, Suggestion 2)

## Dependencies

- IDXEX-046: Add Fuzz Tests for Aerodrome Proportional Math (completed - parent task)

## Acceptance Criteria

- [ ] `test_sqrt_maxUint256_reverts` uses `vm.expectRevert(stdError.arithmeticError)` instead of bare `vm.expectRevert()`
- [ ] `stdError` is properly imported (from `forge-std/StdError.sol` or re-exported via `Test`)
- [ ] All fuzz tests still pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchange_Fuzz.t.sol:335`

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
