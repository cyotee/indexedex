---
name: EVK Liquidation
description: This skill should be used when the user asks about "liquidate", "liquidation", "unhealthy", "underwater", "violator", "seize", "discount", "bad debt", or needs to understand EVault liquidation mechanics.
version: 0.1.0
---

# EVK Liquidation

EVaults implement a sophisticated liquidation mechanism using the EVC's controlCollateral feature. Liquidators repay debt and receive collateral at a discount.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                   LIQUIDATION FLOW                           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Violator Account (Unhealthy)                                │
│  ├── Collateral: Vault A (e.g., 1000 ETH shares)             │
│  ├── Controller: Vault B (e.g., USDC debt vault)             │
│  └── Health: collateralValue < debtValue                     │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Liquidation Process                        │ │
│  │                                                         │ │
│  │  1. Liquidator calls vault.liquidate()                  │ │
│  │     ├── repayAssets: amount of debt to repay            │ │
│  │     ├── collateral: which collateral vault to seize     │ │
│  │     └── minYieldBalance: min collateral to receive      │ │
│  │                                                         │ │
│  │  2. Vault calculates:                                   │ │
│  │     ├── Discount based on violator health               │ │
│  │     ├── Collateral to seize (repay + discount)          │ │
│  │     └── Debt reduction                                  │ │
│  │                                                         │ │
│  │  3. Via EVC.controlCollateral():                        │ │
│  │     └── Collateral transferred to liquidator            │ │
│  │                                                         │ │
│  │  4. Debt reduced, violator health improved              │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Liquidation Configuration

```solidity
// RiskManager.sol - LTV configuration

struct LTVConfig {
    uint16 borrowLTV;           // Max LTV for borrowing (e.g., 80%)
    uint16 liquidationLTV;      // LTV threshold for liquidation (e.g., 85%)
    uint16 initialLiquidationLTV;  // Starting LTV during ramp
    uint48 targetTimestamp;     // When ramp completes
    uint32 rampDuration;        // Ramp period for LTV changes
}

// Per-collateral LTV settings
mapping(address collateral => LTVConfig) internal ltvLookup;

// Vault-level liquidation settings
uint16 public maxLiquidationDiscount;  // Max discount for liquidators (e.g., 15%)
uint16 public liquidationCoolOffTime;  // Delay between partial liquidations

/// @notice Set LTV for a collateral
function setLTV(
    address collateral,
    uint16 borrowLTV,
    uint16 liquidationLTV,
    uint32 rampDuration
) external onlyGovernor {
    // borrowLTV must be <= liquidationLTV
    require(borrowLTV <= liquidationLTV, "Invalid LTV");

    LTVConfig memory config;
    config.borrowLTV = borrowLTV;
    config.liquidationLTV = liquidationLTV;
    config.rampDuration = rampDuration;
    // ... set target timestamp for ramp

    ltvLookup[collateral] = config;
}
```

## Health Calculation

```solidity
// Check if account is liquidatable

/// @notice Get account health factor
/// @dev Returns liability value and collateral value adjusted by liquidation LTV
function checkAccountHealth(address account) public view returns (
    uint256 liabilityValue,
    uint256 collateralValueLiquidation
) {
    // Get debt in unit of account
    uint256 debtAssets = debtOf(account);
    if (debtAssets == 0) return (0, type(uint256).max);

    liabilityValue = oracle.getQuote(debtAssets, asset(), unitOfAccount);

    // Get collateral values with liquidation LTV haircut
    address[] memory collaterals = evc.getCollaterals(account);

    for (uint i = 0; i < collaterals.length; i++) {
        address collateral = collaterals[i];
        LTVConfig memory ltv = ltvLookup[collateral];

        if (ltv.liquidationLTV == 0) continue;

        uint256 balance = IEVault(collateral).balanceOf(account);
        if (balance == 0) continue;

        uint256 value = oracle.getQuote(
            IEVault(collateral).convertToAssets(balance),
            IEVault(collateral).asset(),
            unitOfAccount
        );

        // Apply liquidation LTV (higher than borrow LTV)
        collateralValueLiquidation += value * ltv.liquidationLTV / 1e18;
    }
}

/// @notice Check if account is unhealthy
function isAccountUnhealthy(address account) public view returns (bool) {
    (uint256 liability, uint256 collateral) = checkAccountHealth(account);
    return collateral < liability;
}
```

## Liquidation Discount

```solidity
// Discount scales with how unhealthy the account is

/// @notice Calculate liquidation discount based on health
function calculateDiscount(
    uint256 liabilityValue,
    uint256 collateralValue
) internal view returns (uint256 discount) {
    if (collateralValue >= liabilityValue) {
        // Healthy - no liquidation possible
        return 0;
    }

    // Health factor = collateral / liability (< 1 when unhealthy)
    uint256 healthFactor = collateralValue * 1e18 / liabilityValue;

    // Discount increases as health decreases
    // At health = 1: discount = 0
    // At health = 0: discount = maxLiquidationDiscount

    discount = maxLiquidationDiscount * (1e18 - healthFactor) / 1e18;

    // Cap at max
    if (discount > maxLiquidationDiscount) {
        discount = maxLiquidationDiscount;
    }
}
```

## Liquidate Function

```solidity
/// @notice Liquidate an unhealthy account
/// @param violator Account to liquidate
/// @param collateral Collateral vault to seize from
/// @param repayAssets Amount of debt to repay
/// @param minYieldBalance Minimum collateral shares to receive
function liquidate(
    address violator,
    address collateral,
    uint256 repayAssets,
    uint256 minYieldBalance
) external virtual use(MODULE_LIQUIDATION) {}

// In Liquidation.sol module
function liquidate(
    address violator,
    address collateral,
    uint256 repayAssets,
    uint256 minYieldBalance
) external {
    VaultCache memory cache = initOperation(OP_LIQUIDATE);

    address liquidator = msgSender();

    // 1. Verify violator is unhealthy
    (uint256 liabilityValue, uint256 collateralValue) = checkAccountHealth(violator);
    if (collateralValue >= liabilityValue) revert HealthyAccount();

    // 2. Calculate discount
    uint256 discount = calculateDiscount(liabilityValue, collateralValue);

    // 3. Get collateral configuration
    LTVConfig memory ltvConfig = ltvLookup[collateral];
    if (ltvConfig.liquidationLTV == 0) revert InvalidCollateral();

    // 4. Calculate repay value in unit of account
    uint256 repayValue = oracle.getQuote(repayAssets, asset(), unitOfAccount);

    // 5. Calculate collateral to seize (repay value + discount)
    uint256 seizeValue = repayValue * (1e18 + discount) / 1e18;

    // Convert to collateral assets
    uint256 seizeAssets = oracle.getQuote(
        seizeValue,
        unitOfAccount,
        IEVault(collateral).asset()
    );

    // Convert to collateral shares
    uint256 seizeShares = IEVault(collateral).convertToShares(seizeAssets);

    // 6. Verify minimum yield
    if (seizeShares < minYieldBalance) revert InsufficientYield();

    // 7. Cap at violator's balance
    uint256 violatorBalance = IEVault(collateral).balanceOf(violator);
    if (seizeShares > violatorBalance) {
        seizeShares = violatorBalance;
        // Recalculate repay amount based on available collateral
        seizeAssets = IEVault(collateral).convertToAssets(seizeShares);
        seizeValue = oracle.getQuote(seizeAssets, IEVault(collateral).asset(), unitOfAccount);
        repayValue = seizeValue * 1e18 / (1e18 + discount);
        repayAssets = oracle.getQuote(repayValue, unitOfAccount, asset());
    }

    // 8. Reduce violator's debt
    reduceDebt(cache, violator, repayAssets);

    // 9. Transfer underlying from liquidator
    asset().safeTransferFrom(liquidator, address(this), repayAssets);
    cache.cash += repayAssets;

    // 10. Seize collateral via EVC
    // This uses controlCollateral to transfer from violator to liquidator
    bytes memory transferCall = abi.encodeCall(
        IERC20.transfer,
        (liquidator, seizeShares)
    );

    evc.controlCollateral(collateral, violator, 0, transferCall);

    updateVault(cache);

    // 11. Schedule status checks
    requireAccountStatusCheck(violator);
    requireAccountStatusCheck(liquidator);  // Liquidator might be borrower too
    requireVaultStatusCheck();

    emit Liquidate(liquidator, violator, collateral, repayAssets, seizeShares);
}
```

## Control Collateral (EVC)

```solidity
// EVC.sol - Enables controller to seize collateral

/// @notice Controller vault seizes collateral during liquidation
function controlCollateral(
    address collateralVault,
    address onBehalfOfAccount,
    uint256 value,
    bytes calldata data
) external payable returns (bytes memory) {
    // Only enabled controller can call
    if (!isControllerEnabled(onBehalfOfAccount, msg.sender)) {
        revert ControllerNotEnabled();
    }

    // Set control collateral flag
    executionContext.controlCollateralInProgress = true;

    // Execute call on collateral vault (e.g., transfer)
    (bool success, bytes memory result) = collateralVault.call{value: value}(data);

    executionContext.controlCollateralInProgress = false;

    if (!success) revert ControlCollateralFailed();

    return result;
}

// In collateral vault - allows transfer when controlCollateral in progress
function transfer(address to, uint256 amount) external returns (bool) {
    address from = msgSender();  // Will be violator during liquidation

    // Allow if EVC control collateral is in progress
    if (evc.isControlCollateralInProgress()) {
        // Controller is authorized to transfer on violator's behalf
        _transfer(from, to, amount);
        return true;
    }

    // Normal transfer logic...
}
```

## Bad Debt Handling

```solidity
// When collateral < debt, bad debt is socialized

/// @notice Socialize bad debt from insolvent account
function socializeLoss(address account) external {
    VaultCache memory cache = initOperation(OP_SOCIALIZE_LOSS);

    // Check account has debt but no collateral
    uint256 debt = debtOf(account);
    if (debt == 0) revert NoDebt();

    address[] memory collaterals = evc.getCollaterals(account);
    for (uint i = 0; i < collaterals.length; i++) {
        if (IEVault(collaterals[i]).balanceOf(account) > 0) {
            revert HasCollateral();  // Must liquidate first
        }
    }

    // Socialize the loss - reduce total borrows without repayment
    // This dilutes existing suppliers
    cache.totalBorrows -= debt;

    // Clear user debt
    users[account].borrowed = 0;

    updateVault(cache);

    emit SocializeLoss(account, debt);
}
```

## Liquidation Incentives

```solidity
// Liquidation profitability calculation

// Example scenario:
// - Violator has 100 ETH collateral worth $200,000
// - Violator has $180,000 USDC debt
// - Liquidation LTV is 85%, so threshold is $170,000 collateral value
// - Account is unhealthy: $200k * 85% = $170k < $180k debt

// Health factor = $170,000 / $180,000 = 0.944
// With maxLiquidationDiscount = 15%:
// Discount = 15% * (1 - 0.944) = 0.84%

// Liquidator repays $10,000 of debt
// Receives $10,084 worth of ETH (0.84% profit on this liquidation)

// As account becomes more unhealthy, discount increases:
// At health 0.8: discount = 15% * 0.2 = 3%
// At health 0.5: discount = 15% * 0.5 = 7.5%
// At health 0: discount = 15%
```

## Vault Status Check

```solidity
/// @notice Check vault-level invariants
function checkVaultStatus() external view returns (bytes4) {
    VaultCache memory cache = loadVault();

    // Check supply cap
    if (cache.totalShares > supplyCap()) {
        revert SupplyCapExceeded();
    }

    // Check borrow cap
    if (cache.totalBorrows > borrowCap()) {
        revert BorrowCapExceeded();
    }

    return VAULT_STATUS_CHECK_SELECTOR;
}
```

## Events

```solidity
event Liquidate(
    address indexed liquidator,
    address indexed violator,
    address indexed collateral,
    uint256 repayAssets,
    uint256 yieldBalance
);

event SocializeLoss(address indexed account, uint256 lossAmount);
```

## Reference Files

- `euler-vault-kit/src/EVault/modules/Liquidation.sol` - Liquidation module
- `euler-vault-kit/src/EVault/shared/LiquidityUtils.sol` - Liquidity calculations
- `ethereum-vault-connector/src/EthereumVaultConnector.sol` - controlCollateral
