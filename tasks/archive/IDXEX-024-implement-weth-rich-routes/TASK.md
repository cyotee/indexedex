# Task IDXEX-024: Implement WETH ↔ RICH Routes

**Repo:** IndexedEx
**Status:** Complete
**Created:** 2026-01-31
**Type:** Feature
**Dependencies:** None
**Worktree:** `feature/weth-rich-routes`

---

## Description

Add bidirectional WETH ↔ RICH conversion routes to the Protocol DETF. Currently, users must go through CHIR as an intermediate step. Direct routes improve UX and potentially save gas.

**New Routes:**
1. WETH → RICH: Buy RICH with WETH
2. RICH → WETH: Sell RICH for WETH

Both routes will be accessible via the standard `IStandardExchangeIn` interface.

## Background

Per the route inventory (`docs/reviews/2026-01-31_protocol-detf-route-inventory.md`):
- WETH → RICH and RICH → WETH are missing routes
- High priority for user convenience
- Multi-hop internally but single-call for users

## User Stories

### US-IDXEX-024.1: Buy RICH with WETH

As a WETH holder, I want to buy RICH directly without manually routing through CHIR.

**Acceptance Criteria:**
- [x] `exchangeIn(WETH, *, RICH, ...)` converts WETH to RICH
- [x] `previewExchangeIn(WETH, *, RICH)` returns accurate estimate
- [x] Slippage and deadline protection
- [x] Single transaction

### US-IDXEX-024.2: Sell RICH for WETH

As a RICH holder, I want to sell RICH for WETH directly without manually routing through CHIR.

**Acceptance Criteria:**
- [x] `exchangeIn(RICH, *, WETH, ...)` converts RICH to WETH
- [x] `previewExchangeIn(RICH, *, WETH)` returns accurate estimate
- [x] Slippage and deadline protection
- [x] Single transaction

## Technical Details

### WETH → RICH Route

**Flow:**
1. Transfer WETH from user
2. Deposit WETH into CHIR/WETH vault → get CHIR
3. Deposit CHIR into RICH/CHIR vault → get RICH
4. Transfer RICH to recipient

```solidity
function _executeWethToRich(
    uint256 wethIn,
    uint256 minRichOut,
    address recipient,
    uint256 deadline
) internal returns (uint256 richOut) {
    ProtocolDETFRepo.Storage storage layout = ProtocolDETFRepo._layout();

    // 1. WETH → CHIR via chirWethVault
    layout.wethToken.safeTransfer(address(layout.chirWethVault), wethIn);
    uint256 chirOut = layout.chirWethVault.exchangeIn(
        layout.wethToken,
        wethIn,
        IERC20(address(this)), // CHIR
        0,
        address(this),
        true,
        deadline
    );

    // 2. CHIR → RICH via richChirVault
    IERC20(address(this)).safeTransfer(address(layout.richChirVault), chirOut);
    richOut = layout.richChirVault.exchangeIn(
        IERC20(address(this)), // CHIR
        chirOut,
        layout.richToken,
        minRichOut,
        recipient,
        true,
        deadline
    );
}
```

### RICH → WETH Route

**Flow:**
1. Transfer RICH from user
2. Deposit RICH into RICH/CHIR vault → get CHIR
3. Withdraw CHIR from CHIR/WETH vault → get WETH
4. Transfer WETH to recipient

```solidity
function _executeRichToWeth(
    uint256 richIn,
    uint256 minWethOut,
    address recipient,
    uint256 deadline
) internal returns (uint256 wethOut) {
    ProtocolDETFRepo.Storage storage layout = ProtocolDETFRepo._layout();

    // 1. RICH → CHIR via richChirVault
    layout.richToken.safeTransfer(address(layout.richChirVault), richIn);
    uint256 chirOut = layout.richChirVault.exchangeIn(
        layout.richToken,
        richIn,
        IERC20(address(this)), // CHIR
        0,
        address(this),
        true,
        deadline
    );

    // 2. CHIR → WETH via chirWethVault
    IERC20(address(this)).safeTransfer(address(layout.chirWethVault), chirOut);
    wethOut = layout.chirWethVault.exchangeIn(
        IERC20(address(this)), // CHIR
        chirOut,
        layout.wethToken,
        minWethOut,
        recipient,
        true,
        deadline
    );
}
```

### Files to Modify

1. `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`
   - Add `_executeWethToRich()` implementation
   - Add `_executeRichToWeth()` implementation
   - Add route detection in `exchangeIn()` dispatcher
   - Add preview logic in `previewExchangeIn()`

2. `contracts/interfaces/IProtocolDETF.sol`
   - Document new supported routes

3. `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
   - Add tests for both routes

## Test Requirements

### WETH → RICH Tests

1. **test_exchangeIn_weth_to_rich_basic**
   - Convert WETH to RICH
   - Verify RICH received by recipient

2. **test_exchangeIn_weth_to_rich_preview**
   - Preview matches actual within tolerance

3. **test_exchangeIn_weth_to_rich_slippage**
   - Reverts when output < minAmountOut

### RICH → WETH Tests

4. **test_exchangeIn_rich_to_weth_basic**
   - Convert RICH to WETH
   - Verify WETH received by recipient

5. **test_exchangeIn_rich_to_weth_preview**
   - Preview matches actual within tolerance

6. **test_exchangeIn_rich_to_weth_slippage**
   - Reverts when output < minAmountOut

## Completion Criteria

- [x] `exchangeIn(WETH, *, RICH, ...)` works
- [x] `exchangeIn(RICH, *, WETH, ...)` works
- [x] Both preview functions accurate
- [x] Slippage protection for both routes
- [x] All tests pass
- [x] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`
