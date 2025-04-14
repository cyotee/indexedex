# Task IDXEX-037: Add Balancer V3 Router Integration Tests

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** HIGH
**Dependencies:** IDXEX-033, IDXEX-034
**Worktree:** `feature/add-balancer-v3-router-tests`

---

## Description

The code review identified missing tests for critical Balancer V3 router invariants and assumptions. This task adds comprehensive test coverage for:
1. `SwapDeadline()` error behavior
2. Permit2-only token pull requirement
3. Transient storage clearing (`currentStandardExchangeToken`)
4. Prepay authorization (`onlyUnlockedOrSEToken`)
5. Batch exact-out refund forwarding
6. Query hook access control (after IDXEX-033 fix)

**Source:** REVIEW_REPORT.md lines 855-856, 922-928

## User Stories

### US-IDXEX-037.1: SwapDeadline Error Tests

As a protocol developer, I want tests proving the deadline revert works correctly.

**Acceptance Criteria:**
- [ ] Test: `SwapDeadline()` error exists and is the intended revert
- [ ] Test: expired deadline reverts with `SwapDeadline`
- [ ] Test: valid deadline proceeds

### US-IDXEX-037.2: Permit2 Requirement Tests

As an integrator, I want tests documenting the Permit2 requirement.

**Acceptance Criteria:**
- [ ] Test: ERC20 `transferFrom` is NOT used (Permit2 only)
- [ ] Test: without Permit2 approval, token pull fails
- [ ] Test: with Permit2 approval, token pull succeeds

### US-IDXEX-037.3: Transient Storage Tests

As a security auditor, I want tests proving transient state is cleaned up.

**Acceptance Criteria:**
- [ ] Test: `currentStandardExchangeToken` is set during swap
- [ ] Test: `currentStandardExchangeToken` is cleared on success
- [ ] Test: `currentStandardExchangeToken` is cleared on revert

### US-IDXEX-037.4: Prepay Authorization Tests

As a security auditor, I want tests for the `onlyUnlockedOrSEToken` modifier.

**Acceptance Criteria:**
- [ ] Test: when Vault unlocked, any caller can invoke prepay
- [ ] Test: when Vault locked + current token set, only that token can call
- [ ] Test: when Vault locked + no token, only contracts can call (EOAs blocked)

### US-IDXEX-037.5: Batch Exact-Out Refund Tests

As a vault user, I want tests proving refunds work in batch exact-out swaps.

**Acceptance Criteria:**
- [ ] Test: strategy-vault step uses less than `maxAmountIn` → refund forwarded
- [ ] Test: refund is settled correctly in Balancer Vault
- [ ] Test: strategy vault that doesn't refund → settlement fails predictably

### US-IDXEX-037.6: Query Hook Access Tests (Post-Fix)

As a security auditor, I want regression tests after IDXEX-033 fix.

**Acceptance Criteria:**
- [ ] Test: `querySwapSingleTokenExactInHook` direct call reverts
- [ ] Test: reentrancy via malicious strategy vault is blocked
- [ ] Test: query via `vault.quote()` still works

## Technical Details

**Test files:**
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_Deadline.t.sol`
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_Permit2.t.sol`
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_TransientState.t.sol`
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_PrepayAuth.t.sol`
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchRefund.t.sol`
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_QueryHookAbuse.t.sol`

**Starting point:** Clone/modify `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchExactIn.t.sol`

## Files to Create

**New Files:**
- 6 test files as listed above

## Dependencies

- IDXEX-033: Query hook access control fix (for US-IDXEX-037.6)
- IDXEX-034: StandardExchangeOut refund fix (for US-IDXEX-037.5)

## Inventory Check

Before starting, verify:
- [ ] Existing Balancer V3 router test base (`TestBase_BalancerV3StandardExchangeRouter`)
- [ ] Balancer V3 Vault mock or fork setup
- [ ] Permit2 integration in test environment

## Completion Criteria

- [ ] All 6 test files created and passing
- [ ] Critical invariants documented via tests
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
