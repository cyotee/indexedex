# Task IDXEX-023: Wire wethToRichir() into exchangeIn() Dispatcher

**Repo:** IndexedEx
**Status:** Complete
**Created:** 2026-01-31
**Type:** Refactor
**Dependencies:** IDXEX-021
**Worktree:** `feature/weth-richir-exchangein`

---

## Description

The `wethToRichir()` function already exists in `ProtocolDETFBondingTarget.sol` but is not accessible via the standard `IStandardExchangeIn` interface. This task wires the existing functionality into the `exchangeIn()` dispatcher so users can call:

```solidity
exchangeIn(WETH, wethAmount, RICHIR, minRichirOut, recipient, pretransferred, deadline)
```

This provides a direct on-ramp from WETH to RICHIR via the standard interface.

## Background

Per the route inventory (`docs/reviews/2026-01-31_protocol-detf-route-inventory.md`):
- `wethToRichir()` is a custom function in BondingTarget
- Both input (WETH) and output (RICHIR) are ERC20 tokens
- High user demand for direct WETH → RICHIR conversion
- Essential for aggregator/router composability

## User Stories

### US-IDXEX-023.1: Standard Interface Access

As a router/aggregator, I want to convert WETH to RICHIR using the standard `exchangeIn()` interface so I can compose Protocol DETF routes with other protocols.

**Acceptance Criteria:**
- [x] `exchangeIn(WETH, *, RICHIR, ...)` routes to WETH→RICHIR conversion
- [x] `previewExchangeIn(WETH, *, RICHIR)` returns accurate estimate
- [x] Deadline protection works
- [x] Slippage protection works
- [x] `pretransferred` flag works for gas optimization

### US-IDXEX-023.2: Backward Compatibility

As an existing user, I want `wethToRichir()` to continue working so my existing integrations don't break.

**Acceptance Criteria:**
- [x] `wethToRichir()` still callable directly
- [x] Same behavior as before
- [x] Both entry points produce identical results

## Technical Details

### Implementation Approach

Similar to IDXEX-022, either delegate to existing function or move logic:

**Option A: Delegate**
```solidity
// In ProtocolDETFExchangeInTarget.sol
function _executeWethToRichir(...) internal returns (uint256) {
    return IProtocolDETFBonding(address(this)).wethToRichir(
        amountIn_, minAmountOut_, recipient_, deadline_
    );
}
```

**Option B: Move logic (Recommended)**
- Move implementation from BondingTarget to ExchangeInTarget
- Have `wethToRichir()` delegate to ExchangeInTarget version

### Route Detection

Add to `exchangeIn()` dispatcher:
```solidity
if (_isWethToken(layout_, tokenIn_) && _isRichirToken(tokenOut_)) {
    return _executeWethToRichir(amountIn_, minAmountOut_, recipient_, deadline_);
}
```

### Files to Modify

1. `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`
   - Add route detection in `exchangeIn()` dispatcher
   - Add `_executeWethToRichir()` implementation
   - Add preview logic in `previewExchangeIn()`

2. `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol`
   - Optionally refactor `wethToRichir()` to delegate

3. `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
   - Add test for `exchangeIn(WETH, *, RICHIR, ...)`

## Test Requirements

1. **test_exchangeIn_weth_to_richir_basic**
   - Convert WETH to RICHIR via exchangeIn
   - Verify RICHIR minted to recipient

2. **test_exchangeIn_weth_to_richir_preview**
   - Preview matches actual output within 5% tolerance (rebasing variance)

3. **test_exchangeIn_weth_to_richir_slippage**
   - Reverts when output < minAmountOut

4. **test_exchangeIn_weth_to_richir_deadline**
   - Reverts when deadline exceeded

5. **test_exchangeIn_weth_to_richir_parity**
   - exchangeIn produces same result as wethToRichir()

## Completion Criteria

- [x] `exchangeIn(WETH, *, RICHIR, ...)` works
- [x] `previewExchangeIn(WETH, *, RICHIR)` accurate
- [x] `wethToRichir()` still works (backward compatible)
- [x] All new tests pass
- [x] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`
