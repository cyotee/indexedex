# Task IDXEX-021: Implement WETH → RICHIR Single-Call Wrapper

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-28
**Type:** Feature
**Dependencies:** None
**Worktree:** `feature/weth-richir-wrapper`

---

## Description

Currently, converting WETH to RICHIR requires two separate transactions:
1. `bondWithWeth()` → get Bond NFT
2. `sellNFT()` → get RICHIR

Per the checklist, a single-call wrapper should exist for WETH → RICHIR that combines these steps atomically. This improves UX and reduces gas costs for users who want direct RICHIR exposure without holding a Bond NFT.

## Background

The intended flow for WETH → RICHIR:
1. Deposit WETH into CHIR/WETH vault → get vault shares
2. Unbalanced deposit vault shares to reserve pool → get BPT
3. Credit BPT to protocol-owned NFT
4. Mint RICHIR shares to user

This is equivalent to bonding + immediate sell, but without creating/burning a user NFT.

## User Stories

### US-IDXEX-021.1: Direct WETH → RICHIR Conversion

As a WETH holder, I want to convert my WETH directly to RICHIR in a single transaction without needing to create and sell a Bond NFT.

**Acceptance Criteria:**
- [ ] Single function call converts WETH to RICHIR
- [ ] No intermediate Bond NFT created for user
- [ ] BPT goes directly to protocol-owned NFT
- [ ] RICHIR minted directly to recipient
- [ ] Deadline protection
- [ ] Minimum output protection

### US-IDXEX-021.2: Preview WETH → RICHIR

As a user, I want to preview how much RICHIR I'll receive for a given WETH amount.

**Acceptance Criteria:**
- [ ] `previewWethToRichir(wethAmount)` returns expected RICHIR
- [ ] Accounts for vault share rates and pool math

## Technical Details

### Implementation

Add to `ProtocolDETFBondingTarget.sol`:

```solidity
function wethToRichir(
    uint256 wethIn,
    uint256 minRichirOut,
    address recipient,
    uint256 deadline
) external lock returns (uint256 richirOut) {
    if (block.timestamp > deadline) revert DeadlineExceeded(deadline, block.timestamp);
    if (wethIn == 0) revert ZeroAmount();
    if (recipient == address(0)) recipient = msg.sender;

    ProtocolDETFRepo.Storage storage layout = ProtocolDETFRepo._layout();
    if (!_isInitialized()) revert ReservePoolNotInitialized();

    // Transfer WETH from user
    layout.wethToken.safeTransferFrom(msg.sender, address(this), wethIn);

    // Deposit WETH into CHIR/WETH vault → vault shares
    layout.wethToken.safeTransfer(address(layout.chirWethVault), wethIn);
    uint256 chirWethShares = layout.chirWethVault.exchangeIn(
        layout.wethToken,
        wethIn,
        IERC20(address(layout.chirWethVault)),
        0,
        address(this),
        true,
        deadline
    );

    // Add vault shares to reserve pool → BPT
    uint256 bptOut = _addToReservePool(layout, layout.chirWethVaultIndex, chirWethShares, deadline);

    // Add BPT directly to protocol-owned NFT (no user NFT)
    IERC20(address(_reservePool())).forceApprove(address(layout.protocolNFTVault), bptOut);
    layout.protocolNFTVault.addToProtocolNFT(layout.protocolNFTId, bptOut);

    // Mint RICHIR to recipient (1:1 with BPT)
    richirOut = layout.richirToken.mintFromNFTSale(bptOut, recipient);

    if (richirOut < minRichirOut) {
        revert SlippageExceeded(minRichirOut, richirOut);
    }
}
```

### Preview Function

```solidity
function previewWethToRichir(uint256 wethIn) external view returns (uint256 richirOut) {
    ProtocolDETFRepo.Storage storage layout = ProtocolDETFRepo._layout();

    // Preview vault share output
    uint256 vaultShares = layout.chirWethVault.previewExchangeIn(
        layout.wethToken,
        wethIn,
        IERC20(address(layout.chirWethVault))
    );

    // Preview BPT output from unbalanced deposit
    // ... (use Balancer math)

    // RICHIR is 1:1 with BPT added to protocol NFT
    richirOut = bptOut;
}
```

## Files to Modify

**Modified Files:**
- `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol` - Add `wethToRichir()` and `previewWethToRichir()`
- `contracts/interfaces/IProtocolDETF.sol` - Add interface declarations

**Tests:**
- `test/foundry/spec/vaults/protocol/ProtocolDETF_WethToRichir.t.sol`

## Test Requirements

1. **test_wethToRichir_success**
   - Convert WETH to RICHIR
   - Verify no user NFT created
   - Verify RICHIR minted to recipient

2. **test_wethToRichir_slippage**
   - Verify reverts if output < minRichirOut

3. **test_previewWethToRichir**
   - Preview matches actual output

## Completion Criteria

- [ ] Single-call WETH → RICHIR conversion works
- [ ] No intermediate user NFT created
- [ ] Slippage and deadline protection
- [ ] All tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
