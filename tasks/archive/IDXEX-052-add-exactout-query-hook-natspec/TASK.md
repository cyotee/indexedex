# Task IDXEX-052: Add NatSpec Parity to ExactOut Query Hook

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Priority:** LOW
**Dependencies:** IDXEX-033 (complete)
**Source:** IDXEX-033 code review, Suggestion 1
**Worktree:** `feature/add-exactout-query-hook-natspec`

---

## Description

The ExactOut query hook (`querySwapSingleTokenExactOutHook`) already has the `onlyBalancerV3Vault` modifier but lacks the detailed security NatSpec documentation that was added to the ExactIn hook during IDXEX-033. For consistency and future developer awareness, the same security documentation pattern should be applied.

**Current ExactOut NatSpec (minimal):**
```solidity
/**
 * @notice Internal hook for querying exact output swaps
 */
function querySwapSingleTokenExactOutHook(...)
    external
    onlyBalancerV3Vault
    ...
```

**Reference ExactIn NatSpec (target pattern):**
```solidity
/**
 * @notice Hook called by the Balancer V3 Vault during quote() to simulate exact-in swaps.
 * @dev SECURITY: Must be restricted to Vault-only via onlyBalancerV3Vault.
 * This function calls _balVault.swap() which mutates transient accounting state.
 * Without access control, a direct external call or a reentrancy from a malicious
 * strategy vault callback (during IVault.unlock) could execute uncontrolled deltas
 * in Balancer's transient accounting, leading to DoS or delta manipulation.
 * @param params The swap parameters forwarded from querySwapSingleTokenExactIn.
 * @return amountCalculated The calculated output amount for the simulated swap.
 */
```

## User Stories

### US-IDXEX-052.1: Add Security NatSpec to ExactOut Query Hook

As a developer, I want the ExactOut query hook to have the same detailed security NatSpec as the ExactIn hook, so the security rationale is immediately visible.

**Acceptance Criteria:**
- [ ] `querySwapSingleTokenExactOutHook` has a `@notice` explaining it is called by the Vault during `quote()`
- [ ] `@dev` block documents the `onlyBalancerV3Vault` requirement
- [ ] `@dev` block explains the `_balVault.swap()` transient accounting risk
- [ ] `@dev` block mentions direct-call and reentrancy attack vectors
- [ ] `@param` and `@return` tags are present and accurate
- [ ] NatSpec follows the same pattern as the ExactIn hook

## Technical Details

**File to modify:** `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutQueryTarget.sol`

**Function:** `querySwapSingleTokenExactOutHook()` (line ~115)

**Change:** Replace the minimal NatSpec comment block with the detailed security documentation pattern matching the ExactIn hook, adjusted for ExactOut specifics.

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutQueryTarget.sol` - Update NatSpec on `querySwapSingleTokenExactOutHook()`

## Completion Criteria

- [ ] NatSpec matches ExactIn hook pattern (adjusted for ExactOut)
- [ ] Build succeeds with no new warnings
- [ ] No functional code changes (NatSpec only)

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
