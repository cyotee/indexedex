# Task IDXEX-025: Implement ExactOut Variants

**Repo:** IndexedEx
**Status:** Complete
**Created:** 2026-01-31
**Type:** Feature
**Dependencies:** IDXEX-022, IDXEX-023, IDXEX-024
**Worktree:** `feature/exactout-variants`

---

## Description

Add exact-output variants for routes that currently only have exact-input implementations. This allows users to specify the exact amount they want to receive rather than the amount they're willing to spend.

**Current ExactOut Routes (2):**
- WETH → CHIR (exact)
- CHIR → RICH (exact)

**New ExactOut Routes to Add:**
- CHIR → WETH (exact)
- RICHIR → WETH (exact)
- WETH → RICH (exact)
- RICH → CHIR (exact)
- RICH → RICHIR (exact)
- WETH → RICHIR (exact)

## Background

Per the route inventory (`docs/reviews/2026-01-31_protocol-detf-route-inventory.md`):
- ExactOut routes are lower priority than ExactIn
- Useful for precise redemption amounts
- Required for full parity with Standard Exchange interface

## User Stories

### US-IDXEX-025.1: Exact WETH Redemption from CHIR

As a CHIR holder, I want to redeem exactly X WETH so I can pay an exact gas cost or exact purchase.

**Acceptance Criteria:**
- [x] `exchangeOut(CHIR, maxChirIn, WETH, exactWethOut, ...)` works
- [x] `previewExchangeOut(CHIR, *, WETH, wethAmount)` returns required CHIR
- [x] Slippage protection (max input)

### US-IDXEX-025.2: Exact WETH Redemption from RICHIR

As a RICHIR holder, I want to redeem exactly X WETH.

**Acceptance Criteria:**
- [x] `exchangeOut(RICHIR, maxRichirIn, WETH, exactWethOut, ...)` works
- [x] `previewExchangeOut(RICHIR, *, WETH, wethAmount)` returns required RICHIR

### US-IDXEX-025.3: Exact RICH Purchase

As a WETH holder, I want to buy exactly X RICH.

**Acceptance Criteria:**
- [x] `exchangeOut(WETH, maxWethIn, RICH, exactRichOut, ...)` works
- [x] `previewExchangeOut(WETH, *, RICH, richAmount)` returns required WETH

### US-IDXEX-025.4: Exact CHIR from RICH

As a RICH holder, I want to receive exactly X CHIR.

**Acceptance Criteria:**
- [x] `exchangeOut(RICH, maxRichIn, CHIR, exactChirOut, ...)` works
- [x] `previewExchangeOut(RICH, *, CHIR, chirAmount)` returns required RICH

### US-IDXEX-025.5: Exact RICHIR from RICH/WETH

As a RICH or WETH holder, I want to receive exactly X RICHIR.

**Acceptance Criteria:**
- [x] `exchangeOut(RICH, maxRichIn, RICHIR, exactRichirOut, ...)` works
- [x] `exchangeOut(WETH, maxWethIn, RICHIR, exactRichirOut, ...)` works

## Technical Details

### ExactOut Pattern

For exact-output routes, we need to:
1. Calculate the required input for the desired output
2. Verify input doesn't exceed maxAmountIn
3. Execute the swap
4. Refund any excess input

```solidity
function _executeExactChirToWeth(
    uint256 maxChirIn,
    uint256 exactWethOut,
    address recipient,
    uint256 deadline
) internal returns (uint256 chirUsed) {
    // 1. Preview required CHIR for exact WETH
    chirUsed = previewExchangeOut(
        IERC20(address(this)),
        0,
        layout.wethToken,
        exactWethOut
    );

    // 2. Check slippage
    if (chirUsed > maxChirIn) revert MaxAmountExceeded(maxChirIn, chirUsed);

    // 3. Execute swap
    // ...

    // 4. Refund excess if any
    // ...
}
```

### Complexity Note

ExactOut routes for multi-hop paths (like WETH→RICH, RICH→WETH) require careful reverse calculation through both pools. Consider:
- Pool fees compound in reverse
- Rounding must favor the protocol (round UP required input)
- May need iterative approximation for complex paths

### Files to Modify

1. `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol`
   - Add new route implementations
   - Add route detection in `exchangeOut()` dispatcher
   - Add preview logic in `previewExchangeOut()`

2. `test/foundry/spec/vaults/protocol/ProtocolDETF_ExchangeOut.t.sol`
   - Add tests for all new routes

## Test Requirements

1. **test_exchangeOut_chir_to_weth_exact**
2. **test_exchangeOut_richir_to_weth_exact**
3. **test_exchangeOut_weth_to_rich_exact**
4. **test_exchangeOut_rich_to_chir_exact**
5. **test_exchangeOut_rich_to_richir_exact**
6. **test_exchangeOut_weth_to_richir_exact**

Each test should verify:
- Exact output amount received
- Input amount within maxAmountIn
- Preview accuracy (rounds UP for protocol safety)
- Slippage protection

## Completion Criteria

- [x] All 6 new ExactOut routes work
- [x] Preview functions accurate (round UP)
- [x] Slippage protection (maxAmountIn)
- [x] All tests pass
- [x] Build succeeds

## Priority

**Lower priority than IDXEX-022/023/024.** ExactIn routes cover most use cases. Implement after ExactIn routes are complete.

---

**When complete, output:** `<promise>PHASE_DONE</promise>`
