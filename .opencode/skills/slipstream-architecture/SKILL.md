---
name: Slipstream Architecture
description: This skill should be used when the user asks about "Slipstream", "concentrated liquidity", "CL pool", "tick", "tick spacing", "sqrtPrice", "Q64.96", or needs to understand the core Slipstream architecture.
version: 0.1.0
---

# Aerodrome Slipstream Architecture

Slipstream is Aerodrome's Concentrated Liquidity (CL) implementation, adapted from Uniswap V3 with Velodrome ecosystem integrations. It enables LPs to concentrate capital in specific price ranges for improved capital efficiency.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                 SLIPSTREAM ARCHITECTURE                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Traditional AMM (x * y = k):                                │
│  ├── Liquidity spread across ALL prices (0 to ∞)            │
│  └── Low capital efficiency                                  │
│                                                              │
│  Concentrated Liquidity (Slipstream):                        │
│  ├── LPs choose price range [tickLower, tickUpper]           │
│  ├── Liquidity concentrated where trading happens            │
│  ├── Higher fees earned per unit capital                     │
│  └── Positions represented as NFTs                           │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Price Scale                          │ │
│  │                                                         │ │
│  │  ◄──────────────────────────────────────────────────►   │ │
│  │  0                    Current Price                  ∞  │ │
│  │                           │                             │ │
│  │        [====LP Position===]                             │ │
│  │        tickLower    tickUpper                           │ │
│  │                                                         │ │
│  │  Only earns fees when price is within range             │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Tick System

Prices are represented as discrete "ticks" where each tick represents a 0.01% price change.

```solidity
// TickMath.sol

// Each tick represents price ratio of 1.0001
// tick = log(price) / log(1.0001)

int24 constant MIN_TICK = -887272;
int24 constant MAX_TICK = 887272;

// Minimum/maximum sqrt prices
uint160 constant MIN_SQRT_RATIO = 4295128739;
uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

/// @notice Convert tick to sqrt price in Q64.96 format
/// @param tick The tick to convert
/// @return sqrtPriceX96 sqrt(1.0001^tick) * 2^96
function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96);

/// @notice Convert sqrt price to tick
/// @param sqrtPriceX96 The sqrt price in Q64.96
/// @return tick The greatest tick <= the sqrt price's tick
function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24 tick);
```

### Tick Examples

```
Tick    │ Price (token1/token0)
────────┼─────────────────────
-887272 │ 0.0000000000000000000000000000000000000029
      0 │ 1.0000
  10000 │ 2.7182 (≈e)
  69082 │ 1000.0
 887272 │ 340,282,366,920,938,463,463,374,607,431,768,211,456
```

## Tick Spacing

Not every tick is initialized. Tick spacing determines valid position boundaries.

```solidity
// CLFactory.sol

// Common tick spacings and their fee tiers
mapping(int24 => uint24) public tickSpacingToFee;

// Typical configurations:
// tickSpacing = 1    → fee = 100   (0.01%) - Stable pairs
// tickSpacing = 50   → fee = 500   (0.05%) - Standard pairs
// tickSpacing = 100  → fee = 500   (0.05%)
// tickSpacing = 200  → fee = 3000  (0.30%) - Volatile pairs
// tickSpacing = 2000 → fee = 10000 (1.00%) - Exotic pairs

// Position boundaries must be divisible by tick spacing
// tickLower % tickSpacing == 0
// tickUpper % tickSpacing == 0
```

## Price Representation (Q64.96)

Prices are stored as sqrt(price) in Q64.96 fixed-point format.

```solidity
// Q64.96 means: 64 bits integer, 96 bits fraction
// sqrtPriceX96 = sqrt(price) * 2^96

// Example: ETH/USDC at $2000/ETH
// price = 2000 (USDC per ETH)
// sqrtPrice = sqrt(2000) ≈ 44.72
// sqrtPriceX96 = 44.72 * 2^96 ≈ 3.54 × 10^30

// Why sqrt price?
// - Enables constant-product math with fixed-point arithmetic
// - Avoids overflow in multiplication
// - Simplifies liquidity calculations

// Convert to actual price:
// price = (sqrtPriceX96 / 2^96)^2
// price = sqrtPriceX96^2 / 2^192
```

## Pool Slot0 (Current State)

```solidity
// CLPool.sol

struct Slot0 {
    uint160 sqrtPriceX96;              // Current sqrt(price) in Q64.96
    int24 tick;                         // Current tick (derived from sqrtPrice)
    uint16 observationIndex;            // Index in oracle array
    uint16 observationCardinality;      // Current oracle array size
    uint16 observationCardinalityNext;  // Next oracle array size
    bool unlocked;                      // Reentrancy guard
}

Slot0 public slot0;
```

## Liquidity

```solidity
// Global liquidity state
uint128 public liquidity;        // Currently active liquidity (in range)
uint128 public stakedLiquidity;  // Active liquidity that's staked in gauge

// Liquidity formula:
// For a position from tickLower to tickUpper with liquidity L:
//
// When price is within range:
//   amount0 = L * (sqrt(upper) - sqrt(current)) / (sqrt(current) * sqrt(upper))
//   amount1 = L * (sqrt(current) - sqrt(lower))
//
// This is why we use sqrtPrice - it simplifies these formulas
```

## Tick Data Structure

```solidity
// Tick.sol

struct Info {
    uint128 liquidityGross;        // Total liquidity referencing this tick
    int128 liquidityNet;           // Net liquidity change when crossing
    int128 stakedLiquidityNet;     // Net staked liquidity change

    // Fee growth outside this tick (for fee calculation)
    uint256 feeGrowthOutside0X128;
    uint256 feeGrowthOutside1X128;

    // Reward growth outside this tick
    uint256 rewardGrowthOutsideX128;

    int56 tickCumulativeOutside;   // Oracle: cumulative tick outside
    uint160 secondsPerLiquidityOutsideX128;  // Oracle: seconds per liquidity
    uint32 secondsOutside;         // Oracle: seconds spent outside
}

mapping(int24 => Tick.Info) public ticks;
```

## Tick Bitmap

```solidity
// TickBitmap library - Efficient tick lookup

// Each uint256 stores 256 bits, each representing a tick
// Position = tick / tickSpacing
// Word = position / 256
// Bit = position % 256

mapping(int16 => uint256) public tickBitmap;

/// @notice Check if tick is initialized
function isInitialized(int24 tick) internal view returns (bool) {
    (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
    return (tickBitmap[wordPos] & (1 << bitPos)) != 0;
}

/// @notice Find next initialized tick
/// @param tick Starting tick
/// @param lte Search direction (true = search lower)
/// @return next The next initialized tick
/// @return initialized Whether next tick exists
function nextInitializedTickWithinOneWord(
    int24 tick,
    int24 tickSpacing,
    bool lte
) internal view returns (int24 next, bool initialized);
```

## Pool Creation

```solidity
// CLFactory.sol

/// @notice Create a new concentrated liquidity pool
/// @param tokenA First token
/// @param tokenB Second token
/// @param tickSpacing Tick spacing (determines fee tier)
/// @param sqrtPriceX96 Initial sqrt price
function createPool(
    address tokenA,
    address tokenB,
    int24 tickSpacing,
    uint160 sqrtPriceX96
) external returns (address pool) {
    // Sort tokens
    (address token0, address token1) = tokenA < tokenB
        ? (tokenA, tokenB)
        : (tokenB, tokenA);

    require(getPool[token0][token1][tickSpacing] == address(0), "Pool exists");

    // Clone pool implementation
    bytes32 salt = keccak256(abi.encode(token0, token1, tickSpacing));
    pool = Clones.cloneDeterministic(poolImplementation, salt);

    // Initialize pool
    ICLPool(pool).initialize(sqrtPriceX96);

    getPool[token0][token1][tickSpacing] = pool;
    allPools.push(pool);

    emit PoolCreated(token0, token1, tickSpacing, pool);
}
```

## Key Invariants

```solidity
// 1. Tick boundaries must align with tick spacing
require(tickLower % tickSpacing == 0, "tickLower not aligned");
require(tickUpper % tickSpacing == 0, "tickUpper not aligned");

// 2. Valid tick range
require(tickLower < tickUpper, "tickLower >= tickUpper");
require(tickLower >= MIN_TICK, "tickLower too low");
require(tickUpper <= MAX_TICK, "tickUpper too high");

// 3. Current tick matches sqrt price
require(TickMath.getTickAtSqrtRatio(sqrtPriceX96) == tick, "tick mismatch");

// 4. Active liquidity only includes in-range positions
// liquidity = sum of all positions where tickLower <= currentTick < tickUpper
```

## Events

```solidity
event Initialize(uint160 sqrtPriceX96, int24 tick);
event Mint(
    address indexed sender,
    address indexed owner,
    int24 indexed tickLower,
    int24 tickUpper,
    uint128 amount,
    uint256 amount0,
    uint256 amount1
);
event Burn(
    address indexed owner,
    int24 indexed tickLower,
    int24 indexed tickUpper,
    uint128 amount,
    uint256 amount0,
    uint256 amount1
);
```

## Reference Files

- `contracts/core/CLPool.sol` - Main pool contract
- `contracts/core/CLFactory.sol` - Pool factory
- `contracts/core/libraries/Tick.sol` - Tick data structure
- `contracts/core/libraries/TickMath.sol` - Tick/price conversions
- `contracts/core/libraries/TickBitmap.sol` - Efficient tick lookup
