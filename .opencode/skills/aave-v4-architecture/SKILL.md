---
name: Aave V4 Architecture
description: This skill should be used when the user asks about "Aave V4 architecture", "hub-and-spoke", "Hub contract", "Spoke contract", "unified liquidity layer", or needs a high-level understanding of how Aave V4 works.
version: 0.1.0
---

# Aave V4 Architecture

Aave V4 introduces a unified liquidity layer with a modular hub-and-spoke architecture that enhances capital efficiency, scalability, and risk management.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    AAVE V4 HUB-AND-SPOKE                     │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│      ┌─────────────────┐     ┌─────────────────┐             │
│      │ Liquidity       │     │ Borrowers       │             │
│      │ Providers       │     │                 │             │
│      └────────┬────────┘     └────────┬────────┘             │
│               │                       │                      │
│               ▼                       ▼                      │
│      ┌─────────────┐         ┌─────────────┐                 │
│      │   Spoke 1   │         │   Spoke 2   │                 │
│      │  (crypto)   │         │   (RWA)     │                 │
│      └──────┬──────┘         └──────┬──────┘                 │
│             │                       │                        │
│             └───────────┬───────────┘                        │
│                         ▼                                    │
│               ┌─────────────────┐                            │
│               │       HUB       │                            │
│               │  (Liquidity +   │                            │
│               │   Accounting)   │                            │
│               └─────────────────┘                            │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Key Architectural Changes from V3

| V3 | V4 |
|----|-----|
| Single Pool contract | Hub + multiple Spokes |
| aTokens + DebtTokens | Share-based accounting |
| Static risk parameters | Dynamic Risk Configuration |
| Fixed close factor (50%) | Target Health Factor liquidation |
| Single interest rate | Base Rate + Risk Premium |

## Core Components

### Hub

The Hub is the **immutable** central coordinator for liquidity management:

```solidity
contract Hub is IHub, AccessManaged {
    // Asset management
    mapping(uint256 assetId => Asset) internal _assets;

    // Spoke management per asset
    mapping(uint256 assetId => mapping(address spoke => SpokeData)) internal _spokes;

    // Core operations (callable only by authorized Spokes)
    function add(uint256 assetId, uint256 amount) external returns (uint256 shares);
    function remove(uint256 assetId, uint256 amount, address to) external returns (uint256 shares);
    function draw(uint256 assetId, uint256 amount, address to) external returns (uint256 shares);
    function restore(uint256 assetId, uint256 drawnAmount, PremiumDelta calldata premiumDelta) external returns (uint256);
}
```

**Hub Responsibilities:**
- Maintains registry of authorized Spokes
- Manages liquidity caps for Spokes
- Enforces accounting invariants
- Provides emergency stop functionality
- Tracks drawn shares, added shares, and premium shares

### Spoke

Spokes are **upgradeable** and handle user-facing operations:

```solidity
abstract contract Spoke is ISpoke, Multicall, AccessManagedUpgradeable {
    address public immutable ORACLE;

    // Reserve management
    mapping(uint256 reserveId => Reserve) internal _reserves;

    // User positions
    mapping(address user => mapping(uint256 reserveId => UserPosition)) internal _userPositions;

    // Dynamic risk configuration
    mapping(uint256 reserveId => mapping(uint24 dynamicConfigKey => DynamicReserveConfig)) internal _dynamicConfig;

    // User operations
    function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
    function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
    function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
    function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
    function liquidationCall(...) external;
}
```

**Spoke Responsibilities:**
- User-facing supply, withdraw, borrow, repay operations
- Managing user data structures and configurations
- Risk management (collateral, liquidation thresholds)
- Oracle interactions
- Position Manager authorization

### Position Manager

Gateway contracts that can operate on behalf of users:

```solidity
// Users authorize Position Managers
function setUserPositionManager(address manager, bool approved) external;

// Position Manager can then call user operations
spoke.supply(reserveId, amount, user);  // onBehalfOf = user
```

## Asset vs Reserve

```
┌──────────────────────────────────────────────────────────────┐
│                    ASSET vs RESERVE                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ASSET (Hub-level)          RESERVE (Spoke-level)            │
│  ─────────────────          ──────────────────────           │
│  • assetId: uint256         • reserveId: uint256             │
│  • One per underlying       • One per Spoke per Asset        │
│  • Hub manages liquidity    • Spoke manages risk params      │
│  • Global accounting        • User positions stored here     │
│                                                              │
│  Example:                                                    │
│  Hub has USDC (assetId=0)                                    │
│  Spoke A has USDC reserve (reserveId=0, assetId=0)           │
│  Spoke B has USDC reserve (reserveId=0, assetId=0)           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Data Structures

### Asset (Hub)

```solidity
struct Asset {
    uint256 liquidity;           // Total liquidity in Hub
    uint256 deficitRay;          // Bad debt (ray precision)
    uint256 swept;               // Swept to reinvestment
    uint256 addedShares;         // Total supply shares
    uint256 drawnShares;         // Total borrow shares
    uint256 premiumShares;       // Premium interest shares
    uint256 premiumOffsetRay;    // Premium offset tracking
    uint120 drawnIndex;          // Borrow index
    address underlying;          // Underlying token
    uint40 lastUpdateTimestamp;
    uint8 decimals;
    uint96 drawnRate;            // Current borrow rate
    address irStrategy;          // Interest rate strategy
    uint256 realizedFees;        // Fees collected
    address reinvestmentController;
    address feeReceiver;
    uint16 liquidityFee;         // Fee on liquidity
}
```

### Reserve (Spoke)

```solidity
struct Reserve {
    address underlying;
    IHubBase hub;
    uint16 assetId;
    uint8 decimals;
    uint24 dynamicConfigKey;     // Current risk config
    uint24 collateralRisk;       // Risk premium factor
    ReserveFlags flags;          // paused, frozen, borrowable, etc.
}
```

### UserPosition (Spoke)

```solidity
struct UserPosition {
    uint256 suppliedShares;
    uint256 drawnShares;
    uint256 premiumSharesRay;
    uint256 premiumOffsetRay;
    uint24 dynamicConfigKey;     // Position's risk config snapshot
}
```

## Key Concepts

### Share-Based Accounting

V4 uses shares instead of tokens:
- **Added Shares**: Supply position (like aTokens)
- **Drawn Shares**: Borrow position (like debt tokens)
- **Premium Shares**: Risk premium interest

```solidity
// Convert shares to assets
uint256 assets = hub.previewRemoveByShares(assetId, shares);

// Convert assets to shares
uint256 shares = hub.previewAddByAssets(assetId, assets);
```

### Interest Model

V4 separates interest into:
1. **Base Rate**: Determined by utilization (Hub-level)
2. **Risk Premium**: Based on collateral quality (user-level)

```
Total User Rate = Base Rate × (1 + Risk Premium)
```

### Health Factor

```
Health Factor = Σ(Collateral × Collateral Factor) / Total Debt
```
- Liquidatable when HF < 1
- Target HF after liquidation is configurable

## Protocol Flow

### Supply Flow

```
User → Spoke.supply() → Hub.add()
  1. Spoke transfers underlying to Hub
  2. Hub mints added shares to Spoke
  3. Spoke records user's supply shares
```

### Borrow Flow

```
User → Spoke.borrow() → Hub.draw()
  1. Validate HF will remain >= 1
  2. Hub mints drawn shares to Spoke
  3. Hub transfers underlying to user
  4. Spoke records user's drawn shares + premium
```

### Repay Flow

```
User → Spoke.repay() → Hub.restore()
  1. User transfers underlying to Hub
  2. Hub burns drawn shares and applies premium delta
  3. Spoke updates user position
```

## Skills Reference

| Skill | Description |
|-------|-------------|
| `aave-v4-hub` | Hub contract operations and liquidity management |
| `aave-v4-spoke` | Spoke operations (supply, borrow, repay, withdraw) |
| `aave-v4-risk-premium` | Risk Premium system and collateral quality |
| `aave-v4-dynamic-config` | Dynamic Risk Configuration |
| `aave-v4-liquidation` | Redesigned liquidation engine |
| `aave-v4-position-manager` | Position Manager gateways |

## Reference Files

- `src/hub/Hub.sol` - Hub contract
- `src/spoke/Spoke.sol` - Spoke contract
- `src/hub/interfaces/IHub.sol` - Hub interface
- `src/spoke/interfaces/ISpoke.sol` - Spoke interface
- `docs/overview.md` - Protocol overview
