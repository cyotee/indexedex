---
name: Uniswap V3 Oracle
description: This skill should be used when the user asks about "oracle", "TWAP", "time-weighted average price", "observations", "observe", "price oracle", "tick cumulative", or needs to understand the on-chain oracle system.
version: 0.1.0
---

# Uniswap V3 Oracle

## Overview

Uniswap V3 pools include a built-in oracle that stores historical price observations, enabling on-chain calculation of time-weighted average prices (TWAPs) without external oracle dependencies.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ORACLE ARCHITECTURE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Observation Ring Buffer (circular array):                                  │
│                                                                              │
│  ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐             │
│  │  0  │  1  │  2  │  3  │  4  │  5  │  6  │  7  │  8  │ ... │             │
│  └──┬──┴─────┴─────┴──┬──┴─────┴─────┴──┬──┴─────┴─────┴─────┘             │
│     │                 │                 │                                    │
│     │                 │                 └─ observationIndex (current)       │
│     │                 │                                                      │
│     │                 └─ Historical observation                              │
│     │                                                                        │
│     └─ Oldest observation (wraps around)                                     │
│                                                                              │
│  Each Observation:                                                          │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  blockTimestamp: uint32           │ When this was recorded           │   │
│  │  tickCumulative: int56            │ Sum of tick × time               │   │
│  │  secondsPerLiquidityCumX128: u160 │ Sum of 1/liquidity × time        │   │
│  │  initialized: bool                │ Whether slot is used             │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  TWAP Calculation:                                                          │
│  ─────────────────                                                          │
│  twapTick = (tickCumulative[now] - tickCumulative[ago]) / timeElapsed      │
│  twapPrice = 1.0001^twapTick                                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Observation Data Structure

```solidity
library Oracle {
    struct Observation {
        // Timestamp of this observation
        uint32 blockTimestamp;

        // Cumulative sum of tick values over time
        // tickCumulative[t] = ∑(tick[i] × duration[i]) for all i from 0 to t
        int56 tickCumulative;

        // Cumulative sum of 1/liquidity over time (for liquidity mining)
        // secondsPerLiquidity[t] = ∑(1/liquidity[i] × duration[i]) for all i from 0 to t
        uint160 secondsPerLiquidityCumulativeX128;

        // Whether this observation slot has been written
        bool initialized;
    }
}
```

## Oracle Initialization

```solidity
function initialize(uint32 time)
    internal
    returns (uint16 cardinality, uint16 cardinalityNext)
{
    observations[0] = Observation({
        blockTimestamp: time,
        tickCumulative: 0,
        secondsPerLiquidityCumulativeX128: 0,
        initialized: true
    });
    return (1, 1);
}
```

## Writing Observations

Observations are written at most once per block, during the first swap/mint/burn of each block.

```solidity
function write(
    Observation[65535] storage self,
    uint16 index,
    uint32 blockTimestamp,
    int24 tick,
    uint128 liquidity,
    uint16 cardinality,
    uint16 cardinalityNext
) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
    Observation memory last = self[index];

    // Only write once per block
    if (last.blockTimestamp == blockTimestamp) return (index, cardinality);

    // Grow cardinality if next is larger
    if (cardinalityNext > cardinality && index == (cardinality - 1)) {
        cardinalityUpdated = cardinalityNext;
    } else {
        cardinalityUpdated = cardinality;
    }

    // Calculate new index (wraps around)
    indexUpdated = (index + 1) % cardinalityUpdated;

    // Calculate time delta
    uint32 delta = blockTimestamp - last.blockTimestamp;

    // Write new observation
    self[indexUpdated] = Observation({
        blockTimestamp: blockTimestamp,
        tickCumulative: last.tickCumulative + int56(tick) * int56(uint56(delta)),
        secondsPerLiquidityCumulativeX128: last.secondsPerLiquidityCumulativeX128 +
            ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1)),
        initialized: true
    });
}
```

## Reading Observations (observe)

```solidity
/// @notice Returns the cumulative values at specific times ago
function observe(
    Observation[65535] storage self,
    uint32 time,
    uint32[] memory secondsAgos,
    int24 tick,
    uint16 index,
    uint128 liquidity,
    uint16 cardinality
) internal view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) {
    require(cardinality > 0, 'I');

    tickCumulatives = new int56[](secondsAgos.length);
    secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);

    for (uint256 i = 0; i < secondsAgos.length; i++) {
        (tickCumulatives[i], secondsPerLiquidityCumulativeX128s[i]) = observeSingle(
            self,
            time,
            secondsAgos[i],
            tick,
            index,
            liquidity,
            cardinality
        );
    }
}

function observeSingle(
    Observation[65535] storage self,
    uint32 time,
    uint32 secondsAgo,
    int24 tick,
    uint16 index,
    uint128 liquidity,
    uint16 cardinality
) internal view returns (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) {
    if (secondsAgo == 0) {
        // Current values
        Observation memory last = self[index];
        if (last.blockTimestamp != time) {
            // Extrapolate to current time
            uint32 delta = time - last.blockTimestamp;
            return (
                last.tickCumulative + int56(tick) * int56(uint56(delta)),
                last.secondsPerLiquidityCumulativeX128 +
                    ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1))
            );
        }
        return (last.tickCumulative, last.secondsPerLiquidityCumulativeX128);
    }

    uint32 target = time - secondsAgo;

    // Binary search for surrounding observations
    (Observation memory beforeOrAt, Observation memory atOrAfter) =
        getSurroundingObservations(self, time, target, tick, index, liquidity, cardinality);

    if (target == beforeOrAt.blockTimestamp) {
        // Exact match
        return (beforeOrAt.tickCumulative, beforeOrAt.secondsPerLiquidityCumulativeX128);
    } else if (target == atOrAfter.blockTimestamp) {
        // Exact match
        return (atOrAfter.tickCumulative, atOrAfter.secondsPerLiquidityCumulativeX128);
    } else {
        // Interpolate between observations
        uint32 observationTimeDelta = atOrAfter.blockTimestamp - beforeOrAt.blockTimestamp;
        uint32 targetDelta = target - beforeOrAt.blockTimestamp;

        return (
            beforeOrAt.tickCumulative +
                ((atOrAfter.tickCumulative - beforeOrAt.tickCumulative) / int56(uint56(observationTimeDelta))) *
                int56(uint56(targetDelta)),
            beforeOrAt.secondsPerLiquidityCumulativeX128 +
                uint160(
                    (uint256(
                        atOrAfter.secondsPerLiquidityCumulativeX128 -
                        beforeOrAt.secondsPerLiquidityCumulativeX128
                    ) * targetDelta) / observationTimeDelta
                )
        );
    }
}
```

## Growing Oracle Cardinality

By default, pools store only 1 observation. This can be expanded up to 65,535.

```solidity
/// @notice Prepares the oracle to store more observations
function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external lock {
    uint16 observationCardinalityNextOld = slot0.observationCardinalityNext;
    uint16 observationCardinalityNextNew = observations.grow(
        observationCardinalityNextOld,
        observationCardinalityNext
    );
    slot0.observationCardinalityNext = observationCardinalityNextNew;
    if (observationCardinalityNextOld != observationCardinalityNextNew)
        emit IncreaseObservationCardinalityNext(observationCardinalityNextOld, observationCardinalityNextNew);
}

function grow(
    Observation[65535] storage self,
    uint16 current,
    uint16 next
) internal returns (uint16) {
    require(current > 0, 'I');
    if (next <= current) return current;

    // Initialize new slots
    for (uint16 i = current; i < next; i++) {
        self[i].blockTimestamp = 1;  // Mark as initialized but empty
    }
    return next;
}
```

## TWAP Calculation

### Basic TWAP

```solidity
// Example: Get TWAP over last 10 minutes (600 seconds)
function getTwap(IUniswapV3Pool pool, uint32 twapInterval)
    external view
    returns (int24 arithmeticMeanTick)
{
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = twapInterval;  // Start time
    secondsAgos[1] = 0;              // End time (now)

    (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);

    int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
    arithmeticMeanTick = int24(tickCumulativesDelta / int56(uint56(twapInterval)));

    // Handle rounding for negative ticks
    if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(twapInterval)) != 0)) {
        arithmeticMeanTick--;
    }
}
```

### OracleLibrary (Periphery)

```solidity
library OracleLibrary {
    /// @notice Calculates time-weighted mean tick
    function consult(address pool, uint32 secondsAgo)
        internal view
        returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity)
    {
        require(secondsAgo != 0, 'BP');

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) =
            IUniswapV3Pool(pool).observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        uint160 secondsPerLiquidityCumulativesDelta =
            secondsPerLiquidityCumulativeX128s[1] - secondsPerLiquidityCumulativeX128s[0];

        arithmeticMeanTick = int24(tickCumulativesDelta / int56(uint56(secondsAgo)));
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(secondsAgo)) != 0))
            arithmeticMeanTick--;

        // Harmonic mean liquidity (useful for liquidity mining)
        uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
        harmonicMeanLiquidity = uint128(secondsAgoX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32));
    }

    /// @notice Given a tick and a token amount, calculates the equivalent in the other token
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }

    /// @notice Get oldest available observation timestamp
    function getOldestObservationSecondsAgo(address pool)
        internal view
        returns (uint32 secondsAgo)
    {
        (, , uint16 observationIndex, uint16 observationCardinality, , , ) =
            IUniswapV3Pool(pool).slot0();

        // Oldest observation is at index + 1 (wrapped)
        uint16 oldestIndex = (observationIndex + 1) % observationCardinality;
        (uint32 oldestTimestamp, , , bool initialized) =
            IUniswapV3Pool(pool).observations(oldestIndex);

        if (initialized) {
            secondsAgo = uint32(block.timestamp) - oldestTimestamp;
        } else {
            // Array not fully filled, oldest is at index 0
            (uint32 timestamp, , , ) = IUniswapV3Pool(pool).observations(0);
            secondsAgo = uint32(block.timestamp) - timestamp;
        }
    }
}
```

## Snapshot Cumulatives Inside

For tracking fees/rewards within a position's tick range.

```solidity
function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
    external view
    returns (
        int56 tickCumulativeInside,
        uint160 secondsPerLiquidityInsideX128,
        uint32 secondsInside
    )
{
    checkTicks(tickLower, tickUpper);

    int56 tickCumulativeLower;
    int56 tickCumulativeUpper;
    uint160 secondsPerLiquidityOutsideLowerX128;
    uint160 secondsPerLiquidityOutsideUpperX128;
    uint32 secondsOutsideLower;
    uint32 secondsOutsideUpper;

    {
        Tick.Info storage lower = ticks[tickLower];
        Tick.Info storage upper = ticks[tickUpper];

        // Get values from tick storage
        tickCumulativeLower = lower.tickCumulativeOutside;
        tickCumulativeUpper = upper.tickCumulativeOutside;
        secondsPerLiquidityOutsideLowerX128 = lower.secondsPerLiquidityOutsideX128;
        secondsPerLiquidityOutsideUpperX128 = upper.secondsPerLiquidityOutsideX128;
        secondsOutsideLower = lower.secondsOutside;
        secondsOutsideUpper = upper.secondsOutside;
    }

    Slot0 memory _slot0 = slot0;

    if (_slot0.tick < tickLower) {
        // Current price below range
        return (
            tickCumulativeLower - tickCumulativeUpper,
            secondsPerLiquidityOutsideLowerX128 - secondsPerLiquidityOutsideUpperX128,
            secondsOutsideLower - secondsOutsideUpper
        );
    } else if (_slot0.tick < tickUpper) {
        // Current price inside range
        uint32 time = _blockTimestamp();
        (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) =
            observations.observeSingle(time, 0, _slot0.tick, _slot0.observationIndex, liquidity, _slot0.observationCardinality);

        return (
            tickCumulative - tickCumulativeLower - tickCumulativeUpper,
            secondsPerLiquidityCumulativeX128 - secondsPerLiquidityOutsideLowerX128 - secondsPerLiquidityOutsideUpperX128,
            time - secondsOutsideLower - secondsOutsideUpper
        );
    } else {
        // Current price above range
        return (
            tickCumulativeUpper - tickCumulativeLower,
            secondsPerLiquidityOutsideUpperX128 - secondsPerLiquidityOutsideLowerX128,
            secondsOutsideUpper - secondsOutsideLower
        );
    }
}
```

## Oracle Best Practices

1. **Cardinality**: Expand cardinality before needing historical data
2. **TWAP Window**: Use longer windows (10-30 min) to resist manipulation
3. **Flash Loan Resistance**: TWAP is resistant to single-block manipulation
4. **Gas Cost**: Longer history = more binary search steps

```
Cardinality vs History Trade-off:
┌─────────────┬──────────────────────────────────────┐
│ Cardinality │ Approximate History (1 block/slot)   │
├─────────────┼──────────────────────────────────────┤
│     1       │ Current block only                   │
│    10       │ ~2 minutes                           │
│   100       │ ~20 minutes                          │
│  1000       │ ~3.3 hours                           │
│ 65535       │ ~9 days                              │
└─────────────┴──────────────────────────────────────┘
```

## Events

```solidity
event IncreaseObservationCardinalityNext(
    uint16 observationCardinalityNextOld,
    uint16 observationCardinalityNextNew
);
```

## Reference Files

### v3-core
- `contracts/libraries/Oracle.sol` - Observation storage and interpolation
- `contracts/UniswapV3Pool.sol` - observe() and snapshotCumulativesInside()

### v3-periphery
- `contracts/libraries/OracleLibrary.sol` - TWAP calculation helpers
