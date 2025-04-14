---
name: Comet Architecture
description: This skill should be used when the user asks about "Compound V3", "Comet", "protocol architecture", "monolithic", or needs a high-level understanding of the Compound V3 Comet protocol.
version: 0.1.0
---

# Compound V3 Comet Architecture

Compound V3 (Comet) is a monolithic money market protocol optimized for borrowing a single base asset (e.g., USDC) against multiple collateral assets. Unlike V2's per-asset markets, Comet consolidates everything into one efficient contract.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                   COMET ARCHITECTURE                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                      Comet Proxy                        │ │
│  │                    (TransparentProxy)                   │ │
│  └────────────────────────┬────────────────────────────────┘ │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Comet.sol                            │ │
│  │  • Supply/Withdraw base token                           │ │
│  │  • Supply/Withdraw collateral                           │ │
│  │  • Transfer assets                                      │ │
│  │  • Absorb (liquidate) accounts                          │ │
│  │  • Buy collateral from reserves                         │ │
│  │  • Interest accrual                                     │ │
│  └────────────────────────┬────────────────────────────────┘ │
│                           │ fallback()                       │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   CometExt.sol                          │ │
│  │  • ERC20 approve/allowance                              │ │
│  │  • allowBySig (EIP-712)                                 │ │
│  │  • View functions (name, symbol)                        │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Supplementary Contracts:                                    │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Bulker          │ Batch multiple actions in one tx      │ │
│  │ CometRewards    │ Claim COMP rewards                    │ │
│  │ Configurator    │ Governance configuration              │ │
│  │ CometFactory    │ Deploy new Comet implementations      │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Value Proposition

1. **Capital Efficiency**: More borrowing power for the same collateral
2. **Gas Optimization**: Monolithic design reduces external calls
3. **Single Borrowable Asset**: Optimized for stablecoin borrowing (USDC)
4. **Fine-Grained Access Control**: Delegate account management via `allow`
5. **Internalized Liquidation**: Protocol captures liquidation profits

## Core Contracts

```solidity
// Comet.sol - Main protocol implementation
contract Comet is CometMainInterface {
    // Immutable configuration (set at deploy, never changes)
    address public immutable governor;
    address public immutable pauseGuardian;
    address public immutable baseToken;              // e.g., USDC
    address public immutable baseTokenPriceFeed;     // Chainlink oracle
    address public immutable extensionDelegate;      // CometExt address

    // Interest rate model (kinked)
    uint public immutable supplyKink;
    uint public immutable supplyPerSecondInterestRateSlopeLow;
    uint public immutable supplyPerSecondInterestRateSlopeHigh;
    uint public immutable borrowKink;
    uint public immutable borrowPerSecondInterestRateSlopeLow;
    uint public immutable borrowPerSecondInterestRateSlopeHigh;

    // Collateral configuration (packed for gas)
    uint8 public immutable numAssets;                // Up to 12 assets
}

// CometExt.sol - Extension for additional functions
contract CometExt is CometExtInterface {
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function allow(address manager, bool isAllowed_) external;
    function allowBySig(...) external;  // EIP-712 signatures
}
```

## Storage Layout

```solidity
// CometStorage.sol
contract CometStorage {
    // Global market state (packed into 2 slots)
    uint64 internal baseSupplyIndex;        // Interest index for suppliers
    uint64 internal baseBorrowIndex;        // Interest index for borrowers
    uint64 internal trackingSupplyIndex;    // Reward tracking for suppliers
    uint64 internal trackingBorrowIndex;    // Reward tracking for borrowers
    uint104 internal totalSupplyBase;       // Total base principal supplied
    uint104 internal totalBorrowBase;       // Total base principal borrowed
    uint40 internal lastAccrualTime;        // Last interest accrual timestamp
    uint8 internal pauseFlags;              // Pause state for functions

    // Per-collateral totals
    mapping(address => TotalsCollateral) public totalsCollateral;

    // User state
    mapping(address => UserBasic) public userBasic;
    mapping(address => mapping(address => UserCollateral)) public userCollateral;
    mapping(address => mapping(address => bool)) public isAllowed;
}

struct UserBasic {
    int104 principal;              // Base balance (+ = supply, - = borrow)
    uint64 baseTrackingIndex;      // User's last tracking index
    uint64 baseTrackingAccrued;    // Accumulated reward points
    uint16 assetsIn;               // Bit vector of collateral assets
    uint8 _reserved;
}
```

## Configuration Structure

```solidity
// CometConfiguration.sol
struct Configuration {
    address governor;
    address pauseGuardian;
    address baseToken;
    address baseTokenPriceFeed;
    address extensionDelegate;

    // Interest rate model parameters
    uint64 supplyKink;
    uint64 supplyPerYearInterestRateSlopeLow;
    uint64 supplyPerYearInterestRateSlopeHigh;
    uint64 supplyPerYearInterestRateBase;
    uint64 borrowKink;
    uint64 borrowPerYearInterestRateSlopeLow;
    uint64 borrowPerYearInterestRateSlopeHigh;
    uint64 borrowPerYearInterestRateBase;

    // Other parameters
    uint64 storeFrontPriceFactor;
    uint64 trackingIndexScale;
    uint64 baseTrackingSupplySpeed;
    uint64 baseTrackingBorrowSpeed;
    uint104 baseMinForRewards;
    uint104 baseBorrowMin;
    uint104 targetReserves;

    AssetConfig[] assetConfigs;  // Collateral assets
}

struct AssetConfig {
    address asset;
    address priceFeed;
    uint8 decimals;
    uint64 borrowCollateralFactor;      // CF for initiating borrows
    uint64 liquidateCollateralFactor;   // CF for liquidation check
    uint64 liquidationFactor;           // Penalty applied at liquidation
    uint128 supplyCap;
}
```

## Principal vs Present Value

Comet uses **principal** (day-zero balances) for efficient storage:

```solidity
// Present Value = Principal × Index
// Principal = Present Value / Index

// Supply balance: principal is positive
int presentValue = presentValue(principal);
// If principal > 0: presentValue = principal * baseSupplyIndex
// If principal < 0: presentValue = principal * baseBorrowIndex

// Converting back
int104 principalNew = principalValue(presentValue);
```

This allows a single signed integer to represent both supply and borrow positions.

## Delegation System

Users can delegate account management to other addresses:

```solidity
// Allow manager to act on behalf of owner
function allow(address manager, bool isAllowed_) external;

// EIP-712 gasless signature-based approval
function allowBySig(
    address owner,
    address manager,
    bool isAllowed_,
    uint256 nonce,
    uint256 expiry,
    uint8 v, bytes32 r, bytes32 s
) external;

// Check permission
function hasPermission(address owner, address manager) public view returns (bool) {
    return owner == manager || isAllowed[owner][manager];
}
```

## Price Oracle Integration

Comet uses Chainlink price feeds:

```solidity
function getPrice(address priceFeed) public view returns (uint256) {
    (, int price, , , ) = IPriceFeed(priceFeed).latestRoundData();
    if (price <= 0) revert BadPrice();
    return uint256(price);
}

// All price feeds must return 8 decimals (PRICE_FEED_DECIMALS = 8)
```

## Pause Guardian

Specific functions can be paused by governor or pause guardian:

```solidity
function pause(
    bool supplyPaused,
    bool transferPaused,
    bool withdrawPaused,
    bool absorbPaused,
    bool buyPaused
) external {
    if (msg.sender != governor && msg.sender != pauseGuardian) revert Unauthorized();
    pauseFlags = ...;
}

// Check pause state
function isSupplyPaused() public view returns (bool);
function isTransferPaused() public view returns (bool);
function isWithdrawPaused() public view returns (bool);
function isAbsorbPaused() public view returns (bool);
function isBuyPaused() public view returns (bool);
```

## Key Design Decisions

1. **Immutable Configuration**: Most parameters are immutable; changes require deploying new implementation
2. **Signed Principal**: Single `int104` for both supply and borrow positions
3. **Bit Vector for Assets**: `uint16 assetsIn` tracks which collaterals a user has (up to 16 assets, limited to 12)
4. **Packed Storage**: Aggressive packing to minimize gas costs
5. **Separate Indices**: Supply and borrow have independent interest indices

## Reference Files

- `contracts/Comet.sol` - Main protocol implementation
- `contracts/CometExt.sol` - Extension delegate for ERC20/approval
- `contracts/CometStorage.sol` - Storage layout
- `contracts/CometConfiguration.sol` - Configuration structs
- `contracts/CometCore.sol` - Shared functions and constants
