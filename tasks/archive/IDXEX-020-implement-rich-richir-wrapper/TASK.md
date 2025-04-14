# Task IDXEX-020: Implement RICH → RICHIR Single-Call Wrapper

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-28
**Type:** Feature
**Dependencies:** None
**Worktree:** `feature/rich-richir-wrapper`

---

## Description

Currently, converting RICH to RICHIR requires two separate transactions:
1. `bondWithRich()` → get Bond NFT
2. `sellNFT()` → get RICHIR

Per the checklist, a single-call wrapper should exist for RICH → RICHIR that combines these steps atomically. This improves UX and reduces gas costs for users who want direct RICHIR exposure without holding a Bond NFT.

## Background

The intended flow for RICH → RICHIR:
1. Deposit RICH into RICH/CHIR vault → get vault shares
2. Unbalanced deposit vault shares to reserve pool → get BPT
3. Credit BPT to protocol-owned NFT
4. Mint RICHIR shares to user

This is equivalent to bonding + immediate sell, but without creating/burning a user NFT.

## User Stories

### US-IDXEX-020.1: Direct RICH → RICHIR Conversion

As a RICH holder, I want to convert my RICH directly to RICHIR in a single transaction without needing to create and sell a Bond NFT.

**Acceptance Criteria:**
- [ ] Single function call converts RICH to RICHIR
- [ ] No intermediate Bond NFT created for user
- [ ] BPT goes directly to protocol-owned NFT
- [ ] RICHIR minted directly to recipient
- [ ] Deadline protection
- [ ] Minimum output protection

### US-IDXEX-020.2: Preview RICH → RICHIR

As a user, I want to preview how much RICHIR I'll receive for a given RICH amount.

**Acceptance Criteria:**
- [ ] `previewRichToRichir(richAmount)` returns expected RICHIR
- [ ] Accounts for vault share rates and pool math

## Technical Details

### Implementation

Add to `ProtocolDETFBondingTarget.sol`:

```solidity
function richToRichir(
    uint256 richIn,
    uint256 minRichirOut,
    address recipient,
    uint256 deadline
) external lock returns (uint256 richirOut) {
    if (block.timestamp > deadline) revert DeadlineExceeded(deadline, block.timestamp);
    if (richIn == 0) revert ZeroAmount();
    if (recipient == address(0)) recipient = msg.sender;

    ProtocolDETFRepo.Storage storage layout = ProtocolDETFRepo._layout();
    if (!_isInitialized()) revert ReservePoolNotInitialized();

    // Transfer RICH from user
    layout.richToken.safeTransferFrom(msg.sender, address(this), richIn);

    // Deposit RICH into RICH/CHIR vault → vault shares
    layout.richToken.safeTransfer(address(layout.richChirVault), richIn);
    uint256 richChirShares = layout.richChirVault.exchangeIn(
        layout.richToken,
        richIn,
        IERC20(address(layout.richChirVault)),
        0,
        address(this),
        true,
        deadline
    );

    // Add vault shares to reserve pool → BPT
    uint256 bptOut = _addToReservePool(layout, layout.richChirVaultIndex, richChirShares, deadline);

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
function previewRichToRichir(uint256 richIn) external view returns (uint256 richirOut) {
    ProtocolDETFRepo.Storage storage layout = ProtocolDETFRepo._layout();

    // Preview vault share output
    uint256 vaultShares = layout.richChirVault.previewExchangeIn(
        layout.richToken,
        richIn,
        IERC20(address(layout.richChirVault))
    );

    // Preview BPT output from unbalanced deposit
    // ... (use Balancer math)

    // RICHIR is 1:1 with BPT added to protocol NFT
    richirOut = bptOut;
}
```

## Files to Modify

**Modified Files:**
- `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol` - Add `richToRichir()` and `previewRichToRichir()`
- `contracts/interfaces/IProtocolDETF.sol` - Add interface declarations

**Tests:**
- `test/foundry/spec/vaults/protocol/ProtocolDETF_RichToRichir.t.sol`

## Test Requirements

1. **test_richToRichir_success**
   - Convert RICH to RICHIR
   - Verify no user NFT created
   - Verify RICHIR minted to recipient

2. **test_richToRichir_slippage**
   - Verify reverts if output < minRichirOut

3. **test_previewRichToRichir**
   - Preview matches actual output

## Completion Criteria

- [ ] Single-call RICH → RICHIR conversion works
- [ ] No intermediate user NFT created
- [ ] Slippage and deadline protection
- [ ] All tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
