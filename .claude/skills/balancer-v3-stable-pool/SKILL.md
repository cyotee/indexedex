---
name: Balancer V3 Stable Pool
description: This skill should be used when the user asks about "StablePool", "StablePoolFactory", "amplification parameter", "StableMath", "Curve-style pool", "stableswap", "correlated assets", "like-kind swaps", or needs to understand Balancer V3 Stable Pool implementation.
version: 0.1.0
---

# Balancer V3 Stable Pool

Stable Pools are designed for assets that trade at near parity or known exchange rates. They use StableMath (based on Curve's StableSwap) for capital-efficient swaps with minimal slippage.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    STABLE POOL                               │
├──────────────────────────────────────────────────────────────┤
│ • 2-5 tokens (MAX_STABLE_TOKENS = 5)                         │
│ • Amplification parameter controls curve flatness            │
│ • Uses StableMath for swap/liquidity calculations            │
│ • Amp can be updated over time (1 day minimum)               │
│ • Swap fees: 0.0001% to 10%                                  │
│ • Ideal for: stablecoins, LSTs, wrapped tokens               │
└──────────────────────────────────────────────────────────────┘
```

## StablePool Contract

```solidity
contract StablePool is IStablePool, BalancerPoolToken, BasePoolAuthentication, PoolInfo, Version {
    // Amplification update constraints
    uint256 private constant _MIN_UPDATE_TIME = 1 days;
    uint256 private constant _MAX_AMP_UPDATE_DAILY_RATE = 2;

    // Swap fee bounds
    uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 1e12;   // 0.0001%
    uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 10e16;  // 10%

    // Amplification state
    AmplificationState private _amplificationState;

    struct NewPoolParams {
        string name;
        string symbol;
        uint256 amplificationParameter;  // 1 - 5000 (before precision)
        string version;
    }
}
```

## Amplification Parameter

The amplification parameter (`A`) controls how "flat" the price curve is:

| A Value | Behavior |
|---------|----------|
| Low (1-10) | More like weighted pool, handles volatility |
| Medium (50-200) | Balanced, typical for stablecoins |
| High (200-5000) | Very flat, minimal slippage near parity |

```solidity
// Stored with precision multiplier
uint256 constant AMP_PRECISION = 1000;

// Limits
uint256 constant MIN_AMP = 1;
uint256 constant MAX_AMP = 5000;

// Example: A = 200 is stored as 200000 (200 * 1000)
```

### Updating Amplification

```solidity
// Start gradual update (permissioned)
function startAmplificationParameterUpdate(
    uint256 rawEndValue,     // Target A value (1-5000)
    uint256 endTime          // Timestamp when update completes
) external onlySwapFeeManagerOrGovernance;

// Stop update early (permissioned)
function stopAmplificationParameterUpdate() external onlySwapFeeManagerOrGovernance;

// Query current state
function getAmplificationParameter() external view returns (
    uint256 value,       // Current A * AMP_PRECISION
    bool isUpdating,     // True if update in progress
    uint256 precision    // AMP_PRECISION constant
);
```

### Update Constraints

```solidity
// Minimum duration: 1 day
if (duration < _MIN_UPDATE_TIME) revert AmpUpdateDurationTooShort();

// Maximum rate: 2x per day
// Cannot more than double or halve in a single day
if (dailyRate > _MAX_AMP_UPDATE_DAILY_RATE) revert AmpUpdateRateTooFast();

// Only one update at a time
if (isUpdating) revert AmpUpdateAlreadyStarted();
```

## StableMath

### Invariant Calculation

```solidity
// StableSwap invariant: D
// Sum of all token balances adjusted by amplification
// Solved iteratively via Newton-Raphson

function computeInvariant(uint256 amp, uint256[] memory balances)
    internal pure returns (uint256);
```

### Swap Calculations

```solidity
// Given exact input, calculate output
function computeOutGivenExactIn(
    uint256 amp,
    uint256[] memory balances,
    uint256 tokenIndexIn,
    uint256 tokenIndexOut,
    uint256 amountIn,
    uint256 invariant
) internal pure returns (uint256 amountOut);

// Given exact output, calculate input
function computeInGivenExactOut(
    uint256 amp,
    uint256[] memory balances,
    uint256 tokenIndexIn,
    uint256 tokenIndexOut,
    uint256 amountOut,
    uint256 invariant
) internal pure returns (uint256 amountIn);
```

### Balance Computation

```solidity
// For single-token add/remove liquidity
function computeBalance(
    uint256 amp,
    uint256[] memory balances,
    uint256 newInvariant,
    uint256 tokenIndex
) internal pure returns (uint256 newBalance);
```

## IBasePool Implementation

```solidity
/// @inheritdoc IBasePool
function computeInvariant(
    uint256[] memory balancesLiveScaled18,
    Rounding rounding
) external view returns (uint256 invariant) {
    (uint256 currentAmp, ) = _getAmplificationParameter();
    invariant = StableMath.computeInvariant(currentAmp, balancesLiveScaled18);
    // Apply rounding
    if (invariant > 0 && rounding == Rounding.ROUND_UP) {
        invariant += 1;
    }
}

/// @inheritdoc IBasePool
function onSwap(PoolSwapParams memory request) public view returns (uint256) {
    (uint256 currentAmp, ) = _getAmplificationParameter();
    uint256 invariant = StableMath.computeInvariant(currentAmp, request.balancesScaled18);

    if (request.kind == SwapKind.EXACT_IN) {
        return StableMath.computeOutGivenExactIn(
            currentAmp,
            request.balancesScaled18,
            request.indexIn,
            request.indexOut,
            request.amountGivenScaled18,
            invariant
        );
    } else {
        return StableMath.computeInGivenExactOut(
            currentAmp,
            request.balancesScaled18,
            request.indexIn,
            request.indexOut,
            request.amountGivenScaled18,
            invariant
        );
    }
}
```

## StablePoolFactory

```solidity
contract StablePoolFactory is BasePoolFactory, Version {
    function create(
        string memory name,
        string memory symbol,
        TokenConfig[] memory tokens,           // Max 5 tokens
        uint256 amplificationParameter,        // 1 - 5000
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
// Create a DAI/USDC/USDT stable pool
TokenConfig[] memory tokens = new TokenConfig[](3);
tokens[0] = TokenConfig({
    token: IERC20(DAI),
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
tokens[2] = TokenConfig({
    token: IERC20(USDT),
    tokenType: TokenType.STANDARD,
    rateProvider: IRateProvider(address(0)),
    paysYieldFees: false
});

address pool = factory.create(
    "DAI-USDC-USDT Stable",
    "DAI-USDC-USDT-SP",
    tokens,
    200,        // amplification parameter
    PoolRoleAccounts(address(0), swapFeeManager, address(0)),
    0.0004e16,  // 0.04% swap fee
    address(0), // no hooks
    false,      // no donation
    false,      // allow unbalanced
    keccak256("my-stable-pool-salt")
);
```

## Querying Pool Data

```solidity
// Get amplification state
function getAmplificationParameter() external view returns (
    uint256 value,
    bool isUpdating,
    uint256 precision
);

function getAmplificationState() external view returns (
    AmplificationState memory state,
    uint256 precision
);

// Get dynamic data
function getStablePoolDynamicData() external view returns (StablePoolDynamicData memory);

// Get immutable data
function getStablePoolImmutableData() external view returns (StablePoolImmutableData memory);
```

### StablePoolDynamicData

```solidity
struct StablePoolDynamicData {
    uint256[] balancesLiveScaled18;
    uint256[] tokenRates;
    uint256 staticSwapFeePercentage;
    uint256 totalSupply;
    uint256 bptRate;
    uint256 amplificationParameter;
    bool isAmpUpdating;
    uint64 startValue;
    uint64 endValue;
    uint32 startTime;
    uint32 endTime;
    bool isPoolInitialized;
    bool isPoolPaused;
    bool isPoolInRecoveryMode;
}
```

## Invariant Ratio Bounds

```solidity
// Limits for unbalanced operations
uint256 constant MIN_INVARIANT_RATIO = 70e16;  // 70%
uint256 constant MAX_INVARIANT_RATIO = 300e16; // 300%
```

## Use Cases

| Scenario | Recommended A |
|----------|---------------|
| Stablecoins (DAI/USDC/USDT) | 100-500 |
| LST pools (wstETH/ETH) | 50-200 |
| Wrapped tokens (same underlying) | 500-2000 |
| Volatile stables (algorithmic) | 10-50 |

## Events

```solidity
event AmpUpdateStarted(
    uint256 startValue,
    uint256 endValue,
    uint256 startTime,
    uint256 endTime
);

event AmpUpdateStopped(uint256 currentValue);
```

## Reference Files

- `pkg/pool-stable/contracts/StablePool.sol` - Pool implementation
- `pkg/pool-stable/contracts/StablePoolFactory.sol` - Factory
- `pkg/solidity-utils/contracts/math/StableMath.sol` - Math library
- `pkg/interfaces/contracts/pool-stable/IStablePool.sol` - Interface
