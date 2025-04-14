# Task IDXEX-049: Enforce minAmountOut Slippage Protection

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Dependencies:** IDXEX-007 (completed)
**Worktree:** `feature/enforce-minamountout-slippage`
**Origin:** Code review suggestion from IDXEX-007 (systemic issue)

---

## Description

Enforce `minAmountOut` slippage protection across all exchange facets. Currently, `minAmountOut` is explicitly suppressed in exchange-in targets (e.g., `minAmountOut;` with no effect). This leaves all vault exchange routes without slippage protection.

This is a systemic issue affecting all vault types, not just Camelot V2.

(Created from code review of IDXEX-007, Suggestion 2 / Finding #5)

## Dependencies

- IDXEX-007: Review Camelot V2 DFPkg deployVault (completed - parent task)

## User Stories

### US-IDXEX-049.1: Enforce minAmountOut in all exchange facets

As a vault user, I want exchange operations to enforce my specified `minAmountOut` so that I am protected from excessive slippage.

**Acceptance Criteria:**
- [ ] Camelot V2 `CamelotV2StandardExchangeInTarget` enforces `minAmountOut`
- [ ] Uniswap V2 exchange-in target enforces `minAmountOut`
- [ ] Aerodrome exchange-in target enforces `minAmountOut`
- [ ] Balancer V3 exchange-in target enforces `minAmountOut`
- [ ] Each enforcement has a corresponding revert test
- [ ] Tests pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeInTarget.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol` (if applicable)
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeInTarget.sol` (if applicable)
- `contracts/protocols/dexes/balancer/v3/BalancerV3StandardExchangeInTarget.sol` (if applicable)
- Corresponding test files

## Inventory Check

Before starting, verify:
- [ ] Identify all `*ExchangeInTarget.sol` files that suppress minAmountOut
- [ ] Understand how `minAmountOut` is passed through the exchange interface
- [ ] Check if `minAmountOut` == 0 should be treated as "no slippage check" (common pattern)

## Completion Criteria

- [ ] All exchange-in targets enforce minAmountOut when non-zero
- [ ] Revert tests for each target when output < minAmountOut
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
