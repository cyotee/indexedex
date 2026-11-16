---
name: Aave V3 Configuration
description: This skill should be used when the user asks about "ReserveConfiguration", "interest rate strategy", "DefaultReserveInterestRateStrategyV2", "reserve factor", "LTV", "liquidation threshold", "caps", "PoolConfigurator", or needs to understand Aave V3 reserve configuration.
version: 0.1.0
---

# Aave V3 Configuration

This skill covers reserve configuration, interest rate strategies, and protocol parameters in Aave V3.

## Reserve Configuration Bitmap

Reserve parameters are packed into a single uint256 bitmap for gas efficiency:

```solidity
struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: DEPRECATED (was stable rate)
    //bit 60: asset is paused
    //bit 61: borrowing in isolation mode is enabled
    //bit 62: siloed borrowing enabled
    //bit 63: flashloaning enabled
    //bit 64-79: reserve factor
    //bit 80-115: borrow cap in whole tokens
    //bit 116-151: supply cap in whole tokens
    //bit 152-167: liquidation protocol fee
    //bit 168-175: DEPRECATED (was eMode category)
    //bit 176-211: unbacked mint cap
    //bit 212-251: debt ceiling for isolation mode
    //bit 252: virtual accounting enabled
    //bit 253-255: unused
    uint256 data;
}
```

## ReserveConfiguration Library

```solidity
library ReserveConfiguration {
    uint256 internal constant LTV_MASK =                       0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000;
    uint256 internal constant LIQUIDATION_THRESHOLD_MASK =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF;
    uint256 internal constant LIQUIDATION_BONUS_MASK =         0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFF;
    uint256 internal constant DECIMALS_MASK =                  0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF;
    uint256 internal constant ACTIVE_MASK =                    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
    uint256 internal constant FROZEN_MASK =                    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;
    uint256 internal constant BORROWING_MASK =                 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFFFF;
    uint256 internal constant PAUSED_MASK =                    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF;

    // Getters
    function getLtv(DataTypes.ReserveConfigurationMap memory self) internal pure returns (uint256);
    function getLiquidationThreshold(DataTypes.ReserveConfigurationMap memory self) internal pure returns (uint256);
    function getLiquidationBonus(DataTypes.ReserveConfigurationMap memory self) internal pure returns (uint256);
    function getDecimals(DataTypes.ReserveConfigurationMap memory self) internal pure returns (uint256);
    function getActive(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool);
    function getFrozen(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool);
    function getBorrowingEnabled(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool);
    function getPaused(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool);
    function getReserveFactor(DataTypes.ReserveConfigurationMap memory self) internal pure returns (uint256);
    function getBorrowCap(DataTypes.ReserveConfigurationMap memory self) internal pure returns (uint256);
    function getSupplyCap(DataTypes.ReserveConfigurationMap memory self) internal pure returns (uint256);
    function getDebtCeiling(DataTypes.ReserveConfigurationMap memory self) internal pure returns (uint256);

    // Setters (used by PoolConfigurator)
    function setLtv(DataTypes.ReserveConfigurationMap memory self, uint256 ltv) internal pure;
    function setLiquidationThreshold(DataTypes.ReserveConfigurationMap memory self, uint256 threshold) internal pure;
    function setLiquidationBonus(DataTypes.ReserveConfigurationMap memory self, uint256 bonus) internal pure;
    // ... etc
}
```

## Configuration Parameters

### LTV (Loan-to-Value)

Maximum borrowing power as percentage of collateral:

```solidity
// LTV is in basis points (100 = 1%)
// Example: LTV of 8000 = 80%
// Meaning: Can borrow up to 80% of collateral value

// Setting LTV
function configureReserveAsCollateral(
    address asset,
    uint256 ltv,                    // 0-10000 (basis points)
    uint256 liquidationThreshold,   // 0-10000
    uint256 liquidationBonus        // > 10000 (e.g., 10500 = 5% bonus)
) external;
```

### Liquidation Threshold (LT)

When position becomes liquidatable:

```solidity
// LT > LTV always
// Example: LTV = 80%, LT = 82.5%
// User can borrow up to 80% of collateral
// Position becomes liquidatable when debt > 82.5% of collateral value

// Health Factor = Σ(Collateral × LT) / Total Debt
// Liquidatable when HF < 1
```

### Liquidation Bonus (LB)

Incentive for liquidators:

```solidity
// Stored as 100% + bonus percentage
// Example: 10500 = 5% bonus
// Liquidator receives collateral × 1.05

// Max bonus typically 10-15%
// Higher for volatile assets
```

### Reserve Factor

Protocol fee on interest:

```solidity
// Reserve factor in basis points
// Example: 2000 = 20%
// Protocol takes 20% of interest paid by borrowers

function setReserveFactor(address asset, uint256 newReserveFactor) external;
```

### Caps

```solidity
// Supply cap - max tokens that can be supplied
function setSupplyCap(address asset, uint256 newSupplyCap) external;

// Borrow cap - max tokens that can be borrowed
function setBorrowCap(address asset, uint256 newBorrowCap) external;

// Caps are in whole tokens (no decimals)
// 0 = no cap
```

## Interest Rate Strategy

### DefaultReserveInterestRateStrategyV2

Stateful interest rate strategy introduced in V3.1:

```solidity
contract DefaultReserveInterestRateStrategyV2 is IDefaultInterestRateStrategyV2 {
    // Rate parameters stored per asset
    struct InterestRateData {
        uint16 optimalUsageRatio;     // Target utilization (e.g., 80%)
        uint32 baseVariableBorrowRate; // Base rate when utilization = 0
        uint32 variableRateSlope1;    // Rate increase below optimal
        uint32 variableRateSlope2;    // Rate increase above optimal
    }

    mapping(address => InterestRateData) internal _interestRateData;

    function calculateInterestRates(
        DataTypes.CalculateInterestRatesParams memory params
    ) external view returns (uint256 liquidityRate, uint256 variableBorrowRate) {
        // Calculate utilization
        uint256 availableLiquidity = params.usingVirtualBalance
            ? params.virtualUnderlyingBalance
            : params.liquidityAdded - params.liquidityTaken;

        uint256 totalDebt = params.totalDebt;
        uint256 currentUtilization = totalDebt == 0
            ? 0
            : totalDebt.rayDiv(availableLiquidity + totalDebt);

        InterestRateData memory rateData = _interestRateData[params.reserve];

        // Calculate variable borrow rate
        if (currentUtilization <= rateData.optimalUsageRatio) {
            // Below optimal: base + slope1 × (utilization / optimal)
            variableBorrowRate = rateData.baseVariableBorrowRate +
                currentUtilization.rayMul(rateData.variableRateSlope1).rayDiv(rateData.optimalUsageRatio);
        } else {
            // Above optimal: base + slope1 + slope2 × (utilization - optimal) / (1 - optimal)
            uint256 excessUtilization = currentUtilization - rateData.optimalUsageRatio;
            uint256 maxExcessUtilization = WadRayMath.RAY - rateData.optimalUsageRatio;

            variableBorrowRate = rateData.baseVariableBorrowRate +
                rateData.variableRateSlope1 +
                excessUtilization.rayMul(rateData.variableRateSlope2).rayDiv(maxExcessUtilization);
        }

        // Calculate liquidity rate (supply APY)
        // Portion of borrow interest paid to suppliers
        liquidityRate = variableBorrowRate
            .rayMul(currentUtilization)
            .rayMul(WadRayMath.RAY - params.reserveFactor);
    }
}
```

### Interest Rate Curve

```
┌──────────────────────────────────────────────────────────────┐
│                   INTEREST RATE CURVE                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Rate │                                    ╱                 │
│       │                                  ╱   Slope2          │
│       │                                ╱     (steep)         │
│       │                     ╱─────────╱                      │
│       │                   ╱                                  │
│       │                 ╱  Slope1                            │
│       │               ╱    (gentle)                          │
│       │  baseRate   ╱                                        │
│       └─────────────┼───────────────────────────────────────  │
│       0%           Optimal            100%                   │
│                  Utilization                                 │
│                   (80%)                                      │
│                                                              │
│  When utilization exceeds optimal:                           │
│  - Rates increase steeply (Slope2)                           │
│  - Incentivizes repayment and new supply                     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Setting Interest Rate Data

```solidity
// Via PoolConfigurator
function setReserveInterestRateData(
    address asset,
    bytes calldata rateData  // Encoded InterestRateData
) external;

// Or when updating strategy address
function setReserveInterestRateStrategyAddress(
    address asset,
    address rateStrategyAddress,
    bytes calldata rateData
) external;
```

## PoolConfigurator

Admin contract for configuration changes:

```solidity
contract PoolConfigurator is VersionedInitializable, IPoolConfigurator {
    // Access control modifiers
    modifier onlyPoolAdmin() { /* ... */ }
    modifier onlyEmergencyAdmin() { /* ... */ }
    modifier onlyRiskAdmin() { /* ... */ }
    modifier onlyAssetListingAdmin() { /* ... */ }

    // Reserve initialization
    function initReserves(
        ConfiguratorInputTypes.InitReserveInput[] calldata input
    ) external onlyAssetListingAdmin;

    // Collateral configuration
    function configureReserveAsCollateral(
        address asset,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) external onlyRiskAdmin;

    // Enable/disable borrowing
    function setReserveBorrowing(address asset, bool enabled) external onlyRiskAdmin;

    // Freeze/unfreeze (blocks new supply/borrow)
    function setReserveFreeze(address asset, bool freeze) external onlyRiskOrPoolOrEmergencyAdmins;

    // Pause/unpause (blocks all operations)
    function setReservePause(address asset, bool paused) external onlyEmergencyAdmin;
    function setReservePause(address asset, bool paused, uint40 gracePeriod) external onlyEmergencyAdmin;

    // Caps
    function setSupplyCap(address asset, uint256 newSupplyCap) external onlyRiskAdmin;
    function setBorrowCap(address asset, uint256 newBorrowCap) external onlyRiskAdmin;

    // Reserve factor
    function setReserveFactor(address asset, uint256 newReserveFactor) external onlyRiskAdmin;

    // Interest rate
    function setReserveInterestRateData(address asset, bytes calldata rateData) external onlyRiskAdmin;
}
```

## Reserve States

```
┌──────────────────────────────────────────────────────────────┐
│                     RESERVE STATES                           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ACTIVE    - Normal operation                                │
│           - All operations allowed                           │
│                                                              │
│  FROZEN    - No new supply or borrow                         │
│           - Withdrawals and repayments allowed               │
│           - LTV set to 0 (V3.1+)                             │
│                                                              │
│  PAUSED    - All operations blocked                          │
│           - Emergency state                                  │
│           - Can set grace period on unpause                  │
│                                                              │
│  INACTIVE  - Reserve is disabled                             │
│           - Only withdrawals allowed                         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Virtual Accounting (V3.1+)

Tracks actual protocol-held balances:

```solidity
// Enable for new reserves
struct InitReserveInput {
    // ...
    bool useVirtualBalance;  // Should this reserve use virtual accounting
}

// Virtual balance updated on every in/out flow
reserve.virtualUnderlyingBalance += amountIn;
reserve.virtualUnderlyingBalance -= amountOut;

// Used instead of actual token balance for:
// - Interest rate calculation
// - Withdrawal validation
```

## Isolation Mode

Limits risk from new/volatile assets:

```solidity
// Debt ceiling limits total borrowing against isolated collateral
function setDebtCeiling(address asset, uint256 newDebtCeiling) external;

// Enable borrowing in isolation mode
function setBorrowableInIsolation(address asset, bool borrowable) external;

// When using isolated collateral:
// - Only isolation-mode-borrowable assets can be borrowed
// - Total debt limited by debt ceiling
// - Only one isolated asset can be collateral
```

## Siloed Borrowing

Restricts an asset to be the only borrow in a position:

```solidity
// Enable siloed borrowing for asset
function setSiloedBorrowing(address asset, bool siloed) external;

// When borrowing a siloed asset:
// - Cannot have other borrows
// - Cannot borrow other assets while having siloed debt
// Use case: High-risk or volatile assets
```

## Events

```solidity
event ReserveInitialized(address indexed asset, address indexed aToken, address variableDebtToken, address interestRateStrategyAddress);
event CollateralConfigurationChanged(address indexed asset, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus);
event BorrowingEnabledOnReserve(address indexed asset);
event BorrowingDisabledOnReserve(address indexed asset);
event ReserveActive(address indexed asset, bool active);
event ReserveFrozen(address indexed asset, bool frozen);
event ReservePaused(address indexed asset, bool paused);
event ReserveFactorChanged(address indexed asset, uint256 oldReserveFactor, uint256 newReserveFactor);
event BorrowCapChanged(address indexed asset, uint256 oldBorrowCap, uint256 newBorrowCap);
event SupplyCapChanged(address indexed asset, uint256 oldSupplyCap, uint256 newSupplyCap);
event DebtCeilingChanged(address indexed asset, uint256 oldDebtCeiling, uint256 newDebtCeiling);
event ReserveInterestRateDataChanged(address indexed asset, address indexed strategy, bytes data);
```

## Reference Files

- `src/contracts/protocol/pool/PoolConfigurator.sol` - Configuration contract
- `src/contracts/protocol/pool/DefaultReserveInterestRateStrategyV2.sol` - Interest rate strategy
- `@crane/contracts/external/aave-v3-origin/contracts/protocol/libraries/configuration/ReserveConfiguration.sol` - Bitmap library
- `src/contracts/protocol/libraries/logic/ConfiguratorLogic.sol` - Configuration logic
- `src/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol` - Input types
