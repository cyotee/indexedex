# Protocol DETF (RICHIR/RICH Exchange) Codebase Analysis Report

**Date**: 2026-03-27
**Repository**: contracts/vaults/protocol/
**Status**: Analysis Complete

---

## Executive Summary

The protocol implements a seigniorage-style DeFi vault system with three main tokens:
- **CHIR**: The synthetic token (protocol's "stablecoin")
- **RICH**: Static supply reward token
- **RICHIR**: Rebasing redemption token representing reserve pool shares

**Critical Finding**: The previous agent conflated two distinct workflows:
1. **RICHIR → RICH exchange route** (whitelisted, local redemption)
2. **sellNFT workflow** (selling bond NFTs for RICHIR)

The RICHIR→RICH exchange route exists in `BaseProtocolDETFExchangeInTarget.sol` but is **missing** from `EthereumProtocolDETFExchangeInTarget.sol`.

---

## System Architecture

### Token Relationships

```
    ┌─────────────────────────────────────────┐
    │          Reserve Pool (80/20)           │
    │  ┌─────────────┐     ┌─────────────┐    │
    │  │ CHIR/WETH   │     │ RICH/CHIR   │    │
    │  │   Vault     │     │   Vault     │    │
    │  │   (80%)     │     │   (20%)     │    │
    │  └─────────────┘     └─────────────┘    │
    └─────────────────────────────────────────┘
                ↑                ↑
      ┌─────────┴────────────────┴────────┐
      │              BPT                  │
      │    (Balancer Pool Tokens)         │
      └───────────────────────────────────┘
                ↑                ↑
      ┌─────────┴────────────────┴────────┐
      │     Protocol NFT Vault (80/20)    │
      │  ┌─────────────────────────────┐  │
      │  │   Protocol-owned Position   │  │
      │  │   (holds BPT for RICHIR)    │  │
      │  └─────────────────────────────┘  │
      └───────────────────────────────────┘
                ↑                ↑
      ┌─────────┴────────────────┴───────┐
      │              RICHIR              │
      │  (Rebasing token, 1:1 with BPT)  │
      └────────────────────────────-─────┘
```

### Supported Exchange Routes (via `exchangeIn`)

| Route | File | Status | Access Control |
|-------|------|--------|----------------|
| WETH → CHIR | BaseProtocolDETFExchangeInTarget | ✅ Implemented | Price gate (mintThreshold) |
| CHIR → WETH | BaseProtocolDETFExchangeInTarget | ✅ Implemented | Price gate (burnThreshold) |
| RICH → CHIR | BaseProtocolDETFExchangeInTarget | ✅ Implemented | Price gate |
| RICHIR → WETH | BaseProtocolDETFExchangeInTarget | ✅ Implemented | None (unconstrained) |
| RICH → RICHIR | BaseProtocolDETFExchangeInTarget | ✅ Implemented | None |
| WETH → RICHIR | BaseProtocolDETFExchangeInTarget | ✅ Implemented | None |
| WETH → RICH | BaseProtocolDETFExchangeInTarget | ✅ Implemented | None |
| RICH → WETH | BaseProtocolDETFExchangeInTarget | ✅ Implemented | None |
| **RICHIR → RICH** | **BaseProtocolDETFExchangeInTarget** | **✅ Implemented** | **allowedRichirRedeemAddresses** |
| RICHIR → RICH | EthereumProtocolDETFExchangeInTarget | ❌ **MISSING** | N/A |

---

## The Problem: Missing Route in Ethereum Variant

### File Comparison

**`BaseProtocolDETFExchangeInTarget.sol`** (lines 186-191):
```solidity
/* ---------------------------------------------------------------------- */
/*                      RICHIR → RICH (Local Redeem)                   */
/* ---------------------------------------------------------------------- */

if (_isRichirToken(layout, tokenIn) && _isRichToken(layout, tokenOut)) {
    return _executeRichirToRich(layout, params);
}
```

**`EthereumProtocolDETFExchangeInTarget.sol`** (lines 97-122):
```solidity
if (_isWethToken(layout, tokenIn) && _isChirToken(tokenOut)) {
    return _executeMintWithWeth(layout, params);
}
if (_isChirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
    return _executeChirRedemption(layout, params);
}
if (_isRichToken(layout, tokenIn) && _isChirToken(tokenOut)) {
    return _executeRichToChir(layout, params);
}
if (_isRichirToken(layout, tokenIn) && _isWethToken(layout, tokenOut)) {
    return _executeRichirRedemption(layout, params);
}
if (_isRichToken(layout, tokenIn) && _isRichirToken(layout, tokenOut)) {
    return _executeRichToRichir(layout, params);
}
if (_isWethToken(layout, tokenIn) && _isRichirToken(layout, tokenOut)) {
    return _executeWethToRichir(layout, params);
}
if (_isWethToken(layout, tokenIn) && _isRichToken(layout, tokenOut)) {
    return _executeWethToRich(layout, params);
}
if (_isRichToken(layout, tokenIn) && _isWethToken(layout, tokenOut)) {
    return _executeRichToWeth(layout, params);
}

revert InvalidToken(tokenIn);
```

**The RICHIR → RICH route is NOT present in the Ethereum variant.**

---

## Workflow Analysis

### 1. RICHIR → RICH Exchange Route (`_executeRichirToRich`)

**Location**: `BaseProtocolDETFExchangeInTarget.sol` lines 1035-1110

**Flow**:
1. Verify sender is in `allowedRichirRedeemAddresses`
2. Pull RICHIR from sender
3. Calculate BPT to exit from reserve pool
4. Burn RICHIR shares
5. Exit reserve pool proportionally → [chirWethShares, richChirVaultSharesOut]
6. CHIR/WETH portion → re-add to reserve pool, mint local RICHIR to sender
7. RICH/CHIR portion → exchange for RICH
8. Send RICH to local recipient (NO bridging)

**Access Control**:
```solidity
if (!layout_.allowedRichirRedeemAddresses._contains(msg.sender)) {
    revert BaseProtocolDETFRepo.NotAllowedRichirRedeem(msg.sender);
}
```

### 2. sellNFT Workflow (`sellNFT`)

**Location**: `BaseProtocolDETFBondingTarget.sol` lines 697-711

**Purpose**: Canonical Bond NFT → RICHIR route for selling bond positions

**Flow**:
1. Transfer bond NFT position from user to protocol
2. Harvest pending RICH rewards for `tokenId`
3. Transfer principal shares to protocol-owned position
4. Burn the sold bond NFT
5. Mint RICHIR against the contributed principal shares

**Implementation**:
```solidity
function sellNFT(uint256 tokenId, address recipient) external lock returns (uint256 richirMinted) {
    (uint256 principalShares,) = layout.protocolNFTVault.sellPositionToProtocol(tokenId, msg.sender, recipient);
    if (principalShares == 0) {
        revert ZeroAmount();
    }
    richirMinted = layout.richirToken.mintFromNFTSale(principalShares, recipient);
}
```

---

## What the Previous Agent Confused

| Aspect | RICHIR → RICH Exchange | sellNFT |
|--------|------------------------|---------|
| **Purpose** | Whitelisted local redemption | Sell bond NFT for RICHIR |
| **Input** | RICHIR tokens | Bond NFT |
| **Output** | RICH tokens | RICHIR tokens |
| **Access** | allowedRichirRedeemAddresses | NFT holder |
| **Entry Point** | exchangeIn | sellNFT |

The agent attempted to modify the `sellNFT` workflow when the goal was to add a whitelisted route to exchange RICHIR for RICH via the exchangeIn interface.

---

## Key Files

### Core Implementation
| File | Purpose |
|------|---------|
| `BaseProtocolDETFExchangeInTarget.sol` | Base exchangeIn routes including RICHIR→RICH |
| `EthereumProtocolDETFExchangeInTarget.sol` | Ethereum-specific exchangeIn (missing RICHIR→RICH) |
| `BaseProtocolDETFBondingTarget.sol` | Bonding and sellNFT |
| `BaseProtocolDETFRichirRedeemFacet.sol` | Facet for whitelist management |
| `BaseProtocolDETFRichirRedeemTarget.sol` | Target for whitelist management |
| `BaseProtocolDETFRepo.sol` | Storage with allowedRichirRedeemAddresses |
| `RICHIRFacet.sol` | RICHIR token facet |
| `RICHIRRepo.sol` | RICHIR rebasing token storage |

### Interfaces
| File | Purpose |
|------|---------|
| `IBaseProtocolDETFRichirRedeem.sol` | Whitelist management interface |

---

## Access Control Mechanism

The whitelist is managed via `BaseProtocolDETFRichirRedeemFacet`:

```solidity
// Add to whitelist
function addAllowedRichirRedeemAddress(address addr) external onlyOwnerOrOperator {
    layout.allowedRichirRedeemAddresses._add(addr);
}

// Remove from whitelist
function removeAllowedRichirRedeemAddress(address addr) external onlyOwnerOrOperator {
    layout.allowedRichirRedeemAddresses._remove(addr);
}

// Check if allowed
function isAllowedRichirRedeemAddress(address addr) external view returns (bool) {
    return layout.allowedRichirRedeemAddresses._contains(addr);
}
```

---

## Recommendations

1. **Add RICHIR → RICH route to EthereumProtocolDETFExchangeInTarget.sol**:
   - Copy the route check and `_executeRichirToRich` function from the base
   - Or override `_executeRichirToRich` in the Ethereum variant

2. **Do NOT modify sellNFT** - It correctly handles Bond NFT → RICHIR conversion

3. **Test the whitelisted route** - Verify `allowedRichirRedeemAddresses` works correctly

---

## Summary of Current State

- **RICHIR → RICH exchange**: Exists in base contract, missing in Ethereum variant
- **sellNFT**: Works correctly for Bond NFT → RICHIR
- **Whitelist management**: Properly implemented via `BaseProtocolDETFRichirRedeemFacet`

The agent's work appears to have conflated these two separate workflows, potentially trying to modify `sellNFT` when the actual requirement was adding the RICHIR→RICH exchange route to the Ethereum variant.

---

---

## Deep Dive: Calculation Flow Analysis (2026-03-27)

### Overview

This section provides a detailed trace of the two special calculation processes that deviate from typical vault reserve shares calculations:

1. **RICHIR Shares → BPT Tokens** (for redemption via `_executeRichirToRich`)
2. **NFT Position → RICHIR Minting** (for sellNFT workflow via `mintFromNFTSale`)

The key deviation: Both processes use **proportional share calculations based on the protocol NFT's original shares**, NOT Balancer pool math or current BPT balances.

---

## Calculation #1: RICHIR → BPT (Redemption)

### Purpose

When a whitelisted address redeems RICHIR for RICH, the protocol must calculate how much BPT to exit from the reserve pool. This uses a **proportional share formula** based on the protocol-owned NFT's original BPT allocation.

### Data Structures

**RICHIRRepo.Storage** (`RICHIRRepo.sol`):
```solidity
struct Storage {
    IProtocolDETF protocolDETF;
    IProtocolNFTVault nftVault;
    IERC20 wethToken;
    uint256 protocolNFTId;
    uint256 totalShares;           // Total RICHIR shares outstanding
    mapping(address => uint256) sharesOf;  // Shares per address
    uint256 cachedRedemptionRate;
    uint256 lastRateUpdateBlock;
}
```

**Position** (`IProtocolNFTVault.sol`):
```solidity
struct Position {
    uint256 originalShares;    // Base LP allocation (BPT)
    uint256 effectiveShares;    // Boosted shares (for rewards)
    uint256 bonusMultiplier;    // Lock duration bonus (1e18 = 1x)
    uint256 unlockTime;         // When position unlocks
    uint256 rewardDebt;         // Reward debt for calculation
}
```

### Step-by-Step Calculation

**Location**: `BaseProtocolDETFExchangeInTarget.sol` lines 399-408

```solidity
function _calcRichirRedemptionBptIn(
    BaseProtocolDETFRepo.Storage storage layout_,
    uint256 richirAmount_
) internal view returns (uint256 bptIn_) {
    // STEP 1: Convert RICHIR amount to shares using current redemption rate
    // This accounts for rebasing - balance != shares in RICHIR
    uint256 richirShares = layout_.richirToken.convertToShares(richirAmount_);

    // STEP 2: Get total outstanding RICHIR shares
    uint256 totalRichirShares = layout_.richirToken.totalShares();

    // STEP 3: Get the protocol NFT's ORIGINAL BPT allocation
    // This is the fixed BPT amount the protocol received when NFT was created
    uint256 protocolNftBpt = layout_.protocolNFTVault.originalSharesOf(layout_.protocolNFTId);

    // STEP 4: Apply proportional formula
    // bptIn = (richirShares / totalRichirShares) * protocolNftBpt
    bptIn_ = (richirShares * protocolNftBpt) / totalRichirShares;
}
```

### Mathematical Derivation

The formula maintains an invariant: **The ratio of user's RICHIR shares to total RICHIR shares equals the ratio of user's BPT claim to protocol's total BPT.**

```
let S_richir = user's RICHIR shares
let S_total = total RICHIR shares outstanding
let B_protocol = protocol NFT's original BPT

Invariant: S_richir / S_total = B_claim / B_protocol

Solving for B_claim:
B_claim = (S_richir / S_total) * B_protocol
```

### Why `originalSharesOf`?

**Critical insight**: The calculation uses `originalSharesOf(protocolNFTId)`, NOT the current BPT balance of the protocol NFT.

This is because:
1. The protocol NFT's BPT balance changes over time as rewards accumulate
2. RICHIR is backed 1:1 by the **original** BPT allocation at protocol NFT creation
3. Accumulated rewards are tracked separately via `effectiveShares` and `bonusMultiplier`
4. Using current balance would cause RICHIR valuation to drift from its backing

### Example

```
Given:
- User has 1000 RICHIR tokens
- Current redemption rate = 1.5e18 (1.5 WETH per RICHIR)
- Total RICHIR shares = 10,000
- Protocol NFT originalShares = 5000 BPT

Calculation:
1. richirShares = convertToShares(1000) = 1000 / 1.5 = 667 shares (approximately)
2. bptIn = (667 * 5000) / 10000 = 333.5 BPT
```

### Invariants Maintained

| Invariant | Description |
|-----------|-------------|
| Proportionality | User's BPT claim / Protocol BPT = User's RICHIR shares / Total RICHIR shares |
| Backing | Total RICHIR balance ≤ Protocol NFT's current BPT + pending rewards |
| Original Backing | Original BPT allocation remains constant in originalSharesOf |

---

## Calculation #2: NFT Position → RICHIR Minting

### Purpose

When a user sells their bond NFT to the protocol via `sellNFT()`, the protocol:
1. Transfers the NFT's principal shares to the protocol-owned NFT
2. Mints RICHIR 1:1 against those shares

### Step-by-Step Flow

**Entry Point**: `sellNFT()` in `BaseProtocolDETFBondingTarget.sol` lines 697-711

```solidity
function sellNFT(uint256 tokenId, address recipient) external lock returns (uint256 richirMinted) {
    // Step 1: Transfer NFT position to protocol, get principal shares
    (uint256 principalShares,) = layout.protocolNFTVault.sellPositionToProtocol(
        tokenId, msg.sender, recipient
    );
    if (principalShares == 0) {
        revert ZeroAmount();
    }

    // Step 2: Mint RICHIR 1:1 against the principal shares
    richirMinted = layout.richirToken.mintFromNFTSale(principalShares, recipient);
}
```

### sellPositionToProtocol Details

**Location**: `ProtocolNFTVaultTarget.sol` lines 242-282

```solidity
function sellPositionToProtocol(
    uint256 tokenId,
    address seller,
    address rewardsRecipient
) external onlyOwner lock returns (uint256 principalShares, uint256 rewardsClaimed) {
    // ... validation ...

    // Get the ORIGINAL shares (principal only, not effective/boosted shares)
    principalShares = layout.originalSharesOf[tokenId];

    // Harvest pending RICH rewards for the seller
    ProtocolNFTVaultRepo._updateGlobalRewards(layout);
    rewardsClaimed = _harvestRewardsInternal(layout, tokenId, rewardsRecipient);

    // Remove the sold position (burns the NFT)
    ProtocolNFTVaultRepo._removePosition(layout, tokenId);

    // Transfer original shares to protocol NFT
    ProtocolNFTVaultRepo._addToPosition(layout, layout.protocolNFTId, principalShares);

    // Burn the NFT
    ERC721Repo._burn(tokenId);
}
```

**Key insight**: Only `originalShares` are transferred to the protocol NFT — NOT `effectiveShares`. This is because:
- `effectiveShares` includes the lock bonus (boost multiplier)
- When selling, the user forfeits the lock bonus
- The protocol only backs RICHIR with actual BPT principal

### mintFromNFTSale Implementation

**Location**: `RICHIRTarget.sol` lines 236-250

```solidity
function mintFromNFTSale(uint256 lpShares, address recipient) external onlyOwner returns (uint256 richirMinted) {
    if (lpShares == 0) revert ZeroAmount();

    RICHIRRepo.Storage storage layout = RICHIRRepo._layout();

    // STEP 1: Mint shares directly 1:1 with BPT contributed
    // Shares track the underlying BPT proportion
    RICHIRRepo._mintShares(layout, recipient, lpShares);

    // STEP 2: Get current redemption rate to calculate balance
    uint256 rate = _getCurrentRedemptionRate(layout);

    // STEP 3: Convert shares to balance using rate
    // balance = shares * rate / 1e18
    richirMinted = RICHIRRepo._sharesToBalance(lpShares, rate);

    emit IRICHIR.Minted(recipient, lpShares, lpShares, richirMinted);
    emit IERC20Events.Transfer(address(0), recipient, richirMinted);
}
```

### Mathematical Flow

```
Input: lpShares (BPT amount being added to protocol NFT)

Step 1: _mintShares(recipient, lpShares)
  - sharesOf[recipient] += lpShares
  - totalShares += lpShares

Step 2: _getCurrentRedemptionRate()
  - Returns: (WETH_value_of_protocol_NFT_BPT * 1e18) / totalShares

Step 3: _sharesToBalance(lpShares, rate)
  - balance = lpShares * rate / 1e18

Output: richirMinted (RICHIR tokens minted)
```

### Why 1:1 Shares Minting?

Unlike typical vault operations that use Balancer math for BPT calculations, `mintFromNFTSale` directly mints shares 1:1 with BPT contributed. This works because:

1. The protocol NFT's `originalSharesOf` tracks the cumulative BPT principal
2. The redemption rate (derived from protocol NFT's WETH value) adjusts balance
3. Shares remain constant; only balance (via rate) rebases over time

### Invariants Maintained

| Invariant | Description |
|-----------|-------------|
| 1:1 Shares | Each BPT added to protocol NFT → 1 share minted |
| Balance = Shares × Rate | RICHIR balance adjusts via rebasing |
| Original Backing | Protocol NFT originalShares increases by lpShares |

---

## Calculation #3: Redemption Rate Derivation

### Purpose

The redemption rate determines how much WETH each RICHIR share is worth. It's calculated fresh on each interaction (or cached).

### Implementation

**Location**: `RICHIRTarget.sol` lines 380-406

```solidity
function _calcCurrentRedemptionRate(RICHIRRepo.Storage storage layout_) internal view returns (uint256 rate) {
    uint256 totalShares_ = layout_.totalShares;
    if (totalShares_ == 0) {
        return ONE_WAD;  // 1:1 when no RICHIR outstanding
    }

    // Get protocol-owned NFT position
    IProtocolNFTVault.Position memory position = layout_.nftVault.getPosition(layout_.protocolNFTId);
    if (position.originalShares == 0) {
        return ONE_WAD;
    }

    // Calculate WETH value of protocol NFT's BPT via StandardExchange preview
    IERC20 bpt = IERC20(layout_.protocolDETF.reservePool());
    uint256 wethValue = IStandardExchangeIn(address(layout_.protocolDETF)).previewExchangeIn(
        bpt,
        position.originalShares,  // Use original shares for valuation
        layout_.wethToken
    );

    if (wethValue == 0) {
        return ONE_WAD;
    }

    // rate = WETH_value / total_RICHIR_shares
    // This gives WETH per share (with 1e18 precision)
    rate = (wethValue * ONE_WAD) / totalShares_;

    if (rate == 0) {
        rate = 1;  // Minimum rate of 1 wei
    }
}
```

### Mathematical Formula

```
rate = (WETH_value_of_protocol_NFT × 1e18) / totalRICHIRShares

Where:
- WETH_value_of_protocol_NFT = previewExchangeIn(BPT, originalShares, WETH)
- This converts protocol NFT's originalShares to WETH using reserve pool pricing
```

### Why Use `previewExchangeIn`?

The `previewExchangeIn` function (via `IStandardExchangeIn`) calculates how much WETH you'd receive if you exited the reserve pool with `originalShares` amount of BPT. This gives:

1. **Current market value** of the protocol's BPT position
2. **公允价** (fair market price) based on pool liquidity
3. **Price impact** accounted for via virtual balances (for stableswap pools)

### Why `originalShares` Not Current Balance?

```
position.originalShares = Fixed BPT principal at NFT creation
position.effectiveShares = Original + accumulated lock bonuses

For redemption backing:
- We use originalShares because RICHIR is only backed by principal
- Lock bonuses represent future yield, not current backing
- Rewards (RICH) accumulate separately and don't affect RICHIR backing
```

### Example

```
Given:
- Protocol NFT originalShares = 5000 BPT
- Reserve pool price: 1 BPT = 1.2 WETH (via previewExchangeIn)
- Total RICHIR shares = 10,000

Calculation:
1. wethValue = previewExchangeIn(BPT, 5000, WETH) = 5000 * 1.2 = 6000 WETH
2. rate = (6000 * 1e18) / 10000 = 0.6e18 = 0.6 WETH per share
```

---

## Comparison: Protocol DETF vs Typical Vault Calculations

### Typical Vault: _addToReservePool

**Location**: `BaseProtocolDETFBondingTarget.sol` lines 774-823

```solidity
function _addToReservePool(...) internal returns (uint256 bptOut) {
    // Uses Balancer's calcBptOutGivenSingleIn
    // This calculates BPT output given token input using pool math
    bptOut = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
        virtualInvotes,
        virtualBptSupply,
        totalShares,
        totalWeight,
        amountIn,
        swapFeePercentage
    );
}
```

**Key difference**: Balancer pool math with virtual balances, swap fees, and price impact.

### Protocol DETF: RICHIR Calculations

| Aspect | Typical Vault | Protocol DETF RICHIR |
|--------|--------------|---------------------|
| **Input** | Token amount | RICHIR shares |
| **Formula** | Balancer math | Proportional share |
| **Reference** | Pool reserves | Protocol NFT originalShares |
| **Denominator** | Virtual BPT supply | Total RICHIR shares |
| **Pool fees** | Yes (swapFeePercentage) | No |
| **Price impact** | Yes (from virtual balances) | No (uses originalShares) |
| **Rebasing** | No | Yes (via redemption rate) |

### Why the Difference?

Typical vault calculations must account for:
1. **Pool liquidity** - How much BPT can be minted per token
2. **Price impact** - Slippage from virtual balances
3. **Swap fees** - Protocol takes a cut

Protocol DETF RICHIR calculations don't need this because:
1. **Fixed backing** - RICHIR is backed 1:1 by protocol NFT's originalShares
2. **No secondary market** - RICHIR doesn't trade on AMM
3. **Rebasing mechanism** - Rate adjusts to reflect underlying value changes
4. **Whitelist control** - Only whitelisted addresses can redeem

---

## Summary of Calculation Deviations

### Deviation #1: Proportional BPT Exit

**Typical**: `bptOut = calcBptOutGivenSingleIn(tokenAmount, ...)` using pool math
**Protocol**: `bptIn = (richirShares × protocolNftBpt) / totalRichirShares`

**Why**: Protocol tracks backing via originalShares, not current pool balances.

### Deviation #2: Direct 1:1 Shares Minting

**Typical**: `bptOut = calcBptOutGivenSingleIn(tokenAmount, ...)`
**Protocol**: `_mintShares(recipient, lpShares)` with no pool math

**Why**: Shares directly track BPT principal; redemption rate handles valuation.

### Deviation #3: OriginalShares Valuation

**Typical**: `bptBalance` of vault/reserve
**Protocol**: `position.originalShares` of protocol NFT

**Why**: OriginalShares represents fixed BPT backing; effectiveShares includes bonuses.

### Deviation #4: No Price Impact/Slippage

**Typical**: Virtual balance calculations affect output
**Protocol**: No virtual balance math in share calculations

**Why**: Redemption uses proportional share formula, not AMM pricing.

---

## Verified Implementation Files

| File | Lines | Purpose |
|------|-------|---------|
| `BaseProtocolDETFExchangeInTarget.sol` | 399-408 | `_calcRichirRedemptionBptIn` formula |
| `BaseProtocolDETFExchangeInTarget.sol` | 1035-1110 | `_executeRichirToRich` full flow |
| `RICHIRTarget.sol` | 236-250 | `mintFromNFTSale` |
| `RICHIRTarget.sol` | 380-406 | `_calcCurrentRedemptionRate` |
| `RICHIRRepo.sol` | 256-267 | `_sharesToBalance`, `_balanceToShares` |
| `ProtocolNFTVaultTarget.sol` | 242-282 | `sellPositionToProtocol` |
| `ProtocolNFTVaultRepo.sol` | 229-234 | `_originalSharesOf` |

---

## Remaining Implementation Task

**Add RICHIR → RICH route to `EthereumProtocolDETFExchangeInTarget.sol`**:
- Copy the route check from `BaseProtocolDETFExchangeInTarget.sol` lines 186-191
- Implement or inherit `_executeRichirToRich` function

(End of file)