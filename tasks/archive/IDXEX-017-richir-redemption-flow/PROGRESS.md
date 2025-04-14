# Progress: IDXEX-017 - RICHIR Redemption Flow

## Status: Complete

## Session Log

### 2026-01-28 - Task Created

- Created task from user specification
- User clarified the exact ordering of operations
- Key insight: RICH recycling must happen BEFORE CHIR swap for optimal pricing

### 2026-01-28 - Interface Research Complete

Identified all required interfaces:

1. **Aerodrome Pool LP burn**: `IPool.burn(address to) returns (uint256 amount0, uint256 amount1)`
   - Transfer LP to pool, then call burn(recipient) to get both tokens proportionally

2. **Aerodrome Vault exchangeIn patterns**:
   - Vault shares → LP token: `vault.exchangeIn(vaultToken, amount, lpToken, minOut, recipient, false, deadline)`
   - Token → Vault shares: `vault.exchangeIn(token, amount, vaultToken, minOut, recipient, false, deadline)`
   - Vault shares → Token: `vault.exchangeIn(vaultToken, amount, token, minOut, recipient, false, deadline)`

3. **Balancer unbalanced deposit**: `prepayAddLiquidityUnbalanced` with `AddLiquidityKind.UNBALANCED`

4. **Protocol NFT BPT addition**: `IProtocolNFTVault.addToProtocolNFT(tokenId, lpAmount)`

### 2026-01-28 - Implementation Complete

Implemented the full 11-step RICHIR redemption flow in `ProtocolDETFExchangeInTarget.sol`:

1. ✅ Burn RICHIR (prevents reentrancy, ensures correct rate calculation)
2. ✅ Calculate BPT claim using proportional math
3. ✅ Exit reserve pool proportionally → vault shares
4. ✅ Redeem RICH/CHIR vault shares → LP tokens (`_redeemRichChirVaultToLP`)
5. ✅ Burn LP → RICH + CHIR (`_burnRichChirLP`)
6. ✅ Deposit RICH → RICH/CHIR vault shares (`_depositRichToRichChirVault`)
7. ✅ Unbalanced deposit to reserve pool → BPT (`_unbalancedDepositAndAddToProtocolNFT`)
8. ✅ Add BPT to Protocol NFT (`_unbalancedDepositAndAddToProtocolNFT`)
9. ✅ Swap CHIR → WETH (max liquidity for best price)
10. ✅ Redeem CHIR/WETH vault shares → WETH
11. ✅ Send WETH to user

**New functions added:**
- `_exitRecycleAndUnwindToWeth` - Main entry point for steps 3-10
- `_recycleRichToReservePool` - Steps 4-8 (RICH recycling)
- `_redeemRichChirVaultToLP` - Step 4
- `_burnRichChirLP` - Step 5
- `_depositRichToRichChirVault` - Step 6
- `_unbalancedDepositAndAddToProtocolNFT` - Steps 7-8

**Design rationale:**
- RICH recycling (steps 4-8) ensures RICHIR never runs short of BPT
- CHIR swap (step 9) happens while maximum liquidity is present for optimal pricing
- RICHIR burned first to maintain secure accounting state

**Tests:**
All 69 Protocol DETF tests pass including `test_route_richir_to_weth`.

### Blockers

None.

### Acceptance Criteria

- [x] RICHIR redemption follows the 11-step flow exactly
- [x] RICH is always recycled back into the reserve pool
- [x] Protocol NFT always retains BPT after redemption
- [x] CHIR swap happens while maximum liquidity is present
- [x] All existing tests pass (69/69)
