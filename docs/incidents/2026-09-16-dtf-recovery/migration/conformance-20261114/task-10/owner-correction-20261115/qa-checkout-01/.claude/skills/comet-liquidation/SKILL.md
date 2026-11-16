---
name: Comet Liquidation
description: This skill should be used when the user asks about "liquidation", "absorb", "absorbInternal", "buyCollateral", "quoteCollateral", "protocol reserves", "storeFrontPriceFactor", or needs to understand Comet's liquidation mechanics.
version: 0.1.0
---

# Comet Liquidation System

Comet uses an "absorb" model where the protocol takes over underwater accounts, moving collateral to protocol reserves. Anyone can then buy this collateral at a discount using base tokens.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                   LIQUIDATION FLOW                           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Step 1: Absorb (Protocol takes collateral + debt)           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                                                         │ │
│  │  Underwater Account                Protocol Reserves     │ │
│  │  ┌────────────────┐               ┌────────────────┐    │ │
│  │  │ Collateral: $X │ ──absorb()──► │ Collateral: +X │    │ │
│  │  │ Debt: $Y       │               │ Reserves: -Y    │    │ │
│  │  └────────────────┘               └────────────────┘    │ │
│  │                                                         │ │
│  │  Account zeroed out; debt covered by reserves           │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Step 2: Buy Collateral (Buyers purchase at discount)        │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                                                         │ │
│  │  Buyer                          Protocol                 │ │
│  │  ┌────────────────┐            ┌────────────────┐       │ │
│  │  │ Base Tokens    │ ─payBuy──► │ Base Tokens    │       │ │
│  │  │                │ ◄─collat── │ Collateral -   │       │ │
│  │  │ Collateral +   │            │                │       │ │
│  │  └────────────────┘            └────────────────┘       │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Absorb Function

```solidity
/// @notice Absorb underwater accounts onto protocol balance sheet
/// @param absorber The address receiving liquidation points
/// @param accounts List of underwater accounts to absorb
function absorb(address absorber, address[] calldata accounts) external {
    if (isAbsorbPaused()) revert Paused();

    uint startGas = gasleft();
    accrueInternal();

    for (uint i = 0; i < accounts.length; ) {
        absorbInternal(absorber, accounts[i]);
        unchecked { i++; }
    }

    uint gasUsed = startGas - gasleft();

    // Track liquidator points for potential rewards
    LiquidatorPoints memory points = liquidatorPoints[absorber];
    points.numAbsorbs++;
    points.numAbsorbed += safe64(accounts.length);
    points.approxSpend += safe128(gasUsed * block.basefee);
    liquidatorPoints[absorber] = points;
}
```

## Absorb Internal Logic

```solidity
/// @dev Transfer account's collateral and debt to protocol
function absorbInternal(address absorber, address account) internal {
    // Must be liquidatable
    if (!isLiquidatable(account)) revert NotLiquidatable();

    UserBasic memory accountUser = userBasic[account];
    int104 oldPrincipal = accountUser.principal;
    int256 oldBalance = presentValue(oldPrincipal);  // Negative (debt)
    uint16 assetsIn = accountUser.assetsIn;

    uint256 basePrice = getPrice(baseTokenPriceFeed);
    uint256 deltaValue = 0;

    // Seize all collateral
    for (uint8 i = 0; i < numAssets; ) {
        if (isInAsset(assetsIn, i)) {
            AssetInfo memory assetInfo = getAssetInfo(i);
            address asset = assetInfo.asset;
            uint128 seizeAmount = userCollateral[account][asset].balance;

            // Transfer collateral to protocol reserves
            userCollateral[account][asset].balance = 0;
            totalsCollateral[asset].totalSupplyAsset -= seizeAmount;

            // Calculate value with liquidation factor
            uint256 value = mulPrice(seizeAmount, getPrice(assetInfo.priceFeed), assetInfo.scale);
            deltaValue += mulFactor(value, assetInfo.liquidationFactor);

            emit AbsorbCollateral(absorber, account, asset, seizeAmount, value);
        }
        unchecked { i++; }
    }

    // Calculate new balance
    uint256 deltaBalance = divPrice(deltaValue, basePrice, uint64(baseScale));
    int256 newBalance = oldBalance + signed256(deltaBalance);

    // Cap at zero - excess debt absorbed by reserves
    if (newBalance < 0) {
        newBalance = 0;
    }

    // Update account
    int104 newPrincipal = principalValue(newBalance);
    updateBasePrincipal(account, accountUser, newPrincipal);
    userBasic[account].assetsIn = 0;  // Clear all asset flags

    // Update global totals
    (uint104 repayAmount, uint104 supplyAmount) = repayAndSupplyAmount(oldPrincipal, newPrincipal);
    totalSupplyBase += supplyAmount;
    totalBorrowBase -= repayAmount;

    uint256 basePaidOut = unsigned256(newBalance - oldBalance);
    uint256 valueOfBasePaidOut = mulPrice(basePaidOut, basePrice, uint64(baseScale));
    emit AbsorbDebt(absorber, account, basePaidOut, valueOfBasePaidOut);
}
```

## Buy Collateral

```solidity
/// @notice Buy collateral from protocol reserves at a discount
/// @param asset The collateral to buy
/// @param minAmount Minimum collateral to receive (slippage protection)
/// @param baseAmount Base tokens to pay
/// @param recipient Address to receive collateral
function buyCollateral(
    address asset,
    uint minAmount,
    uint baseAmount,
    address recipient
) external nonReentrant {
    if (isBuyPaused()) revert Paused();

    // Can only buy when reserves are below target
    int reserves = getReserves();
    if (reserves >= 0 && uint(reserves) >= targetReserves) revert NotForSale();

    // Transfer base tokens in
    baseAmount = doTransferIn(baseToken, msg.sender, baseAmount);

    // Calculate collateral amount
    uint collateralAmount = quoteCollateral(asset, baseAmount);
    if (collateralAmount < minAmount) revert TooMuchSlippage();
    if (collateralAmount > getCollateralReserves(asset)) revert InsufficientReserves();

    // Transfer collateral out
    doTransferOut(asset, recipient, safe128(collateralAmount));

    emit BuyCollateral(msg.sender, asset, baseAmount, collateralAmount);
}
```

## Quote Collateral (Discount Calculation)

```solidity
/// @notice Get collateral amount for a given base amount
/// @param asset The collateral asset
/// @param baseAmount The base tokens to pay
function quoteCollateral(address asset, uint baseAmount) public view returns (uint) {
    AssetInfo memory assetInfo = getAssetInfoByAddress(asset);
    uint256 assetPrice = getPrice(assetInfo.priceFeed);

    // Discount formula:
    // discount = storeFrontPriceFactor × (1 - liquidationFactor)
    uint256 discountFactor = mulFactor(
        storeFrontPriceFactor,
        FACTOR_SCALE - assetInfo.liquidationFactor
    );
    uint256 assetPriceDiscounted = mulFactor(assetPrice, FACTOR_SCALE - discountFactor);

    // Collateral amount = (basePrice × baseAmount) / discountedAssetPrice × assetScale
    uint256 basePrice = getPrice(baseTokenPriceFeed);
    return basePrice * baseAmount * assetInfo.scale / assetPriceDiscounted / baseScale;
}
```

## Discount Math Example

```
┌──────────────────────────────────────────────────────────────┐
│              COLLATERAL DISCOUNT CALCULATION                 │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Given:                                                      │
│  - liquidationFactor = 93% (0.93e18)                         │
│  - storeFrontPriceFactor = 70% (0.7e18)                      │
│  - Asset price = $2000                                       │
│  - Base amount = 1000 USDC                                   │
│                                                              │
│  Calculation:                                                │
│  1. Penalty from liquidation = 1 - 0.93 = 7%                 │
│  2. Discount factor = 0.7 × 0.07 = 4.9%                      │
│  3. Discounted price = $2000 × (1 - 0.049) = $1902           │
│  4. Collateral received = 1000 / 1902 = 0.526 units          │
│                                                              │
│  Buyer pays 1000 USDC → Gets 0.526 units ($1052 at market)   │
│  Profit = 5.2% discount on collateral                        │
│                                                              │
│  Note: storeFrontPriceFactor controls discount distribution  │
│        70% = 70% of penalty goes to buyers (4.9% discount)   │
│        30% = 30% of penalty kept by protocol (2.1% revenue)  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Protocol Reserves

```solidity
/// @notice Get protocol's base token reserves
function getReserves() public view returns (int) {
    (uint64 baseSupplyIndex_, uint64 baseBorrowIndex_) =
        accruedInterestIndices(getNowInternal() - lastAccrualTime);

    uint balance = IERC20NonStandard(baseToken).balanceOf(address(this));
    uint totalSupply_ = presentValueSupply(baseSupplyIndex_, totalSupplyBase);
    uint totalBorrow_ = presentValueBorrow(baseBorrowIndex_, totalBorrowBase);

    // Reserves = balance - deposits + loans
    return signed256(balance) - signed256(totalSupply_) + signed256(totalBorrow_);
}

/// @notice Get protocol's collateral reserves
function getCollateralReserves(address asset) public view returns (uint) {
    return IERC20NonStandard(asset).balanceOf(address(this)) -
           totalsCollateral[asset].totalSupplyAsset;
}
```

## Target Reserves

```solidity
// When reserves exceed target, collateral is not for sale
uint public immutable targetReserves;

// In buyCollateral:
if (reserves >= 0 && uint(reserves) >= targetReserves) revert NotForSale();
```

## Withdraw Reserves (Governor Only)

```solidity
/// @notice Governor can withdraw excess reserves
function withdrawReserves(address to, uint amount) external {
    if (msg.sender != governor) revert Unauthorized();

    int reserves = getReserves();
    if (reserves < 0 || amount > unsigned256(reserves)) revert InsufficientReserves();

    doTransferOut(baseToken, to, amount);

    emit WithdrawReserves(to, amount);
}
```

## Liquidator Points

```solidity
struct LiquidatorPoints {
    uint32 numAbsorbs;      // Number of absorb calls
    uint64 numAbsorbed;     // Number of accounts absorbed
    uint128 approxSpend;    // Approximate gas spent (gas × basefee)
    uint32 _reserved;
}

mapping(address => LiquidatorPoints) public liquidatorPoints;

// Points can be used for future liquidator rewards/incentives
```

## On-Chain Liquidator

The protocol includes an on-chain liquidator that can:
1. Flash loan base tokens
2. Absorb underwater accounts
3. Buy collateral at discount
4. Swap collateral for base tokens
5. Repay flash loan with profit

```solidity
// contracts/liquidator/OnChainLiquidator.sol
function absorbAndArbitrage(
    address comet,
    address[] calldata liquidatableAccounts,
    address[] calldata assets,
    PoolConfig[] calldata poolConfigs,
    uint[] calldata maxAmountsToPurchase,
    address flashLoanPairToken,
    uint24 flashLoanPoolFee,
    uint liquidationThreshold
) external;
```

## Events

```solidity
event AbsorbCollateral(
    address indexed absorber,
    address indexed borrower,
    address indexed asset,
    uint128 collateralAbsorbed,
    uint usdValue
);

event AbsorbDebt(
    address indexed absorber,
    address indexed borrower,
    uint basePaidOut,
    uint usdValue
);

event BuyCollateral(
    address indexed buyer,
    address indexed asset,
    uint baseAmount,
    uint collateralAmount
);

event WithdrawReserves(address indexed to, uint amount);
```

## Reference Files

- `contracts/Comet.sol:1153-1266` - absorb, absorbInternal, buyCollateral
- `contracts/Comet.sol:1268-1302` - quoteCollateral, withdrawReserves
- `contracts/Comet.sol:504-517` - getReserves, getCollateralReserves
- `contracts/liquidator/OnChainLiquidator.sol` - Automated liquidation
