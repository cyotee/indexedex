# Task IDXEX-018: Fix Protocol DETF Donation Flow

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-28
**Type:** Bug Fix
**Dependencies:** None
**Worktree:** `feature/fix-donation-flow`

---

## Description

The `donate()` function in `ProtocolDETFBondingTarget.sol` has multiple bugs discovered during the IDXEX-001 code review. WETH donations don't properly deposit vault shares into the Balancer reserve pool to get BPT, and CHIR donations are transferred to the NFT vault instead of being burned. Additionally, the interface signature doesn't match the implementation.

## Background

The donation flow is used by the FeeCollector to route protocol fees back into the reserve backing. Proper functioning is critical for maintaining protocol value.

**Interface specification (IProtocolDETF.sol lines 217-218):**
- WETH: Single-sided deposit to CHIR/WETH vault, unbalanced to reserve
- CHIR: Simply burned

## Issues Found

### Issue 1: WETH Donation Missing Reserve Pool Deposit (HIGH)

**Current behavior:**
1. WETH transferred to CHIR/WETH vault
2. `exchangeIn` deposits WETH, vault shares sent to protocolNFTVault
3. `addToProtocolNFT` called with vault shares

**Problem:** Vault shares are never deposited into the Balancer 80/20 reserve pool. The `addToProtocolNFT` expects BPT (reserve pool LP tokens), not vault shares.

**Expected behavior:**
1. WETH transferred to CHIR/WETH vault
2. `exchangeIn` deposits WETH, vault shares received by CHIR contract
3. Vault shares deposited into Balancer reserve pool via unbalanced deposit
4. BPT received and added to protocol NFT via `addToProtocolNFT`

### Issue 2: CHIR Donation Not Burned (HIGH)

**Current behavior (lines 636-639):**
```solidity
} else {
    // CHIR goes directly to protocol NFT vault
    token.safeTransfer(address(layout.protocolNFTVault), amount);
}
```

**Problem:** CHIR is transferred to the NFT vault instead of being burned.

**Expected behavior:** CHIR should be burned via `ERC20Repo._burn()` to reduce supply.

### Issue 3: Interface Parameter Mismatch (MEDIUM)

**Interface (IProtocolDETF.sol):**
```solidity
function donate(IERC20 token, uint256 amount, bool pretransferred) external;
```

**Implementation:**
```solidity
function donate(IERC20 token, uint256 amount) external lock {
```

The `pretransferred` parameter is missing from the implementation.

## User Stories

### US-IDXEX-018.1: Fix WETH Donation Flow

As the FeeCollector contract, I want to donate WETH to the protocol so that the value is properly added to the reserve pool backing.

**Acceptance Criteria:**
- [ ] WETH is deposited into CHIR/WETH vault to receive vault shares
- [ ] Vault shares are deposited into Balancer 80/20 reserve pool via unbalanced deposit
- [ ] BPT received from reserve pool deposit
- [ ] BPT added to protocol NFT position via `addToProtocolNFT`
- [ ] No CHIR is minted during this process

### US-IDXEX-018.2: Fix CHIR Donation Flow

As the FeeCollector contract, I want to donate CHIR to the protocol so that the CHIR supply is reduced (burned).

**Acceptance Criteria:**
- [ ] CHIR is burned via `ERC20Repo._burn()`
- [ ] CHIR supply decreases by the donated amount
- [ ] CHIR is NOT transferred to the NFT vault or any other address

### US-IDXEX-018.3: Fix Interface Signature

As a developer, I want the interface and implementation to match so that the contract compiles correctly and callers use the correct signature.

**Acceptance Criteria:**
- [ ] Implementation includes `pretransferred` parameter
- [ ] If `pretransferred=true`, tokens are assumed already in the contract
- [ ] If `pretransferred=false`, tokens are transferred from `msg.sender`

## Technical Details

### WETH Donation Implementation

Reference the existing `_addToReservePool` helper (lines 653-698) which already handles single-sided deposits to the reserve pool. The flow should be:

```solidity
if (_isWethToken(layout, token)) {
    // 1. Transfer WETH (or use pretransferred)
    if (!pretransferred) {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    // 2. Deposit WETH into CHIR/WETH vault
    token.safeTransfer(address(layout.chirWethVault), amount);
    uint256 vaultShares = layout.chirWethVault.exchangeIn(
        token,
        amount,
        IERC20(address(layout.chirWethVault)),
        0,
        address(this),  // Shares come to this contract, not NFT vault
        true,
        block.timestamp
    );

    // 3. Add vault shares to reserve pool (get BPT)
    uint256 bptOut = _addToReservePool(
        layout,
        layout.chirWethVaultIndex,
        vaultShares,
        block.timestamp
    );

    // 4. Add BPT to protocol NFT
    IERC20(address(_reservePool())).forceApprove(address(layout.protocolNFTVault), bptOut);
    layout.protocolNFTVault.addToProtocolNFT(layout.protocolNFTId, bptOut);
}
```

### CHIR Donation Implementation

```solidity
} else {
    // CHIR: burn to reduce supply
    if (!pretransferred) {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }
    ERC20Repo._burn(address(this), amount);
}
```

## Files to Modify

**Modified Files:**
- `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol` - Fix `donate()` function (lines 604-640)
- `contracts/interfaces/IProtocolDETF.sol` - Already has correct signature (verify)

**Tests to Add/Modify:**
- `test/foundry/spec/vaults/protocol/ProtocolDETFDonation.t.sol` - Add donation flow tests

## Test Requirements

1. **test_donate_weth_adds_to_reserve_pool**
   - Donate WETH
   - Verify BPT balance of protocol NFT increases
   - Verify no CHIR minted
   - Verify WETH balance decreases from donor

2. **test_donate_chir_burns_supply**
   - Donate CHIR
   - Verify CHIR totalSupply decreases
   - Verify CHIR not transferred to NFT vault or anywhere else

3. **test_donate_weth_pretransferred**
   - Transfer WETH to contract first
   - Call donate with pretransferred=true
   - Verify works correctly

4. **test_donate_chir_pretransferred**
   - Transfer CHIR to contract first
   - Call donate with pretransferred=true
   - Verify CHIR burned

5. **test_donate_reverts_invalid_token**
   - Try to donate RICH or other token
   - Verify reverts with InvalidDonationToken

## Completion Criteria

- [ ] WETH donations deposit to reserve pool and add BPT to protocol NFT
- [ ] CHIR donations are burned
- [ ] Interface signature matches implementation
- [ ] All new tests pass
- [ ] Existing Protocol DETF tests still pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
