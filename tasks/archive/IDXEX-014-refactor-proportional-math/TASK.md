# Task IDXEX-014: Refactor Shared Proportional Math

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-13
**Type:** Refactor
**Dependencies:** IDXEX-008
**Worktree:** `feature/refactor-proportional-math`
**Origin:** Deferred debt D1 from IDXEX-008 code review

---

## Description

Extract shared proportional math logic to avoid duplication between `previewDeployVault()` and `_calculateProportionalAmounts()` in the Uniswap V2 DFPkg.

Currently, the preview function and execution function duplicate the same proportional calculation logic. This creates drift risk if one is updated without the other.

(Created from code review deferred debt of IDXEX-008)

## User Stories

### US-IDXEX-014.1: Extract Shared Helper

As a developer, I want proportional calculation logic in a single place so that preview and execution always match.

**Acceptance Criteria:**
- [ ] Create a shared view/pure function for proportional calculation
- [ ] `previewDeployVault()` uses the shared function
- [ ] `_calculateProportionalAmounts()` uses the shared function
- [ ] Preview results still match execution results exactly
- [ ] Tests pass
- [ ] Build succeeds

## Files to Modify

**Primary:**
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol`

**Tests:**
- `test/foundry/spec/protocols/dexes/uniswap/v2/UniswapV2StandardExchange_DeployWithPool.t.sol`

## Implementation Notes

Consider:
1. Creating a pure/view function that both preview and execution call
2. Keeping the same semantics (never exceeds user-provided max amounts)
3. Handling edge cases (zero reserves) consistently

## Completion Criteria

- [ ] Shared helper function created
- [ ] No code duplication between preview and execution
- [ ] Preview/execution parity maintained
- [ ] All tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
