# Task IDXEX-022: Wire richToRichir() into exchangeIn() Dispatcher

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-31
**Type:** Refactor
**Dependencies:** IDXEX-020
**Worktree:** `feature/rich-richir-exchangein`

---

## Description

The `richToRichir()` function already exists in `ProtocolDETFBondingTarget.sol` but is not accessible via the standard `IStandardExchangeIn` interface. This task wires the existing functionality into the `exchangeIn()` dispatcher so users can call:

```solidity
exchangeIn(RICH, richAmount, RICHIR, minRichirOut, recipient, pretransferred, deadline)
```

This improves composability with routers and aggregators that use the Standard Exchange interface pattern.

## Background

Per the route inventory (`docs/reviews/2026-01-31_protocol-detf-route-inventory.md`):
- `richToRichir()` is a custom function in BondingTarget
- Both input (RICH) and output (RICHIR) are ERC20 tokens
- No special parameters beyond standard interface requirements
- Perfect candidate for Standard Exchange interface integration

## User Stories

### US-IDXEX-022.1: Standard Interface Access

As a router/aggregator, I want to convert RICH to RICHIR using the standard `exchangeIn()` interface so I can compose Protocol DETF routes with other protocols.

**Acceptance Criteria:**
- [ ] `exchangeIn(RICH, *, RICHIR, ...)` routes to RICH→RICHIR conversion
- [ ] `previewExchangeIn(RICH, *, RICHIR)` returns accurate estimate
- [ ] Deadline protection works
- [ ] Slippage protection works
- [ ] `pretransferred` flag works for gas optimization

### US-IDXEX-022.2: Backward Compatibility

As an existing user, I want `richToRichir()` to continue working so my existing integrations don't break.

**Acceptance Criteria:**
- [ ] `richToRichir()` still callable directly
- [ ] Same behavior as before
- [ ] Both entry points produce identical results

## Technical Details

### Implementation Approach

**Option A: Delegate to existing function**
```solidity
// In ProtocolDETFExchangeInTarget.sol
function _executeRichToRichir(...) internal returns (uint256) {
    // Call the existing richToRichir implementation
    return IProtocolDETFBonding(address(this)).richToRichir(
        amountIn_, minAmountOut_, recipient_, deadline_
    );
}
```

**Option B: Move logic to ExchangeInTarget**
- Move the implementation from BondingTarget to ExchangeInTarget
- Have `richToRichir()` call the ExchangeInTarget version
- Avoids cross-facet call overhead

**Recommendation:** Option B for cleaner architecture.

### Files to Modify

1. `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`
   - Add route detection in `exchangeIn()` dispatcher
   - Add `_executeRichToRichir()` implementation
   - Add preview logic in `previewExchangeIn()`
   - Add `_isRichirToken()` helper if not exists

2. `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol`
   - Optionally refactor `richToRichir()` to delegate to ExchangeInTarget

3. `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
   - Add test for `exchangeIn(RICH, *, RICHIR, ...)`
   - Verify parity with direct `richToRichir()` call

## Test Requirements

1. **test_exchangeIn_rich_to_richir_basic**
   - Convert RICH to RICHIR via exchangeIn
   - Verify RICHIR minted to recipient
   - Verify RICH deducted from sender

2. **test_exchangeIn_rich_to_richir_preview**
   - Preview matches actual output within tolerance

3. **test_exchangeIn_rich_to_richir_slippage**
   - Reverts when output < minAmountOut

4. **test_exchangeIn_rich_to_richir_deadline**
   - Reverts when deadline exceeded

5. **test_exchangeIn_rich_to_richir_pretransferred**
   - Works with pretransferred=true

6. **test_exchangeIn_rich_to_richir_parity**
   - exchangeIn produces same result as richToRichir()

## Completion Criteria

- [x] `exchangeIn(RICH, *, RICHIR, ...)` works
- [x] `previewExchangeIn(RICH, *, RICHIR)` accurate
- [x] `richToRichir()` still works (backward compatible)
- [x] All new tests pass
- [x] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`
