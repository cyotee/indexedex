---
name: Balancer V3 Weighted Pool
description: This skill should be used when the user asks about "WeightedPool", "WeightedPoolFactory", "normalized weights", "WeightedMath", "weighted pool invariant", "constant product AMM", or needs to understand Balancer V3 Weighted Pool implementation.
version: 0.1.0
---

# Balancer V3 Weighted Pool

Weighted Pools are designed for uncorrelated assets with customizable token weights. They use the constant product formula from Balancer v1/v2.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    WEIGHTED POOL                             │
├──────────────────────────────────────────────────────────────┤
│ • 2-8 tokens with arbitrary weights                          │
│ • Weights fixed at deployment (immutable)                    │
│ • Uses WeightedMath for swap/liquidity calculations          │
│ • Extends BalancerPoolToken (is its own BPT)                 │
│ • Swap fees: 0.001% to 10%                                   │
└──────────────────────────────────────────────────────────────┘
```

## WeightedPool Contract

```solidity
contract WeightedPool is IWeightedPool, BalancerPoolToken, PoolInfo, Version {
    // Minimum weight: 1%
    uint256 internal constant _MIN_WEIGHT = 1e16;

    // Swap fee bounds
    uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 0.001e16; // 0.001%
    uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 10e16;    // 10%

    // Weights stored as immutables (gas efficient)
    uint256 internal immutable _normalizedWeight0;
    uint256 internal immutable _normalizedWeight1;
    // ... up to _normalizedWeight7

    struct NewPoolParams {
        string name;
        string symbol;
        uint256 numTokens;
        uint256[] normalizedWeights;  // Must sum to 1e18
        string version;
    }
}
```

## Weight Constraints

```solidity
// Weights are 18-decimal fixed point
// Must sum to exactly FixedPoint.ONE (1e18)
// Each weight >= 1% (_MIN_WEIGHT = 1e16)

// Example: 80/20 pool
// weight0 = 80e16 (80%)
// weight1 = 20e16 (20%)
// sum = 100e16 = 1e18 ✓
```

## WeightedMath

### Invariant Calculation

```solidity
// Weighted constant product formula:
// V = Π (B_i ^ w_i)
// where B_i = balance of token i, w_i = weight of token i

function computeInvariantDown(
    uint256[] memory normalizedWeights,
    uint256[] memory balances
) internal pure returns (uint256 invariant) {
    invariant = FixedPoint.ONE;
    for (uint256 i = 0; i < normalizedWeights.length; ++i) {
        invariant = invariant.mulDown(balances[i].powDown(normalizedWeights[i]));
    }
}

function computeInvariantUp(
    uint256[] memory normalizedWeights,
    uint256[] memory balances
) internal pure returns (uint256 invariant) {
    invariant = FixedPoint.ONE;
    for (uint256 i = 0; i < normalizedWeights.length; ++i) {
        invariant = invariant.mulUp(balances[i].powUp(normalizedWeights[i]));
    }
}
```

### Swap Calculations

```solidity
// EXACT_IN: Given amountIn, calculate amountOut
function computeOutGivenExactIn(
    uint256 balanceIn,
    uint256 weightIn,
    uint256 balanceOut,
    uint256 weightOut,
    uint256 amountIn
) internal pure returns (uint256 amountOut) {
    // amountOut = balanceOut * (1 - (balanceIn / (balanceIn + amountIn))^(weightIn/weightOut))
    uint256 denominator = balanceIn + amountIn;
    uint256 base = balanceIn.divUp(denominator);
    uint256 exponent = weightIn.divDown(weightOut);
    uint256 power = base.powUp(exponent);
    return balanceOut.mulDown(power.complement());
}

// EXACT_OUT: Given amountOut, calculate amountIn
function computeInGivenExactOut(
    uint256 balanceIn,
    uint256 weightIn,
    uint256 balanceOut,
    uint256 weightOut,
    uint256 amountOut
) internal pure returns (uint256 amountIn) {
    // amountIn = balanceIn * ((balanceOut / (balanceOut - amountOut))^(weightOut/weightIn) - 1)
    uint256 base = balanceOut.divUp(balanceOut - amountOut);
    uint256 exponent = weightOut.divUp(weightIn);
    uint256 power = base.powUp(exponent);
    uint256 ratio = power - FixedPoint.ONE;
    return balanceIn.mulUp(ratio);
}
```

### Balance Computation

```solidity
// Used for single-token add/remove liquidity
function computeBalanceOutGivenInvariant(
    uint256 currentBalance,
    uint256 weight,
    uint256 invariantRatio  // newInvariant / oldInvariant
) internal pure returns (uint256 newBalance) {
    // newBalance = currentBalance * invariantRatio^(1/weight)
    uint256 exponent = FixedPoint.ONE.divUp(weight);
    uint256 power = invariantRatio.powUp(exponent);
    return currentBalance.mulUp(power);
}
```

## IBasePool Implementation

```solidity
/// @inheritdoc IBasePool
function computeInvariant(
    uint256[] memory balancesLiveScaled18,
    Rounding rounding
) public view virtual returns (uint256) {
    function(uint256[] memory, uint256[] memory) internal pure returns (uint256) _upOrDown =
        rounding == Rounding.ROUND_UP
            ? WeightedMath.computeInvariantUp
            : WeightedMath.computeInvariantDown;

    return _upOrDown(_getNormalizedWeights(), balancesLiveScaled18);
}

/// @inheritdoc IBasePool
function computeBalance(
    uint256[] memory balancesLiveScaled18,
    uint256 tokenInIndex,
    uint256 invariantRatio
) public view virtual returns (uint256 newBalance) {
    return WeightedMath.computeBalanceOutGivenInvariant(
        balancesLiveScaled18[tokenInIndex],
        _getNormalizedWeight(tokenInIndex),
        invariantRatio
    );
}

/// @inheritdoc IBasePool
function onSwap(PoolSwapParams memory request) public view virtual returns (uint256) {
    if (request.kind == SwapKind.EXACT_IN) {
        return WeightedMath.computeOutGivenExactIn(
            request.balancesScaled18[request.indexIn],
            _getNormalizedWeight(request.indexIn),
            request.balancesScaled18[request.indexOut],
            _getNormalizedWeight(request.indexOut),
            request.amountGivenScaled18
        );
    } else {
        return WeightedMath.computeInGivenExactOut(
            request.balancesScaled18[request.indexIn],
            _getNormalizedWeight(request.indexIn),
            request.balancesScaled18[request.indexOut],
            _getNormalizedWeight(request.indexOut),
            request.amountGivenScaled18
        );
    }
}
```

## BPT Rate

```solidity
/// @inheritdoc IRateProvider
function getRate() public pure override returns (uint256) {
    // Weighted Pools do NOT support getRate()
    // Cannot safely nest as WITH_RATE tokens
    revert WeightedPoolBptRateUnsupported();
}
```

**Why?** The invariant-based rate calculation has non-linear rounding errors that could be exploited.

## WeightedPoolFactory

```solidity
contract WeightedPoolFactory is BasePoolFactory, Version {
    string private _poolVersion;

    function create(
        string memory name,
        string memory symbol,
        TokenConfig[] memory tokens,
        uint256[] memory normalizedWeights,
        PoolRoleAccounts memory roleAccounts,
        uint256 swapFeePercentage,
        address poolHooksContract,
        bool enableDonation,
        bool disableUnbalancedLiquidity,
        bytes32 salt
    ) external returns (address pool);
}
```

### Factory Usage Example

```solidity
// Create an 80/20 WETH/USDC pool
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

uint256[] memory weights = new uint256[](2);
weights[0] = 80e16;  // 80%
weights[1] = 20e16;  // 20%

address pool = factory.create(
    "80WETH-20USDC",
    "80WETH-20USDC",
    tokens,
    weights,
    PoolRoleAccounts(address(0), address(0), address(0)),
    0.003e16,  // 0.3% swap fee
    address(0), // no hooks
    false,      // no donation
    false,      // allow unbalanced
    keccak256("my-pool-salt")
);
```

## WeightedPool8020Factory

Specialized factory for 80/20 pools with 2 tokens:

```solidity
contract WeightedPool8020Factory is BasePoolFactory {
    // Fixed weights: 80% token0, 20% token1
    uint256 private constant _WEIGHT_80 = 80e16;
    uint256 private constant _WEIGHT_20 = 20e16;

    function create(
        string memory name,
        string memory symbol,
        TokenConfig memory token1,  // 80% weight
        TokenConfig memory token2,  // 20% weight
        PoolRoleAccounts memory roleAccounts,
        uint256 swapFeePercentage,
        address poolHooksContract,
        bool enableDonation,
        bool disableUnbalancedLiquidity,
        bytes32 salt
    ) external returns (address pool);
}
```

## Querying Pool Data

```solidity
// Get weights
function getNormalizedWeights() external view returns (uint256[] memory);

// Get immutable data
function getWeightedPoolImmutableData() external view returns (
    WeightedPoolImmutableData memory data
);
// Returns: tokens, decimalScalingFactors, normalizedWeights

// Get dynamic data
function getWeightedPoolDynamicData() external view returns (
    WeightedPoolDynamicData memory data
);
// Returns: balancesLiveScaled18, tokenRates, staticSwapFeePercentage,
//          totalSupply, isPoolInitialized, isPoolPaused, isPoolInRecoveryMode
```

## Invariant Ratio Bounds

```solidity
// Limits for unbalanced add/remove operations
uint256 constant _MIN_INVARIANT_RATIO = 60e16;  // 60%
uint256 constant _MAX_INVARIANT_RATIO = 500e16; // 500%
```

## Reference Files

- `pkg/pool-weighted/contracts/WeightedPool.sol` - Pool implementation
- `pkg/pool-weighted/contracts/WeightedPoolFactory.sol` - General factory
- `pkg/pool-weighted/contracts/WeightedPool8020Factory.sol` - 80/20 factory
- `pkg/solidity-utils/contracts/math/WeightedMath.sol` - Math library
