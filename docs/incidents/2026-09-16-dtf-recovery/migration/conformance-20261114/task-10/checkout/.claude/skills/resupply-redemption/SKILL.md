---
name: resupply-redemption
description: This skill should be used when the user asks about "redemption", "redeem collateral", "RedemptionHandler", "redemption fees", "dynamic fees", "arbitrage reUSD", or needs to understand Resupply's collateral redemption mechanism.
---

# Resupply Redemption System

The redemption system allows reUSD holders to redeem their stablecoins for collateral from lending pairs, providing a price floor mechanism and arbitrage opportunity. Located in `/src/protocol/RedemptionHandler.sol`.

## Redemption Concept

Redemption enables reUSD holders to exchange reUSD directly for collateral from borrowers' positions:

```
reUSD holder → RedemptionHandler → Collateral from pair
                    ↓
              Borrower's debt reduced
```

This creates a price floor for reUSD at approximately $1 minus fees.

## RedemptionHandler Contract

```solidity
contract RedemptionHandler {
    // Fee configuration
    uint256 public baseRedemptionFee;      // e.g., 1e16 (1%)
    uint256 public protocolRedemptionFee;  // Protocol's share of fees

    // Usage tracking for dynamic fees
    mapping(address pair => uint256) public pairRedemptionUsage;
    uint256 public totalRedemptionUsage;

    // Main redemption function
    function redeemCollateral(
        address _caller,
        uint256 _amount,
        address _pair,
        uint256 _minCollateralReceived
    ) external returns (uint256 collateralReceived);
}
```

## Redemption Flow

### Step-by-Step Process

```solidity
function redeemCollateral(
    address _caller,
    uint256 _amount,
    address _pair,
    uint256 _minCollateralReceived
) external returns (uint256 collateralReceived) {
    // 1. Calculate dynamic fee based on utilization
    uint256 fee = calculateRedemptionFee(_pair, _amount);

    // 2. Calculate collateral to receive (minus fee)
    uint256 redeemValue = _amount - (_amount * fee / 1e18);
    collateralReceived = convertToCollateral(_pair, redeemValue);

    // 3. Verify minimum received
    require(collateralReceived >= _minCollateralReceived, "Slippage exceeded");

    // 4. Burn reUSD from caller
    IStablecoin(asset).burn(_caller, _amount);

    // 5. Reduce borrower debt (picks from highest utilization positions)
    _reduceDebtFromPair(_pair, _amount);

    // 6. Transfer collateral to caller
    IResupplyPair(_pair).transferCollateralOut(_caller, collateralReceived);

    // 7. Update usage tracking
    pairRedemptionUsage[_pair] += _amount;
    totalRedemptionUsage += _amount;
}
```

## Dynamic Fee System

Redemption fees adjust based on pair utilization and redemption frequency:

### Base Fee Calculation

```solidity
function calculateRedemptionFee(address _pair, uint256 _amount) public view returns (uint256) {
    uint256 fee = baseRedemptionFee;  // Start with base (e.g., 1%)

    // Adjust based on pair utilization
    uint256 utilization = getPairUtilization(_pair);
    if (utilization > TARGET_UTILIZATION) {
        // Higher fee when pair is heavily utilized
        fee += (utilization - TARGET_UTILIZATION) * UTILIZATION_MULTIPLIER;
    }

    // Adjust based on redemption frequency
    uint256 recentRedemptions = getRecentRedemptions(_pair);
    if (recentRedemptions > REDEMPTION_THRESHOLD) {
        // Higher fee when redemptions are frequent
        fee += OVERUSAGE_PENALTY;
    }

    return fee;
}
```

### Fee Components

| Component | Description | Typical Value |
|-----------|-------------|---------------|
| `baseRedemptionFee` | Minimum fee | 1% (1e16) |
| `utilizationPremium` | Added when utilization high | 0-2% |
| `overusagePenalty` | Added when redemptions frequent | 0-1% |
| `protocolRedemptionFee` | Protocol's share | 20% of fees |

### Fee Distribution

```solidity
function _distributeFees(uint256 totalFee) internal {
    uint256 protocolShare = totalFee * protocolRedemptionFee / 1e18;
    uint256 stakerShare = totalFee - protocolShare;

    // Protocol share to treasury
    IStablecoin(asset).transfer(feeReceiver, protocolShare);

    // Staker share to reward distribution
    IRewardHandler(rewardHandler).notifyReward(stakerShare);
}
```

## Position Selection

Redemptions target positions with highest utilization first:

```solidity
function _selectPositionToRedeem(address _pair) internal view returns (address borrower) {
    // Sort borrowers by utilization (debt/collateral ratio)
    // Redeem from highest utilization positions first
    // This protects healthier positions
}
```

## Redemption Limits

Pairs can set redemption limits to prevent excessive collateral drain:

```solidity
// Per-epoch redemption limits
uint256 public maxRedemptionPerEpoch;
mapping(uint256 epoch => uint256 redeemed) public epochRedemptions;

function redeemCollateral(...) external {
    uint256 currentEpoch = getEpoch();
    require(
        epochRedemptions[currentEpoch] + _amount <= maxRedemptionPerEpoch,
        "Epoch redemption limit exceeded"
    );
    epochRedemptions[currentEpoch] += _amount;
    // ... continue redemption
}
```

## Arbitrage Opportunity

Redemptions create arbitrage when reUSD trades below $1:

```
Market price: $0.98 reUSD
Redemption: 1 reUSD → ~$0.99 collateral (after 1% fee)
Profit: ~$0.01 per reUSD redeemed
```

**Arbitrage flow:**
1. Buy reUSD at $0.98 on DEX
2. Redeem for ~$0.99 collateral
3. Sell collateral for ~$0.99
4. Profit: ~1%

This mechanism helps maintain reUSD's peg.

## Affected Borrowers

When a position is redeemed against:

```solidity
function _reduceDebtFromPair(address _pair, uint256 _redeemAmount) internal {
    address borrower = _selectPositionToRedeem(_pair);

    // Reduce borrower's debt
    uint256 shares = IResupplyPair(_pair).getSharesFromAmount(_redeemAmount);
    IResupplyPair(_pair).reduceDebt(borrower, shares);

    // Reduce borrower's collateral proportionally
    uint256 collateralReduced = _calculateCollateralReduced(_redeemAmount);
    IResupplyPair(_pair).reduceCollateral(borrower, collateralReduced);
}
```

**Borrower impact:**
- Debt reduced by redemption amount
- Collateral reduced proportionally
- LTV ratio unchanged (neutral to borrower)

## Events

```solidity
event Redemption(
    address indexed redeemer,
    address indexed pair,
    uint256 amountRedeemed,
    uint256 collateralReceived,
    uint256 feesPaid
);

event RedemptionFeeUpdated(
    uint256 oldFee,
    uint256 newFee
);
```

