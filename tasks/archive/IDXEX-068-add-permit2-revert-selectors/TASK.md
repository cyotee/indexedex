# Task IDXEX-068: Add Specific Error Selectors to Permit2 Revert Tests

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-037 (complete)
**Worktree:** `feature/add-permit2-revert-selectors`
**Origin:** Code review suggestion from IDXEX-037 (Suggestion 1)

---

## Description

Three Permit2 tests and one BatchRefund test use bare `vm.expectRevert()` without specifying the expected error selector. This means the tests pass on *any* revert, not just the Permit2-specific error. If the router were to revert for a different reason (e.g., a regression that changes the error before Permit2 is reached), these tests would still pass, masking the regression.

Replace bare `vm.expectRevert()` with specific Permit2 error selectors in the failure tests. Permit2 has multiple possible revert paths (`InsufficientAllowance`, `AllowanceExpired`, standard `TransferFrom` errors), so determine which specific error each test scenario triggers and use that selector.

(Created from code review of IDXEX-037)

## Dependencies

- IDXEX-037: Add Balancer V3 Router Integration Tests (parent task, complete)

## User Stories

### US-IDXEX-068.1: Add specific Permit2 error selectors

As a test maintainer, I want Permit2 revert tests to specify exact error selectors so that regressions that change the revert source are not masked.

**Acceptance Criteria:**
- [ ] `test_permit2_noRouterApproval_swapReverts` uses specific error selector instead of bare `vm.expectRevert()`
- [ ] `test_permit2_noERC20Approval_swapReverts` uses specific error selector
- [ ] `test_permit2_directERC20ApproveOnRouter_insufficient` uses specific error selector
- [ ] `test_batchRefund_maxAmountInTooLow_reverts` either uses specific error selector or adds a comment documenting why bare revert is acceptable
- [ ] All modified tests still pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `test/foundry/spec/protocols/balancerV3/BalancerV3StandardExchangeRouter_Permit2.t.sol`
- `test/foundry/spec/protocols/balancerV3/BalancerV3StandardExchangeRouter_BatchRefund.t.sol`

## Inventory Check

Before starting, verify:
- [ ] IDXEX-037 is complete
- [ ] Identify the exact Permit2 error selectors for each failure scenario
- [ ] Confirm the IAllowanceTransfer or ISignatureTransfer interface has the error definitions

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
