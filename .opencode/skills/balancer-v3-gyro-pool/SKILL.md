---
name: Balancer V3 Gyro Pool
description: This skill should be used when the user asks about "Gyro pool", "2-CLP", "E-CLP", "concentrated liquidity", "sqrtAlpha", "sqrtBeta", "ellipse curve", "Gyroscope", "pricing range", or needs to understand Balancer V3 Gyro Pool implementations.
version: 0.1.0
---

# Balancer V3 Gyro Pools

Gyro pools are Concentrated Liquidity Pools (CLPs) that allow liquidity to be focused within specific price ranges, providing higher capital efficiency than traditional AMMs.

## Overview

Balancer V3 includes two types of Gyro pools:

| Pool Type | Tokens | Curve Shape | Best For |
|-----------|--------|-------------|----------|
| **Gyro2CLP** | 2 | Hyperbolic (like Uniswap v3) | General concentrated liquidity |
| **GyroECLP** | 2 | Ellipse | Stable pairs with asymmetric behavior |

## Gyro 2-CLP Pool

Concentrates liquidity within a pricing range [α, β].

### Invariant Formula

```
L² = (x + a)(y + b)

where:
  a = L / sqrt(β)    // Virtual offset for token X
  b = L * sqrt(α)    // Virtual offset for token Y
  L = Invariant
```

### Gyro2CLPPool Contract

```solidity
contract Gyro2CLPPool is IGyro2CLPPool, BalancerPoolToken, PoolInfo, Version {
    uint256 private immutable _sqrtAlpha;  // sqrt(lower price bound)
    uint256 private immutable _sqrtBeta;   // sqrt(upper price bound)

    struct GyroParams {
        string name;
        string symbol;
        uint256 sqrtAlpha;   // sqrt of minimum price
        uint256 sqrtBeta;    // sqrt of maximum price
        string version;
    }

    constructor(GyroParams memory params, IVault vault) {
        // sqrtAlpha must be less than sqrtBeta
        if (params.sqrtAlpha >= params.sqrtBeta) {
            revert SqrtParamsWrong();
        }
        _sqrtAlpha = params.sqrtAlpha;
        _sqrtBeta = params.sqrtBeta;
    }
}
```

### Price Range Configuration

```solidity
// Price range [α, β] defines where liquidity is concentrated
// Example: For a 0.95 - 1.05 price range:
// sqrtAlpha = sqrt(0.95e18) ≈ 974679434480896e3
// sqrtBeta = sqrt(1.05e18) ≈ 1024695076595960e3

// The tighter the range, the higher the capital efficiency
// but also the higher the impermanent loss risk
```

### Swap Calculation

```solidity
function onSwap(PoolSwapParams calldata request) external view returns (uint256) {
    bool tokenInIsToken0 = request.indexIn == 0;

    // Calculate virtual offsets based on current invariant
    (uint256 virtualParamIn, uint256 virtualParamOut) = _getVirtualOffsets(
        request.balancesScaled18[request.indexIn],
        request.balancesScaled18[request.indexOut],
        tokenInIsToken0
    );

    if (request.kind == SwapKind.EXACT_IN) {
        return Gyro2CLPMath.calcOutGivenIn(
            balanceIn, balanceOut, amountIn, virtualParamIn, virtualParamOut
        );
    } else {
        return Gyro2CLPMath.calcInGivenOut(
            balanceIn, balanceOut, amountOut, virtualParamIn, virtualParamOut
        );
    }
}
```

### Gyro2CLPPoolFactory

```solidity
contract Gyro2CLPPoolFactory is BasePoolFactory {
    function create(
        string memory name,
        string memory symbol,
        TokenConfig[] memory tokens,      // Exactly 2 tokens
        uint256 sqrtAlpha,
        uint256 sqrtBeta,
        PoolRoleAccounts memory roleAccounts,
        uint256 swapFeePercentage,
        address poolHooksContract,
        bytes32 salt
    ) external returns (address pool);
}
```

## Gyro E-CLP Pool

Trading occurs along part of an ellipse curve, providing more flexible price behavior.

### E-CLP Parameters

```solidity
struct EclpParams {
    int256 alpha;   // Lower price bound
    int256 beta;    // Upper price bound
    int256 c;       // cos(phi) - rotation angle
    int256 s;       // sin(phi) - rotation angle
    int256 lambda;  // Stretching parameter
}

struct DerivedEclpParams {
    Vector2 tauAlpha;  // Derived from alpha
    Vector2 tauBeta;   // Derived from beta
    int256 u, v, w, z; // Derived coefficients
    int256 dSq;        // Denominator squared
}
```

### GyroECLPPool Contract

```solidity
contract GyroECLPPool is IGyroECLPPool, BalancerPoolToken, PoolInfo, Version {
    // E-CLP parameters (immutable)
    int256 internal immutable _paramsAlpha;
    int256 internal immutable _paramsBeta;
    int256 internal immutable _paramsC;
    int256 internal immutable _paramsS;
    int256 internal immutable _paramsLambda;

    // Derived parameters (38 decimal precision)
    int256 internal immutable _tauAlphaX;
    int256 internal immutable _tauAlphaY;
    int256 internal immutable _tauBetaX;
    int256 internal immutable _tauBetaY;
    int256 internal immutable _u, _v, _w, _z;
    int256 internal immutable _dSq;

    struct GyroECLPPoolParams {
        string name;
        string symbol;
        EclpParams eclpParams;
        DerivedEclpParams derivedEclpParams;  // Pre-computed off-chain
        string version;
    }
}
```

### E-CLP Math

```solidity
// Invariant calculation with error bounds
function calculateInvariantWithError(
    uint256[] memory balances,
    EclpParams memory params,
    DerivedEclpParams memory derived
) internal pure returns (int256 invariant, int256 error);

// Swap calculations
function calcOutGivenIn(
    uint256[] memory balances,
    uint256 amountIn,
    bool tokenInIsToken0,
    EclpParams memory params,
    DerivedEclpParams memory derived,
    Vector2 memory invariant
) internal pure returns (uint256 amountOut, ...);

function calcInGivenOut(
    uint256[] memory balances,
    uint256 amountOut,
    bool tokenInIsToken0,
    EclpParams memory params,
    DerivedEclpParams memory derived,
    Vector2 memory invariant
) internal pure returns (uint256 amountIn, ...);
```

### GyroECLPPoolFactory

```solidity
contract GyroECLPPoolFactory is BasePoolFactory {
    function create(
        string memory name,
        string memory symbol,
        TokenConfig[] memory tokens,
        EclpParams memory eclpParams,
        DerivedEclpParams memory derivedEclpParams,
        PoolRoleAccounts memory roleAccounts,
        uint256 swapFeePercentage,
        address poolHooksContract,
        bytes32 salt
    ) external returns (address pool);
}
```

## Fee Bounds

```solidity
// Gyro pools have wide fee ranges
function getMinimumSwapFeePercentage() external pure returns (uint256) {
    return 1e12; // 0.0001%
}

function getMaximumSwapFeePercentage() external pure returns (uint256) {
    return 1e18; // 100% (for extreme cases)
}
```

## Invariant Ratio Bounds

```solidity
// 2-CLP: No bounds (unlimited unbalanced operations)
function getMinimumInvariantRatio() returns (uint256) { return 0; }
function getMaximumInvariantRatio() returns (uint256) { return type(uint256).max; }

// E-CLP: Has bounds
uint256 constant MIN_INVARIANT_RATIO = ...; // Pool specific
uint256 constant MAX_INVARIANT_RATIO = ...; // Pool specific
```

## Querying Pool Data

### 2-CLP

```solidity
function getGyro2CLPPoolDynamicData() external view returns (Gyro2CLPPoolDynamicData memory);
function getGyro2CLPPoolImmutableData() external view returns (Gyro2CLPPoolImmutableData memory);

struct Gyro2CLPPoolImmutableData {
    IERC20[] tokens;
    uint256[] decimalScalingFactors;
    uint256 sqrtAlpha;
    uint256 sqrtBeta;
}
```

### E-CLP

```solidity
function getECLPParams() external view returns (EclpParams memory, DerivedEclpParams memory);
function getGyroECLPPoolDynamicData() external view returns (GyroECLPPoolDynamicData memory);
function getGyroECLPPoolImmutableData() external view returns (GyroECLPPoolImmutableData memory);
```

## Factory Usage Examples

### 2-CLP Pool

```solidity
// Create a concentrated USDC/DAI pool (0.99 - 1.01 range)
uint256 sqrtAlpha = 995037190209989e3;  // sqrt(0.99e18)
uint256 sqrtBeta = 1004987562112089e3;  // sqrt(1.01e18)

TokenConfig[] memory tokens = new TokenConfig[](2);
tokens[0] = TokenConfig({
    token: IERC20(USDC),
    tokenType: TokenType.STANDARD,
    rateProvider: IRateProvider(address(0)),
    paysYieldFees: false
});
tokens[1] = TokenConfig({
    token: IERC20(DAI),
    tokenType: TokenType.STANDARD,
    rateProvider: IRateProvider(address(0)),
    paysYieldFees: false
});

address pool = gyro2ClpFactory.create(
    "USDC-DAI 2CLP",
    "USDC-DAI-2CLP",
    tokens,
    sqrtAlpha,
    sqrtBeta,
    PoolRoleAccounts(address(0), address(0), address(0)),
    0.0001e16,  // 0.01% swap fee
    address(0), // no hooks
    keccak256("my-2clp-salt")
);
```

### E-CLP Pool

```solidity
// E-CLP requires pre-computed derived parameters
// These are typically computed off-chain using the Gyroscope SDK

EclpParams memory params = EclpParams({
    alpha: ...,
    beta: ...,
    c: ...,      // cos(phi)
    s: ...,      // sin(phi)
    lambda: ...  // stretching
});

DerivedEclpParams memory derived = EclpParams({
    tauAlpha: Vector2(..., ...),
    tauBeta: Vector2(..., ...),
    u: ..., v: ..., w: ..., z: ...,
    dSq: ...
});

address pool = gyroEclpFactory.create(
    "WETH-wstETH ECLP",
    "WETH-wstETH-ECLP",
    tokens,
    params,
    derived,
    roleAccounts,
    swapFeePercentage,
    address(0),
    salt
);
```

## Use Cases

| Pool Type | Best For |
|-----------|----------|
| 2-CLP | Stablecoin pairs, pegged assets, predictable ranges |
| E-CLP | LST pairs (wstETH/ETH), asymmetric price behavior |

## Reference Files

- `pkg/pool-gyro/contracts/Gyro2CLPPool.sol` - 2-CLP implementation
- `pkg/pool-gyro/contracts/Gyro2CLPPoolFactory.sol` - 2-CLP factory
- `pkg/pool-gyro/contracts/GyroECLPPool.sol` - E-CLP implementation
- `pkg/pool-gyro/contracts/GyroECLPPoolFactory.sol` - E-CLP factory
- `pkg/pool-gyro/contracts/lib/Gyro2CLPMath.sol` - 2-CLP math
- `pkg/pool-gyro/contracts/lib/GyroECLPMath.sol` - E-CLP math
- [Gyroscope Docs](https://docs.gyro.finance/gyroscope-protocol/concentrated-liquidity-pools/)
