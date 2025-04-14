# Code Review: IDXEX-059

**Reviewer:** Claude Opus 4.6
**Review Started:** 2026-02-08
**Status:** Complete

---

## Clarifying Questions

No clarifying questions needed. The task description, TASK.md acceptance criteria, and PROGRESS.md were clear.

---

## Review Findings

### Finding 1: Correct use of low-level pool.swap() for exact-out semantics
**File:** `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol:417-427`
**Severity:** N/A (positive finding)
**Description:** The implementation correctly replaces the router-based `swapExactTokensForTokens` (which consumed all approved input) with a direct `pool.swap()` call. The approach:
1. Computes `amountIn` via `ConstProdUtils._purchaseQuote()` (exact-out math)
2. Transfers only the computed `amountIn` to the pool via `safeTransfer`
3. Calls `pool.swap(amount0Out, amount1Out, recipient, "")` with the exact desired output

This matches how UniswapV2 implements `swapTokensForExactTokens` under the hood. The Aerodrome pool validates the k-invariant internally, so the output is guaranteed correct.
**Status:** Resolved (correct)

### Finding 2: Token direction logic is correct
**File:** `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol:423-425`
**Severity:** N/A (verified correct)
**Description:** The token0/token1 output amount assignment:
```solidity
(uint256 amount0Out, uint256 amount1Out) =
    address(args.tokenOut) == token0 ? (args.amountOut, uint256(0)) : (uint256(0), args.amountOut);
```
Correctly maps `tokenOut` to the right position. If `tokenOut` is `token0`, then `amount0Out = amountOut` and `amount1Out = 0`, and vice versa.
**Status:** Resolved (correct)

### Finding 3: `_secureTokenTransfer` interaction with pretransferred flag
**File:** `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol:409-416`
**Severity:** N/A (verified correct)
**Description:** When `pretransferred=true`, `_secureTokenTransfer` returns the passed `amountIn` value (the computed needed amount, not `maxAmountIn`). This is correct because:
- `amountIn` was already computed as the minimum needed amount
- The subsequent `safeTransfer` to the pool (line 421) will revert if the vault doesn't hold enough
- `_refundExcess` then refunds `maxAmountIn - amountIn` back to the caller

When `pretransferred=false`, `_secureTokenTransfer` pulls exactly `amountIn` from the caller via `transferFrom`, and the balance-delta logic correctly returns only what was received.
**Status:** Resolved (correct)

### Finding 4: Reserve integrity check post-swap
**File:** `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol:431-437`
**Severity:** N/A (verified correct)
**Description:** After the swap and refund, the code verifies that the vault's LP token balance hasn't changed:
```solidity
uint256 poolBalance = IERC20(address(aeroReserve.pool)).balanceOf(address(this));
uint256 storedReserve = ERC4626Repo._lastTotalAssets();
if (poolBalance != storedReserve) { revert(); }
```
This is a safety invariant: a pass-through swap should not affect the vault's LP holdings. The swap only involves the pool's constituent tokens, not the LP token itself. This check correctly guards against any unexpected LP token movement.
**Status:** Resolved (correct)

### Finding 5: `_purchaseQuote` parameter order verified
**File:** `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol:394-405`
**Severity:** N/A (verified correct)
**Description:** `ConstProdUtils._purchaseQuote(amountOut, reserveIn, reserveOut, feePercent, feeDenominator)` is called with:
- `knownReserve` as `reserveIn` (the tokenIn reserve, sorted correctly at lines 383-392)
- `opposingReserve` as `reserveOut` (the tokenOut reserve)

The `_sortReserves` call uses `address(args.tokenIn)` as the known token, ensuring `knownReserve` corresponds to the input side. Parameter order is correct.
**Status:** Resolved (correct)

### Finding 6: `using BetterSafeERC20 for IERC20` correctly added
**File:** `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol:39`
**Severity:** N/A (verified correct)
**Description:** The `using` directive is required because Solidity's `using` declarations in parent contracts (`AerodromeStandardExchangeCommon`, `BasicVaultCommon`) do NOT propagate to child contracts. Without this, the `.safeTransfer()` call at line 421 would fail to compile. Both the import (line 11) and `using` directive (line 39) are correctly added.
**Status:** Resolved (correct)

### Finding 7: Fee parameter hardcoded to `false` (volatile pool)
**File:** `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol:402`
**Severity:** Low (informational)
**Description:** The fee lookup uses `getFee(address(aeroReserve.pool), false)` with `false` hardcoded for the `stable` parameter, rather than using `AerodromePoolMetadataRepo._isStable()` as is done elsewhere in the codebase (e.g., `previewExchangeOut` at line 105). However, this is a pre-existing pattern in the `exchangeOut` function, not introduced by this change. The same `false` hardcoding exists in other branches of `exchangeOut` (e.g., line 487). This appears to be by design for the volatile pool implementation.
**Status:** Resolved (pre-existing, out of scope for this task)

---

## Test Coverage Assessment

### Tests Created: 14 total

| Category | Count | Description |
|----------|-------|-------------|
| Basic execution (preview vs execution) | 6 | Balanced/Unbalanced/Extreme, A->B and B->A |
| Pretransferred refund (surplus) | 4 | Balanced/Unbalanced/Extreme, A->B and B->A |
| Pretransferred exact (no refund) | 2 | Balanced/Unbalanced |
| Slippage protection | 1 | maxAmountIn below required reverts |
| Fuzz invariant | 1 | 256 runs: net spent == amountIn for variable surplus |

### Test Quality

- Tests use `_safeAmountOut()` helper to bound amountOut to 1% of output reserve, preventing overflow on unbalanced/extreme pools
- Fuzz test checks the fundamental refund invariant: `callerBalanceBefore - callerBalanceAfter == amountIn`
- Both token directions (A->B and B->A) are tested across all configurations
- The fuzz test bounds surplus to `[1e12, 100e18]` which is reasonable for 18-decimal tokens

### Regression Results

- 170/170 Aerodrome spec tests pass
- 0 regressions introduced

---

## Suggestions

### Suggestion 1: Add stable pool test coverage (future task)
**Priority:** Low
**Description:** Finding 7 notes the `false` hardcoding for the stable parameter. If stable pools are ever supported in the pass-through swap route, tests should be added. This is pre-existing and not caused by IDXEX-059.
**Affected Files:**
- `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchangeOut_Swap.t.sol`
**User Response:** (pending)
**Notes:** Informational only - no action needed for this task.

### Suggestion 2: Consider adding a B->A direction for pretransferred exact no-refund tests
**Priority:** Low
**Description:** The `_test_pretransferredExactNoRefund` tests only cover A->B direction for balanced and unbalanced pools. Adding B->A would complete the matrix. However, since the logic is symmetric (same code path, just different reserve sorting), this is low priority.
**Affected Files:**
- `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchangeOut_Swap.t.sol`
**User Response:** Accepted
**Notes:** Converted to task IDXEX-091

---

## Acceptance Criteria Verification

- [x] **Aerodrome pass-through swap route uses exact-output swap semantics** - Verified: `pool.swap(amount0Out, amount1Out, ...)` with exact output amounts
- [x] **Only the needed input amount is consumed by the swap** - Verified: only `amountIn` (computed via `_purchaseQuote`) is transferred to the pool
- [x] **`_refundExcess` correctly returns surplus tokens** - Verified: `_refundExcess(tokenIn, maxAmountIn, amountIn, ...)` refunds `maxAmountIn - amountIn`
- [x] **Test: pretransferred with surplus -> refund occurs** - Verified: 4 tests (`_test_pretransferredRefund`) + fuzz test
- [x] **Test: exact amount pretransferred -> no refund, no revert** - Verified: 2 tests (`_test_pretransferredExactNoRefund`)
- [x] **Build succeeds** - Verified: clean compilation
- [x] **No test regressions** - Verified: 170/170 Aerodrome tests pass

---

## Review Summary

**Findings:** 7 findings, all resolved as correct. No bugs, no security issues identified.
**Suggestions:** 2 low-priority suggestions (additional test coverage for stable pools and B->A direction in no-refund tests).
**Recommendation:** **APPROVE** - The implementation is correct, well-tested, and solves the exact problem described in the task. The approach of using low-level `pool.swap()` is sound and matches the pattern used by UniswapV2 routers internally. All acceptance criteria are met.

---

**When review complete, output:** `<promise>PHASE_DONE</promise>`
