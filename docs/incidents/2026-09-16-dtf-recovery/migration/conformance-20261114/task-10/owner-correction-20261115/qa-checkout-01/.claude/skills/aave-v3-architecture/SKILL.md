---
name: Aave V3 Architecture
description: This skill should be used when the user asks about "Aave V3 architecture", "Pool contract", "PoolAddressesProvider", "PoolConfigurator", "Aave lending", "Aave borrowing", or needs a high-level understanding of how Aave V3 works.
version: 0.1.0
---

# Aave V3 Architecture

Aave V3 is a decentralized non-custodial lending protocol where users can supply assets to earn interest and borrow against collateral. This skill provides a high-level overview of the protocol architecture.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                      AAVE V3 ARCHITECTURE                    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 PoolAddressesProvider                   │ │
│  │     Central registry for all protocol contracts         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                               │
│       ┌──────────────────────┼──────────────────────┐        │
│       ▼                      ▼                      ▼        │
│  ┌─────────┐          ┌─────────────┐        ┌───────────┐   │
│  │  Pool   │◄────────►│PoolConfig-  │        │ ACLManager│   │
│  │         │          │   urator    │        │           │   │
│  └────┬────┘          └─────────────┘        └───────────┘   │
│       │                                                      │
│       │  manages                                             │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Reserves (Assets)                     │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐     │ │
│  │  │ aToken  │  │ Variable│  │ Interest│  │ Oracle  │     │ │
│  │  │         │  │DebtToken│  │RateStrat│  │         │     │ │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Core Components

### PoolAddressesProvider

The central registry that stores addresses of all protocol contracts for a specific market.

```solidity
interface IPoolAddressesProvider {
    function getPool() external view returns (address);
    function getPoolConfigurator() external view returns (address);
    function getPriceOracle() external view returns (address);
    function getACLManager() external view returns (address);
    function getACLAdmin() external view returns (address);
    function getPriceOracleSentinel() external view returns (address);
    function getPoolDataProvider() external view returns (address);

    // Generic address getter for custom identifiers
    function getAddress(bytes32 id) external view returns (address);
}
```

### Pool

The main entry point for user interactions. All supply, borrow, repay, and withdraw operations go through the Pool.

```solidity
interface IPool {
    // Core operations
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);

    // Collateral management
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

    // Liquidation
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;

    // Flash loans
    function flashLoan(address receiverAddress, address[] calldata assets, uint256[] calldata amounts, uint256[] calldata interestRateModes, address onBehalfOf, bytes calldata params, uint16 referralCode) external;
    function flashLoanSimple(address receiverAddress, address asset, uint256 amount, bytes calldata params, uint16 referralCode) external;

    // eModes
    function setUserEMode(uint8 categoryId) external;
    function getUserEMode(address user) external view returns (uint256);

    // Account data
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
}
```

### PoolConfigurator

Admin contract for configuring reserves and protocol parameters.

```solidity
interface IPoolConfigurator {
    // Reserve initialization
    function initReserves(ConfiguratorInputTypes.InitReserveInput[] calldata input) external;

    // Reserve configuration
    function setReserveBorrowing(address asset, bool enabled) external;
    function configureReserveAsCollateral(address asset, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus) external;
    function setReserveFreeze(address asset, bool freeze) external;
    function setReservePause(address asset, bool paused) external;
    function setReserveFactor(address asset, uint256 newReserveFactor) external;

    // Caps
    function setBorrowCap(address asset, uint256 newBorrowCap) external;
    function setSupplyCap(address asset, uint256 newSupplyCap) external;

    // eModes
    function setEModeCategory(uint8 categoryId, uint16 ltv, uint16 liquidationThreshold, uint16 liquidationBonus, string calldata label) external;
}
```

### ACLManager

Access control manager for protocol roles.

```solidity
interface IACLManager {
    function isPoolAdmin(address admin) external view returns (bool);
    function isEmergencyAdmin(address admin) external view returns (bool);
    function isRiskAdmin(address admin) external view returns (bool);
    function isFlashBorrower(address borrower) external view returns (bool);
    function isBridge(address bridge) external view returns (bool);
    function isAssetListingAdmin(address admin) external view returns (bool);
}
```

## Reserve Data Structure

Each asset listed on Aave has associated reserve data:

```solidity
struct ReserveData {
    // Configuration stored as bitmap
    ReserveConfigurationMap configuration;

    // Indexes (in ray - 27 decimals)
    uint128 liquidityIndex;          // Supply index for interest accrual
    uint128 variableBorrowIndex;     // Borrow index for interest accrual

    // Current rates (in ray)
    uint128 currentLiquidityRate;    // Current supply APY
    uint128 currentVariableBorrowRate; // Current borrow APY

    // Deficit tracking (V3.3)
    uint128 deficit;

    // Timestamps
    uint40 lastUpdateTimestamp;
    uint40 liquidationGracePeriodUntil;

    // Token addresses
    uint16 id;
    address aTokenAddress;
    address variableDebtTokenAddress;
    address interestRateStrategyAddress;

    // Accounting
    uint128 accruedToTreasury;       // Fees accumulated for treasury
    uint128 unbacked;                 // Unbacked aTokens (bridging)
    uint128 isolationModeTotalDebt;   // Debt in isolation mode
    uint128 virtualUnderlyingBalance; // Virtual accounting balance
}
```

## Key Concepts

### Interest Rate Model

Aave uses a variable interest rate model:

```
┌──────────────────────────────────────────────────────────────┐
│                    INTEREST RATE CURVE                       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Rate │                                    ╱                 │
│       │                                  ╱                   │
│       │                                ╱  Slope2             │
│       │                              ╱                       │
│       │                     ╱───────╱                        │
│       │                   ╱  Slope1                          │
│       │                 ╱                                    │
│       │      Base Rate ╱                                     │
│       └───────────────┼───────────────────────────────────   │
│                       │                                      │
│                   Optimal                                    │
│                 Utilization                                  │
│                                                              │
│  Utilization = Total Debt / (Virtual Balance + Total Debt)  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Loan-to-Value (LTV) and Liquidation

- **LTV**: Maximum borrowing power as percentage of collateral
- **Liquidation Threshold (LT)**: When health factor drops below 1, liquidation is possible
- **Liquidation Bonus (LB)**: Incentive for liquidators (extra collateral received)
- **Health Factor**: `HF = Σ(Collateral × LT) / Total Debt`

### Virtual Accounting (V3.1+)

Aave V3.1+ tracks virtual balances to protect against donation attacks:

```solidity
// Instead of checking actual token balance:
// balanceOf(aToken)

// Aave uses virtual balance tracking:
virtualUnderlyingBalance += amountSupplied;
virtualUnderlyingBalance -= amountWithdrawn;
```

### eModes (Efficiency Modes)

Allow higher LTV for correlated assets:

```solidity
struct EModeCategory {
    uint16 ltv;                  // Higher LTV for correlated assets
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
    uint128 collateralBitmap;    // Which assets can be collateral
    uint128 borrowableBitmap;    // Which assets can be borrowed
    string label;
}
```

## Protocol Flow

### Supply Flow

```
User → Pool.supply() → SupplyLogic.executeSupply()
  1. Update reserve indexes
  2. Transfer underlying to aToken
  3. Mint aTokens to user
  4. Update virtual balance
  5. Update interest rates
```

### Borrow Flow

```
User → Pool.borrow() → BorrowLogic.executeBorrow()
  1. Validate health factor will remain >= 1
  2. Update reserve indexes
  3. Mint debt tokens to user
  4. Transfer underlying to user
  5. Update interest rates
```

### Liquidation Flow

```
Liquidator → Pool.liquidationCall() → LiquidationLogic.executeLiquidationCall()
  1. Verify user health factor < 1
  2. Calculate debt to cover and collateral to receive
  3. Burn debt tokens
  4. Transfer collateral to liquidator (+ bonus)
  5. Update interest rates
```

## Version Features

| Version | Key Features |
|---------|--------------|
| V3.0 | eModes, isolation mode, siloed borrowing |
| V3.1 | Virtual accounting, stateful interest rates, liquidation grace period |
| V3.2 | Liquid eModes, stable rate deprecation |
| V3.3 | Deficit tracking, liquidation optimizations |

## Skills Reference

| Skill | Description |
|-------|-------------|
| `aave-v3-pool` | Core Pool operations (supply, borrow, repay, withdraw) |
| `aave-v3-tokens` | aTokens and Variable Debt Tokens |
| `aave-v3-configuration` | Reserve configuration and interest rate strategies |
| `aave-v3-emodes` | Efficiency Modes for correlated assets |
| `aave-v3-flash-loans` | Flash loan functionality |
| `aave-v3-stata-token` | ERC4626 wrapper for aTokens |

## Reference Files

- `src/contracts/protocol/pool/Pool.sol` - Main Pool contract
- `src/contracts/protocol/pool/PoolConfigurator.sol` - Configuration contract
- `@crane/contracts/external/aave-v3-origin/contracts/protocol/libraries/types/DataTypes.sol` - Core data structures
- `@crane/contracts/external/aave-v3-origin/contracts/interfaces/IPool.sol` - Pool interface
- `src/contracts/interfaces/IPoolAddressesProvider.sol` - Registry interface
