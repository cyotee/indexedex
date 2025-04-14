# Task IDXEX-033: Fix Balancer V3 Query Hook Public Access

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-02
**Priority:** CRITICAL
**Dependencies:** None
**Worktree:** `feature/fix-balancer-v3-query-hook-access`

---

## Description

The Balancer V3 exact-in query hook (`querySwapSingleTokenExactInHook`) is publicly callable and executes actual `IVault.swap(...)` operations. This function is intended only for `IVault.quote(...)` contexts but lacks the `onlyBalancerV3Vault` modifier, creating a public stateful surface that bypasses expected router entrypoint controls.

**Source:** REVIEW_REPORT.md lines 858-901

## Impact Analysis

**Direct call exploit:** Any user can call `querySwapSingleTokenExactInHook(...)` directly on the router diamond, reaching `_balVault.swap(...)` on several branches. Even if it reverts due to missing credits/settlement, this breaks the critical assumption ("safe because we're in a query context").

**Reentrancy exploit:** During any `IVault.unlock(...)` callback:
1. A malicious strategy vault can re-enter the router
2. Call `querySwapSingleTokenExactInHook(...)` while Vault is unlocked
3. Execute extra deltas without corresponding settlement
4. Either DoS the parent call (transient accounting invariant failure) or create out-of-band deltas

**Affected files:**
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInQueryTarget.sol`
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInQueryFacet.sol`

## User Stories

### US-IDXEX-033.1: Add Access Control to Query Hook

As a protocol user, I want query hooks to be properly restricted so that they cannot be abused to manipulate swap execution.

**Acceptance Criteria:**
- [ ] `querySwapSingleTokenExactInHook(...)` has `onlyBalancerV3Vault` modifier
- [ ] Direct calls from non-vault addresses revert
- [ ] Query hooks can still be called via `IVault.quote(...)`

### US-IDXEX-033.2: Add Selector Surface Regression Test

As a security auditor, I want tests proving the query hook cannot be called externally after the fix.

**Acceptance Criteria:**
- [ ] Test: direct call to `querySwapSingleTokenExactInHook` reverts (not `onlyBalancerV3Vault`)
- [ ] Test: reentrancy via malicious strategy vault is blocked
- [ ] Selector surface test: assert hook selector NOT exposed without `onlyBalancerV3Vault`

### US-IDXEX-033.3: Document Query Hook Security Model

As a future developer, I want clear documentation on why query hooks must be vault-only.

**Acceptance Criteria:**
- [ ] NatSpec comment on hook function explaining security requirement
- [ ] Comment explaining reentrancy risk from strategy vault callbacks

## Technical Details

**File to modify:** `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInQueryTarget.sol`

**Current (vulnerable):**
```solidity
function querySwapSingleTokenExactInHook(
    SwapSingleTokenHookParams calldata params
)
    external
    // MISSING: onlyBalancerV3Vault
    returns (uint256)
{
    // ... calls _balVault.swap(...)
}
```

**Fixed:**
```solidity
function querySwapSingleTokenExactInHook(
    SwapSingleTokenHookParams calldata params
)
    external
    onlyBalancerV3Vault
    returns (uint256)
{
    // ... calls _balVault.swap(...)
}
```

## Test Plan (from review)

**New file:** `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_ExactInQueryHookAbuse.t.sol`

**Test case A (reentrancy DoS):**
1. Deploy `MaliciousStrategyVault` implementing `IStandardExchangeIn.exchangeIn(...)`
2. In `exchangeIn`, re-enter router calling `querySwapSingleTokenExactInHook(...)`
3. Assert outer router call reverts (proves reentrancy risk exists)

**Test case B (external call surface):**
1. Call `querySwapSingleTokenExactInHook(...)` directly from EOA/test contract
2. Assert it reverts with access control error (after fix) or accounting error (before fix)

**Test case C (selector exposure regression):**
1. Assert `querySwapSingleTokenExactInHook.selector` is exposed on router diamond
2. After fix: assert calls revert with `onlyBalancerV3Vault` check

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInQueryTarget.sol` - Add `onlyBalancerV3Vault`

**Tests:**
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_ExactInQueryHookAbuse.t.sol`

## Inventory Check

Before starting, verify:
- [ ] Locate `BalancerV3StandardExchangeRouterExactInQueryTarget.sol`
- [ ] Confirm `onlyBalancerV3Vault` modifier exists in codebase
- [ ] Check if similar query hooks in exact-out also need fixing

## Completion Criteria

- [ ] Query hook has `onlyBalancerV3Vault` modifier
- [ ] Reentrancy/direct-call tests pass
- [ ] Build succeeds
- [ ] All existing Balancer V3 router tests pass

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
