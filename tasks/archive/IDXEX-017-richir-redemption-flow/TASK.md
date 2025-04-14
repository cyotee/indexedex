# Task IDXEX-017: Implement Correct RICHIR Redemption Flow

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-28
**Type:** Implementation
**Dependencies:** IDXEX-001 (spec reference)
**Worktree:** N/A

---

## Description

Redesign `_executeRichirRedemption` in `ProtocolDETFExchangeInTarget.sol` to implement the correct token flow as specified in IDXEX-001.

## Intended Flow (Canonical)

The order is critical for security and optimal pricing:

1. **Burn RICHIR** - Done first to maintain secure state
2. **Calculate user claim** - Convert RICHIR shares to BPT amount using proportional math:
   - `bptIn = (richirShares / totalRichirShares) * protocolNftBpt`
3. **Proportional exit from reserve pool** - Get CHIR/WETH vault shares and RICH/CHIR vault shares
4. **Redeem RICH/CHIR vault shares for LP tokens** - Call `exchangeIn` on RICH/CHIR vault with vault token as tokenIn, LP token as tokenOut
5. **Burn RICH/CHIR LP tokens** - Proportional withdrawal to get RICH and CHIR
6. **Deposit RICH into RICH/CHIR vault** - Call `exchangeIn` with RICH as tokenIn, vault token as tokenOut
7. **Unbalanced deposit to reserve pool** - Deposit new RICH/CHIR vault shares
8. **Add new BPT to Protocol NFT** - Assign resulting BPT back to RICHIR-owned position
9. **Swap CHIR for WETH** - Call `exchangeIn` on CHIR/WETH vault with CHIR as tokenIn, WETH as tokenOut
10. **Redeem CHIR/WETH vault shares for WETH** - Call `exchangeIn` with vault token as tokenIn, WETH as tokenOut
11. **Send all WETH to user**

## Design Rationale

### Why recycle RICH before swapping CHIR (steps 6-8 before 9-10)?

1. **RICHIR never runs short of BPT** - By withdrawing RICH and CHIR, then redepositing RICH, the protocol always retains BPT backing
2. **Better CHIR→WETH pricing** - By swapping CHIR before redeeming CHIR/WETH vault shares, maximum liquidity is present in the pool for the swap, getting best price
3. **CHIR recapture** - More liquidity means we recapture more value when swapping

### Why burn RICHIR first?

- Prevents reentrancy issues
- Ensures rate calculations are based on pre-exit state
- Maintains secure accounting

## Files to Modify

- `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`
  - `_executeRichirRedemption()` - Main function to rewrite
  - Add helper functions as needed for each step

## Interfaces Required

The following vault operations are needed:

```solidity
// Step 4: Vault token → LP token
richChirVault.exchangeIn(vaultToken, amount, lpToken, minOut, recipient, false, deadline);

// Step 5: LP burn (Aerodrome router)
aerodromeRouter.removeLiquidity(tokenA, tokenB, stable, liquidity, minA, minB, to, deadline);

// Step 6: RICH → Vault token
richChirVault.exchangeIn(richToken, amount, vaultToken, minOut, recipient, false, deadline);

// Step 7: Unbalanced deposit to Balancer pool
// (need to verify exact Balancer V3 interface)

// Step 8: Add BPT to NFT
// (need to verify Protocol NFT Vault interface)

// Step 9: CHIR → WETH
chirWethVault.exchangeIn(chirToken, amount, wethToken, minOut, recipient, false, deadline);

// Step 10: Vault token → WETH
chirWethVault.exchangeIn(vaultToken, amount, wethToken, minOut, recipient, false, deadline);
```

## Acceptance Criteria

- [ ] RICHIR redemption follows the 11-step flow exactly
- [ ] RICH is always recycled back into the reserve pool
- [ ] Protocol NFT always retains BPT after redemption
- [ ] CHIR swap happens while maximum liquidity is present
- [ ] All existing tests pass
- [ ] New tests verify the flow steps

## Testing

- [ ] Unit test: Each step in isolation
- [ ] Integration test: Full flow end-to-end
- [ ] Verify BPT is added back to Protocol NFT
- [ ] Verify WETH output is correct

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
