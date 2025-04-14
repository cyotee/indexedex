---
name: resupply-liquidation
description: This skill should be used when the user asks about "liquidation", "LiquidationHandler", "liquidate position", "bad debt", "underwater position", "liquidation fee", "collateral seizure", or needs to understand how Resupply handles undercollateralized positions.
---

# Resupply Liquidation System

The liquidation system protects the protocol from bad debt by allowing third parties to liquidate undercollateralized positions. Located in `/src/protocol/LiquidationHandler.sol` and pair contracts.

## Liquidation Mechanics

### When Positions Become Liquidatable

A position becomes liquidatable when the borrow value exceeds the allowed LTV:

```solidity
function _isSolvent(address _borrower) internal view returns (bool) {
    uint256 collateralValue = getCollateralValue(_borrower);
    uint256 borrowValue = getBorrowValue(_borrower);

    // Liquidatable when: borrowValue > collateralValue * maxLTV / LTV_PRECISION
    return borrowValue * LTV_PRECISION <= collateralValue * maxLTV;
}
```

**Example with 95% maxLTV:**
- Collateral value: 1000 reUSD
- Max borrow: 950 reUSD (95%)
- If debt grows to 960 reUSD → position is liquidatable

### Pair-Level Liquidation

The basic liquidation function in ResupplyPair:

```solidity
function liquidate(address _borrower) external returns (uint256 collateralForLiquidator) {
    require(!_isSolvent(_borrower), "Position is healthy");

    // Get borrower's debt
    uint256 borrowShares = userBorrowShares[_borrower];
    uint256 borrowAmount = (borrowShares * totalBorrowAmount) / totalBorrowShares;

    // Calculate collateral to seize (includes liquidation fee)
    uint256 collateralSeized = _calculateCollateralSeized(borrowAmount);

    // Clear borrower's position
    userBorrowShares[_borrower] = 0;
    totalBorrowShares -= borrowShares;
    totalBorrowAmount -= borrowAmount;

    userCollateralBalance[_borrower] -= collateralSeized;
    totalCollateral -= collateralSeized;

    // Transfer collateral to liquidator
    IERC20(collateralContract).safeTransfer(msg.sender, collateralForLiquidator);

    // Liquidator must repay the debt
    IStablecoin(asset).burn(msg.sender, borrowAmount);
}
```

### Collateral Calculation

Liquidators receive collateral worth more than the debt they repay:

```solidity
function _calculateCollateralSeized(uint256 borrowAmount) internal view returns (uint256) {
    uint256 collateralPrice = oracle.getPrice(collateralContract);

    // Base collateral needed
    uint256 baseCollateral = (borrowAmount * EXCHANGE_PRECISION) / collateralPrice;

    // Add liquidation fee (e.g., 5%)
    uint256 withFee = baseCollateral + (baseCollateral * liquidationFee / LTV_PRECISION);

    return withFee;
}
```

## LiquidationHandler Contract

The centralized liquidation handler (`/src/protocol/LiquidationHandler.sol`) provides advanced liquidation features:

```solidity
contract LiquidationHandler {
    uint256 public collateralIncentive;  // Default: 25e18 (reward for liquidators)

    // Process liquidation with incentive
    function liquidate(
        address _pair,
        address _borrower
    ) external returns (uint256 collateralReceived);

    // Handle bad debt scenarios
    function handleBadDebt(
        address _pair,
        address _borrower,
        uint256 _badDebtAmount
    ) external;
}
```

### Liquidation Flow

1. **Check solvency**: Verify position is underwater
2. **Calculate amounts**: Determine debt and collateral to seize
3. **Seize collateral**: Transfer to liquidator with incentive
4. **Repay debt**: Liquidator burns reUSD
5. **Handle remainder**: Bad debt goes to insurance pool if any

## Bad Debt Handling

When collateral is insufficient to cover debt:

```solidity
function handleBadDebt(address _pair, address _borrower, uint256 _badDebtAmount) external {
    // Route bad debt to insurance pool
    IInsurancePool(insurancePool).coverBadDebt(_badDebtAmount);

    // Clear remaining position
    IResupplyPair(_pair).clearBadDebtPosition(_borrower);
}
```

**Insurance pool coverage:**
```solidity
function coverBadDebt(uint256 amount) external {
    // Burn reUSD from insurance pool reserves
    // Or mark as protocol loss if insufficient reserves
    if (totalAssets() >= amount) {
        IStablecoin(asset).burn(address(this), amount);
    } else {
        protocolLoss += amount - totalAssets();
    }
}
```

## Liquidation Parameters

Key configuration values:

| Parameter | Typical Value | Description |
|-----------|---------------|-------------|
| `maxLTV` | 95_000 (95%) | Maximum loan-to-value before liquidation |
| `liquidationFee` | 5_000 (5%) | Bonus collateral for liquidators |
| `collateralIncentive` | 25e18 | Fixed incentive amount |

## Partial vs Full Liquidation

Resupply uses **full liquidation** - the entire position is liquidated when underwater:

```solidity
// Full position liquidation
uint256 borrowShares = userBorrowShares[_borrower];  // All shares
userBorrowShares[_borrower] = 0;                      // Clear completely
```

This simplifies accounting and ensures positions are fully cleared.

## Liquidator Requirements

To liquidate a position:

1. **Hold sufficient reUSD**: Must repay the borrower's full debt
2. **Call liquidate()**: On either pair or LiquidationHandler
3. **Receive collateral**: Get collateral + liquidation fee

```solidity
// Liquidator flow
IERC20(reUSD).approve(pair, borrowAmount);
uint256 collateralReceived = IResupplyPair(pair).liquidate(borrower);
// collateralReceived > borrowAmount value due to liquidation fee
```

## Oracle Dependency

Liquidations depend on accurate price feeds:

```solidity
// BasicVaultOracle returns ERC4626 share price
function getPrice(address vault) external view returns (uint256) {
    return IERC4626(vault).convertToAssets(1e18);
}
```

**Risk consideration**: Oracle manipulation could enable unfair liquidations or prevent legitimate ones.

## Events

Monitor liquidation activity:

```solidity
event Liquidate(
    address indexed borrower,
    address indexed liquidator,
    uint256 debtRepaid,
    uint256 collateralSeized
);

event BadDebt(
    address indexed pair,
    address indexed borrower,
    uint256 badDebtAmount
);
```

