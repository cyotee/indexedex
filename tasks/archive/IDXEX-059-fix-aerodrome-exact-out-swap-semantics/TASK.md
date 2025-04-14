# Task IDXEX-059: Fix Aerodrome Pass-Through Swap Exact-Out Semantics

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Priority:** HIGH
**Dependencies:** IDXEX-034 ✓
**Worktree:** `feature/fix-aerodrome-exact-out-swap-semantics`
**Origin:** Code review suggestion from IDXEX-034

---

## Description

The Aerodrome pass-through swap route in `AerodromeStandardExchangeOutTarget` uses `swapExactTokensForTokens` (exact-input swap) in an exact-out context (`exchangeOut`). When `pretransferred == true` with surplus, the entire pretransferred balance is swapped rather than just the computed amount needed. This means `_refundExcess` cannot refund anything because `amountIn` equals the full balance.

The fix should use `swapTokensForExactTokens` (or equivalent exact-output swap) so that only the needed input tokens are consumed, allowing `_refundExcess` to correctly return the surplus.

This is a pre-existing bug, not introduced by IDXEX-034. The other two targets (UniswapV2, CamelotV2) handle this correctly.

(Created from code review of IDXEX-034, Suggestion 3)

## User Stories

### US-IDXEX-059.1: Fix Aerodrome Exact-Out Swap

As a user performing an exact-out exchange through Aerodrome, I want excess pretransferred tokens refunded to me, not consumed by an exact-input swap.

**Acceptance Criteria:**
- [ ] Aerodrome pass-through swap route uses exact-output swap semantics
- [ ] Only the needed input amount is consumed by the swap
- [ ] `_refundExcess` correctly returns surplus tokens
- [ ] Test: pretransferred with surplus -> refund occurs
- [ ] Test: exact amount pretransferred -> no refund, no revert
- [ ] Build succeeds
- [ ] No test regressions

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol` - Fix swap function call

## Inventory Check

Before starting, verify:
- [ ] IDXEX-034 is complete
- [ ] Aerodrome Router supports `swapTokensForExactTokens` or equivalent
- [ ] Understand the Aerodrome router interface for exact-output swaps

## Completion Criteria

- [ ] Aerodrome exact-out swap correctly limits input consumption
- [ ] Refund works when pretransferred with surplus
- [ ] All tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
