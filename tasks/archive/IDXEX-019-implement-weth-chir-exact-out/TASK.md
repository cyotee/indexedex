# Task IDXEX-019: Implement WETH → CHIR Exact-Out Exchange

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-28
**Type:** Feature
**Dependencies:** None
**Worktree:** `feature/weth-chir-exact-out`

---

## Description

The `exchangeOut` function in `ProtocolDETFExchangeOutTarget.sol` currently reverts with `ExchangeOutNotAvailable()` for all routes. Per the checklist review, WETH → CHIR exact-out SHOULD be implemented since there IS a gas-efficient way to calculate the required WETH input for a desired CHIR output.

Only block `exchangeOut` when there's no gas-efficient way to calculate amount-in (e.g., ZapIn to target LP amount). For WETH → CHIR minting, the calculation is straightforward.

## Background

**Current behavior:**
```solidity
function previewExchangeOut(...) external pure returns (uint256) {
    revert ExchangeOutNotAvailable();  // Always reverts
}

function exchangeOut(...) external lock returns (uint256) {
    revert ExchangeOutNotAvailable();  // Always reverts
}
```

**Dead code exists** in `_executeMintExactChir` (lines 103-155) but has **incorrect rounding** - uses floor division when it should round UP for the amount-in calculation.

## User Stories

### US-IDXEX-019.1: Preview Exact-Out WETH → CHIR

As a user, I want to preview how much WETH I need to provide to receive an exact amount of CHIR.

**Acceptance Criteria:**
- [ ] `previewExchangeOut(WETH, CHIR, exactChirAmount)` returns required WETH
- [ ] Calculation accounts for synthetic price and seigniorage
- [ ] Amount rounds UP (user provides more, vault-favorable)
- [ ] Reverts if minting not allowed (syntheticPrice <= mintThreshold)

### US-IDXEX-019.2: Execute Exact-Out WETH → CHIR

As a user, I want to exchange WETH for an exact amount of CHIR.

**Acceptance Criteria:**
- [ ] `exchangeOut(WETH, maxWethIn, CHIR, exactChirOut, recipient, pretransferred, deadline)` works
- [ ] Minting gated by `syntheticPrice > mintThreshold`
- [ ] User receives exactly `exactChirOut` CHIR
- [ ] User provides at most `maxWethIn` WETH
- [ ] Excess WETH refunded if pretransferred
- [ ] Seigniorage captured to protocol NFT

## Technical Details

### Correct Rounding for Exact-Out

The current dead code uses:
```solidity
amountIn_ = (p_.amountOut * p_.syntheticPrice) / ONE_WAD;  // WRONG - rounds DOWN
```

Should be:
```solidity
amountIn_ = BetterMath._mulDivUp(p_.amountOut, p_.syntheticPrice, ONE_WAD);  // Rounds UP
```

### Implementation Flow

1. Calculate base WETH required for exact CHIR (using mulDivUp)
2. Check slippage: `amountIn <= maxAmountIn`
3. Transfer WETH (or use pretransferred)
4. Calculate seigniorage from actual WETH in
5. Deposit WETH to CHIR/WETH vault
6. Mint seigniorage to protocol NFT
7. Mint exact CHIR to recipient
8. Refund excess WETH if pretransferred

## Files to Modify

**Modified Files:**
- `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol` - Enable WETH → CHIR route

**Tests:**
- `test/foundry/spec/vaults/protocol/ProtocolDETFExchangeOut.t.sol` - Add exact-out tests

## Test Requirements

1. **test_previewExchangeOut_weth_chir**
   - Preview exact CHIR output
   - Verify WETH amount rounds up

2. **test_exchangeOut_weth_chir_success**
   - Execute exact-out exchange
   - Verify user receives exact CHIR
   - Verify seigniorage captured

3. **test_exchangeOut_weth_chir_slippage**
   - Verify reverts if required WETH > maxAmountIn

4. **test_exchangeOut_weth_chir_minting_not_allowed**
   - Verify reverts when syntheticPrice <= mintThreshold

## Completion Criteria

- [ ] previewExchangeOut returns correct WETH for exact CHIR
- [ ] exchangeOut mints exact CHIR amount
- [ ] Rounding favors vault (UP for inputs)
- [ ] All tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
