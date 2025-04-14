---
name: Balancer V3 RECLAMM Pool
description: This skill should be used when the user asks about "RECLAMM", "ReClammPool", "regenerating concentrated liquidity", "virtual balances", "price range tracking", "centeredness", "dailyPriceShiftExponent", "price ratio update", or needs to understand Balancer V3 RECLAMM Pool implementation.
version: 0.1.0
---

# Balancer V3 RECLAMM Pool

RECLAMM (Regenerating Concentrated Liquidity AMM) is a 2-token pool that automatically adjusts its price range to track market prices over time. It uses virtual balances to define concentrated liquidity within a price range.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                       RECLAMM POOL                           │
├──────────────────────────────────────────────────────────────┤
│ • 2-token concentrated liquidity AMM                         │
│ • Virtual balances define price range [minPrice, maxPrice]   │
│ • Automatically adjusts range to track market price          │
│ • "Centeredness" measures if pool is within target range     │
│ • dailyPriceShiftExponent controls adjustment speed          │
│ • Only proportional liquidity (unbalanced disabled)          │
│ • Self-hooking pool with optional secondary hook forwarding  │
└──────────────────────────────────────────────────────────────┘
```

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                   RECLAMM PRICE RANGE TRACKING                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Virtual Balances define the price range:                      │
│   ┌───────────────────────────────────────────────────────┐     │
│   │     minPrice ◄──────── targetPrice ────────► maxPrice │     │
│   │         ▲                   ▲                   ▲     │     │
│   │    virtualBalanceA      current           virtualBalanceB   │
│   └───────────────────────────────────────────────────────┘     │
│                                                                 │
│   Centeredness = distance from center of range                  │
│   - If within centerednessMargin: pool is "centered"            │
│   - If outside margin: virtual balances shift over time         │
│                                                                 │
│   Price Shift Rate = 2^dailyPriceShiftExponent per day          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## ReClammPool Contract

```solidity
contract ReClammPool is
    IReClammPoolMain,
    IHooks,
    BalancerPoolToken,
    BasePoolAuthentication,
    PoolInfo,
    ReClammCommon,
    VaultGuard,
    Version
{
    // Extension for getter functions (called via delegatecall)
    ReClammPoolExtension internal immutable _EXTENSION;

    // Optional secondary hook contract
    address internal immutable _HOOK_CONTRACT;

    constructor(
        ReClammPoolParams memory params,
        IVault vault,
        ReClammPoolExtension extensionContract,
        address hookContract
    );
}
```

## Pool Parameters

### ReClammPoolParams

```solidity
struct ReClammPoolParams {
    string name;
    string symbol;
    string version;
    uint256 dailyPriceShiftExponent;  // Virtual balances shift by 2^exp per day
    uint64 centerednessMargin;         // How far price can be from center
    uint256 initialMinPrice;           // Initial min price (token B per token A)
    uint256 initialMaxPrice;           // Initial max price
    uint256 initialTargetPrice;        // Initial target price
    bool tokenAPriceIncludesRate;      // Use rate provider for token A price
    bool tokenBPriceIncludesRate;      // Use rate provider for token B price
}
```

### ReClammPriceParams (Factory Input)

```solidity
struct ReClammPriceParams {
    uint256 initialMinPrice;
    uint256 initialMaxPrice;
    uint256 initialTargetPrice;
    bool tokenAPriceIncludesRate;
    bool tokenBPriceIncludesRate;
}
```

## Virtual Balances & Price Range

Virtual balances create the concentrated liquidity price range:

```solidity
// Price range is determined by virtual balances
(minPrice, maxPrice) = ReClammMath.computePriceRange(
    balancesScaled18,
    virtualBalanceA,
    virtualBalanceB
);

// Spot price calculation
spotPrice = (realBalanceB + virtualBalanceB) / (realBalanceA + virtualBalanceA);
```

### Price Range Computation

```solidity
function computePriceRange(
    uint256[] memory balances,
    uint256 virtualBalanceA,
    uint256 virtualBalanceB
) internal pure returns (uint256 minPrice, uint256 maxPrice) {
    // minPrice = virtualBalanceB / (realBalanceA + virtualBalanceA)
    // maxPrice = (realBalanceB + virtualBalanceB) / virtualBalanceA
}
```

## Centeredness

Centeredness measures how close the pool price is to the center of its range:

```solidity
function computeCenteredness(
    uint256[] memory balances,
    uint256 virtualBalanceA,
    uint256 virtualBalanceB
) internal pure returns (uint256 centeredness, bool isAboveCenter);

// centeredness = 0 means exactly at center
// centeredness = 1e18 means at edge of range
// If centeredness > centerednessMargin, virtual balances will shift
```

### Target Range Check

```solidity
function isPoolWithinTargetRange(
    uint256[] memory balances,
    uint256 virtualBalanceA,
    uint256 virtualBalanceB,
    uint256 centerednessMargin
) internal pure returns (bool);
```

## Virtual Balance Updates

When the pool is outside the target range, virtual balances shift over time:

```solidity
function computeCurrentVirtualBalances(
    uint256[] memory balancesScaled18,
    uint256 lastVirtualBalanceA,
    uint256 lastVirtualBalanceB,
    uint256 dailyPriceShiftBase,
    uint32 lastTimestamp,
    uint64 centerednessMargin,
    PriceRatioState memory priceRatioState
) internal view returns (
    uint256 currentVirtualBalanceA,
    uint256 currentVirtualBalanceB,
    bool changed
);
```

### Daily Price Shift

```solidity
// dailyPriceShiftExponent controls the speed of range adjustment
// Higher exponent = faster adjustment
// Range can shift by 2^exponent per day

uint256 constant _MAX_DAILY_PRICE_SHIFT_EXPONENT = 5; // Max 32x per day
```

## Price Ratio Updates

The price ratio can be updated gradually over time:

```solidity
struct PriceRatioState {
    uint64 startFourthRootPriceRatio;
    uint64 endFourthRootPriceRatio;
    uint32 priceRatioUpdateStartTime;
    uint32 priceRatioUpdateEndTime;
}

// Update price ratio over time (permissioned)
function startPriceRatioUpdate(
    uint256 endFourthRootPriceRatio,
    uint256 duration
) external;

// Stop ongoing update
function stopPriceRatioUpdate() external;
```

## Hook Implementation

RECLAMM is its own hooks contract:

```solidity
function getHookFlags() external pure returns (HookFlags memory hookFlags) {
    hookFlags.shouldCallBeforeInitialize = true;
    hookFlags.shouldCallBeforeAddLiquidity = true;
    hookFlags.shouldCallBeforeRemoveLiquidity = true;
    // Optional: forward to secondary hook
}

// Before initialize: validate and set initial virtual balances
function onBeforeInitialize(uint256[] memory exactAmountsIn) external returns (bool);

// Before add/remove: update virtual balances based on time
function onBeforeAddLiquidity(...) external returns (bool);
function onBeforeRemoveLiquidity(...) external returns (bool);
```

### Secondary Hook Forwarding

```solidity
// Pool can forward hooks to optional secondary hook contract
address internal immutable _HOOK_CONTRACT;

// If _HOOK_CONTRACT != address(0), forward hook calls
```

## IBasePool Implementation

```solidity
/// @inheritdoc IBasePool
function computeInvariant(
    uint256[] memory balancesLiveScaled18,
    Rounding rounding
) public view returns (uint256 invariant) {
    (uint256 virtualBalanceA, uint256 virtualBalanceB, ) =
        _computeCurrentVirtualBalances(balancesLiveScaled18);

    invariant = ReClammMath.computeInvariant(
        balancesLiveScaled18,
        virtualBalanceA,
        virtualBalanceB,
        rounding
    );
}

/// @inheritdoc IBasePool
function computeBalance(
    uint256[] memory balancesLiveScaled18,
    uint256 tokenInIndex,
    uint256 invariantRatio
) external view returns (uint256 newBalance) {
    (uint256 virtualBalanceA, uint256 virtualBalanceB, ) =
        _computeCurrentVirtualBalances(balancesLiveScaled18);

    return ReClammMath.computeBalance(
        balancesLiveScaled18,
        virtualBalanceA,
        virtualBalanceB,
        tokenInIndex,
        invariantRatio
    );
}

/// @inheritdoc IBasePool
function onSwap(PoolSwapParams memory request) external view returns (uint256) {
    (uint256 virtualBalanceA, uint256 virtualBalanceB, ) =
        _computeCurrentVirtualBalances(request.balancesScaled18);

    if (request.kind == SwapKind.EXACT_IN) {
        return ReClammMath.computeOutGivenIn(
            request.balancesScaled18,
            virtualBalanceA,
            virtualBalanceB,
            request.indexIn,
            request.amountGivenScaled18
        );
    } else {
        return ReClammMath.computeInGivenOut(
            request.balancesScaled18,
            virtualBalanceA,
            virtualBalanceB,
            request.indexOut,
            request.amountGivenScaled18
        );
    }
}
```

## ReClammPoolFactory

```solidity
contract ReClammPoolFactory is IPoolVersion, BasePoolFactory, Version {
    function create(
        string memory name,
        string memory symbol,
        TokenConfig[] memory tokens,           // Exactly 2 tokens
        PoolRoleAccounts memory roleAccounts,
        uint256 swapFeePercentage,
        address hookContract,                   // Optional secondary hook
        ReClammPriceParams memory priceParams,
        uint256 dailyPriceShiftExponent,
        uint256 centerednessMargin,
        bytes32 salt
    ) external returns (address pool);

    // Uses CREATE3 for deterministic addresses
    function getDeploymentAddress(bytes32 salt) public view returns (address);
}
```

### Factory Configuration

The factory enforces RECLAMM requirements:

```solidity
LiquidityManagement memory liquidityManagement = getDefaultLiquidityManagement();
liquidityManagement.enableDonation = false;
liquidityManagement.disableUnbalancedLiquidity = true;  // Proportional only

// Pool is its own hook
_registerPoolWithVault(
    pool,
    tokens,
    swapFeePercentage,
    false,      // not exempt from protocol fees
    roleAccounts,
    pool,       // Pool is the hook contract
    liquidityManagement
);
```

## ReClammPoolExtension

Extension contract for getter functions (called via delegatecall):

```solidity
contract ReClammPoolExtension is IReClammPoolExtension, ReClammCommon, VaultGuard {
    // Getters
    function getLastTimestamp() external view returns (uint32);
    function getLastVirtualBalances() external view returns (uint256, uint256);
    function getCenterednessMargin() external view returns (uint256);
    function getDailyPriceShiftExponent() external view returns (uint256);
    function getDailyPriceShiftBase() external view returns (uint256);
    function getPriceRatioState() external view returns (PriceRatioState memory);

    // Convenience functions
    function computeCurrentPriceRatio() external view returns (uint256);
    function computeCurrentFourthRootPriceRatio() external view returns (uint256);
    function computeCurrentPriceRange() external view returns (uint256 min, uint256 max);
    function computeCurrentPoolCenteredness() external view returns (uint256, bool);
    function computeCurrentVirtualBalances() external view returns (uint256, uint256, bool);
    function computeCurrentSpotPrice() external view returns (uint256);
    function isPoolWithinTargetRangeUsingCurrentVirtualBalances() external view returns (bool, bool);

    // Dynamic and immutable data
    function getReClammPoolDynamicData() external view returns (ReClammPoolDynamicData memory);
    function getReClammPoolImmutableData() external view returns (ReClammPoolImmutableData memory);
}
```

## Querying Pool Data

### ReClammPoolDynamicData

```solidity
struct ReClammPoolDynamicData {
    uint256[] balancesLiveScaled18;
    uint256[] tokenRates;
    uint256 staticSwapFeePercentage;
    uint256 totalSupply;
    uint32 lastTimestamp;
    uint256[] lastVirtualBalances;
    uint256 dailyPriceShiftBase;
    uint256 dailyPriceShiftExponent;
    uint256 centerednessMargin;
    uint64 startFourthRootPriceRatio;
    uint64 endFourthRootPriceRatio;
    uint32 priceRatioUpdateStartTime;
    uint32 priceRatioUpdateEndTime;
    uint256 currentPriceRatio;
    uint256 currentFourthRootPriceRatio;
    bool isPoolInitialized;
    bool isPoolPaused;
    bool isPoolInRecoveryMode;
}
```

### ReClammPoolImmutableData

```solidity
struct ReClammPoolImmutableData {
    IERC20[] tokens;
    uint256[] decimalScalingFactors;
    bool tokenAPriceIncludesRate;
    bool tokenBPriceIncludesRate;
    uint256 minSwapFeePercentage;
    uint256 maxSwapFeePercentage;
    uint256 initialMinPrice;
    uint256 initialMaxPrice;
    uint256 initialTargetPrice;
    uint256 initialDailyPriceShiftExponent;
    uint64 initialCenterednessMargin;
    address hookContract;
    uint64 maxCenterednessMargin;
    uint256 maxDailyPriceShiftExponent;
    uint256 maxDailyPriceRatioUpdateRate;
    uint256 minPriceRatioUpdateDuration;
    uint256 minPriceRatioDelta;
    uint256 balanceRatioAndPriceTolerance;
}
```

## Factory Usage Example

```solidity
// Create WETH/USDC RECLAMM pool with 1800-2200 price range
TokenConfig[] memory tokens = new TokenConfig[](2);
tokens[0] = TokenConfig({
    token: IERC20(WETH),
    tokenType: TokenType.STANDARD,
    rateProvider: IRateProvider(address(0)),
    paysYieldFees: false
});
tokens[1] = TokenConfig({
    token: IERC20(USDC),
    tokenType: TokenType.STANDARD,
    rateProvider: IRateProvider(address(0)),
    paysYieldFees: false
});

ReClammPriceParams memory priceParams = ReClammPriceParams({
    initialMinPrice: 1800e18,    // $1800 per ETH min
    initialMaxPrice: 2200e18,    // $2200 per ETH max
    initialTargetPrice: 2000e18, // $2000 target
    tokenAPriceIncludesRate: false,
    tokenBPriceIncludesRate: false
});

address pool = reClammFactory.create(
    "RECLAMM WETH-USDC",
    "rclm-WETH-USDC",
    tokens,
    PoolRoleAccounts(address(0), swapFeeManager, address(0)),
    0.003e16,           // 0.3% swap fee
    address(0),          // no secondary hook
    priceParams,
    2,                   // dailyPriceShiftExponent (4x per day max)
    0.05e18,             // 5% centeredness margin
    keccak256("my-reclamm-salt")
);
```

## Comparison to Other Pools

| Aspect | Weighted Pool | Gyro 2-CLP | RECLAMM |
|--------|---------------|------------|---------|
| Tokens | 2-8 | 2 | 2 |
| Price Range | Unlimited | Fixed | Dynamic/Tracking |
| Concentration | None | Static | Self-adjusting |
| Range Updates | N/A | Immutable | Automatic over time |
| Capital Efficiency | Lower | Higher | Adaptive |
| Best For | Diverse assets | Stable pairs | Trending markets |

## Key Features

| Feature | Description |
|---------|-------------|
| Regenerating Range | Price range automatically tracks market over time |
| Virtual Balances | Define concentrated liquidity without tick system |
| Centeredness | Measures if pool is within target operating range |
| Gradual Updates | Price ratio can be updated over configurable duration |
| Self-Hooking | Pool implements its own hooks for state updates |
| Proportional Only | Unbalanced liquidity disabled for security |

## Security Considerations

1. **Proportional Only**: Unbalanced add/remove disabled to prevent manipulation
2. **Rate Controls**: dailyPriceShiftExponent and price ratio update rate are bounded
3. **Hook Validation**: Pool validates itself as hook during registration
4. **Extension Pattern**: Getter functions isolated in extension contract

## Reference Files

- `contracts/ReClammPool.sol` - Main pool implementation
- `contracts/ReClammPoolExtension.sol` - Extension for getters
- `contracts/ReClammPoolFactory.sol` - Factory with CREATE3
- `contracts/lib/ReClammMath.sol` - Math library
- `contracts/interfaces/IReClammPool.sol` - Interfaces
- `contracts/ReClammCommon.sol` - Shared utilities
- `contracts/ReClammStorage.sol` - Storage layout
