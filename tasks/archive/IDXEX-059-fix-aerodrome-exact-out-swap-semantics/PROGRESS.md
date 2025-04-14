# Progress Log: IDXEX-059

## Current Checkpoint

**Last checkpoint:** Implementation complete
**Next step:** Ready for code review
**Build status:** Passing
**Test status:** 170/170 Aerodrome tests pass, 741/744 spec tests pass (3 pre-existing failures in VaultFeeOracle unrelated to this change)

---

## Session Log

### 2026-02-08 - Implementation Complete

#### Problem
The Aerodrome pass-through swap route in `AerodromeStandardExchangeOutTarget.exchangeOut()` used `router.swapExactTokensForTokens()` (exact-input swap) in an exact-out context. While the code correctly computed the needed `amountIn` via `ConstProdUtils._purchaseQuote()`, using the router's exact-input function meant:
- The router consumed the full approved amount rather than just what was needed
- The Aerodrome Router does NOT provide `swapTokensForExactTokens()` (unlike UniswapV2)

#### Solution
Replaced the router-based `swapExactTokensForTokens` call with a direct low-level `pool.swap()` call that provides true exact-out semantics:

1. Transfer the computed `amountIn` directly to the pool (not through the router)
2. Call `pool.swap(amount0Out, amount1Out, recipient, "")` specifying the exact desired output
3. The pool validates the k-invariant and sends exactly `amountOut` to the recipient

This is the same pattern used by UniswapV2's `swapTokensForExactTokens` under the hood.

#### Files Modified
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol`
  - Added `BetterSafeERC20` import and `using` directive
  - Replaced router swap with low-level `pool.swap()` in pass-through swap branch (lines ~414-427)

#### Files Created
- `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchangeOut_Swap.t.sol`
  - 14 tests covering: basic execution, pretransferred refund, exact no-refund, slippage protection, fuzz invariant
  - Tests across balanced, unbalanced, and extreme pool configurations
  - Both A->B and B->A directions

#### Test Results
- 14/14 new tests pass (including 256 fuzz runs)
- 170/170 Aerodrome spec tests pass (zero regressions)
- 741/744 total spec tests pass (3 pre-existing failures in VaultFeeOracle, unrelated)
- Build: clean (no errors, no new warnings)

#### Acceptance Criteria Status
- [x] Aerodrome pass-through swap route uses exact-output swap semantics
- [x] Only the needed input amount is consumed by the swap
- [x] `_refundExcess` correctly returns surplus tokens
- [x] Test: pretransferred with surplus -> refund occurs
- [x] Test: exact amount pretransferred -> no refund, no revert
- [x] Build succeeds
- [x] No test regressions

### 2026-02-07 - Task Created

- Task created from code review suggestion
- Origin: IDXEX-034 REVIEW.md, Suggestion 3
- Ready for agent assignment via /backlog:launch
