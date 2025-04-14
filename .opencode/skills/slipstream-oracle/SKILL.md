---
name: Slipstream Oracle
description: This skill should be used when the user asks about "oracle", "TWAP", "observe", "observation", "price history", "cardinality", "tickCumulative", or needs to understand the oracle system.
version: 0.1.0
---

# Slipstream Oracle

Slipstream pools include a built-in TWAP (Time-Weighted Average Price) oracle that records price observations for historical price queries.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    ORACLE SYSTEM                             │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Observations Array (Circular Buffer):                       │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                                                         │ │
│  │  Index:  [0]    [1]    [2]    [3]   ...   [N-1]         │ │
│  │           │      │      │      │            │           │ │
│  │          obs    obs    obs    obs   ...    obs          │ │
│  │           │                                  │           │ │
│  │           └──────── Circular ───────────────┘           │ │
│  │                                                         │ │
│  │  Each observation contains:                             │ │
│  │  ├── blockTimestamp                                     │ │
│  │  ├── tickCumulative (integral of tick over time)        │ │
│  │  ├── secondsPerLiquidityCumulativeX128                  │ │
│  │  └── initialized flag                                   │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  TWAP Calculation:                                           │
│  ├── Query: observe([60, 0]) → [obs_60s_ago, obs_now]        │
│  ├── tickDelta = tickCumulative[now] - tickCumulative[60s]   │
│  ├── timeDelta = 60 seconds                                  │
│  └── TWAP tick = tickDelta / timeDelta                       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Observation Structure

```solidity
// Oracle.sol

struct Observation {
    uint32 blockTimestamp;                       // Timestamp of observation
    int56 tickCumulative;                        // Cumulative tick * time
    uint160 secondsPerLiquidityCumulativeX128;  // Cumulative seconds per liquidity
    bool initialized;                            // Whether observation is valid
}

// Pool stores up to 65,535 observations
Oracle.Observation[65535] public observations;
```

## Pool Oracle State

```solidity
// CLPool.sol - Slot0 contains oracle indices

struct Slot0 {
    uint160 sqrtPriceX96;
    int24 tick;
    uint16 observationIndex;            // Current index in observations array
    uint16 observationCardinality;      // Current size of observations array
    uint16 observationCardinalityNext;  // Requested size (grows on next write)
    bool unlocked;
}
```

## Writing Observations

```solidity
// Oracle.sol

/// @notice Write a new observation
/// @param self Observations array
/// @param index Current observation index
/// @param blockTimestamp Current block timestamp
/// @param tick Current tick
/// @param liquidity Current liquidity
/// @param cardinality Current array size
/// @param cardinalityNext Requested array size
/// @return indexUpdated New observation index
/// @return cardinalityUpdated New array size
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

    // Expand array if requested and not yet expanded
    if (cardinalityNext > cardinality && index == (cardinality - 1)) {
        cardinalityUpdated = cardinalityNext;
    } else {
        cardinalityUpdated = cardinality;
    }

    // Calculate new index (circular)
    indexUpdated = (index + 1) % cardinalityUpdated;

    // Calculate cumulative values
    uint32 delta = blockTimestamp - last.blockTimestamp;

    self[indexUpdated] = Observation({
        blockTimestamp: blockTimestamp,
        tickCumulative: last.tickCumulative + int56(tick) * int56(uint56(delta)),
        secondsPerLiquidityCumulativeX128: last.secondsPerLiquidityCumulativeX128 +
            ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1)),
        initialized: true
    });
}
```

## Observation Timing

```solidity
// Observations are written during swaps when tick changes

function swap(...) external {
    // ... swap logic ...

    // Write observation if tick changed
    if (state.tick != slot0Start.tick) {
        (slot0.observationIndex, slot0.observationCardinality) = observations.write(
            slot0Start.observationIndex,
            _blockTimestamp(),
            slot0Start.tick,
            cache.liquidityStart,
            slot0Start.observationCardinality,
            slot0Start.observationCardinalityNext
        );
    }

    // ... continue swap ...
}
```

## Observe Function

```solidity
// CLPool.sol

/// @notice Query historical observations
/// @param secondsAgos Array of seconds ago to query
/// @return tickCumulatives Cumulative tick values at each time
/// @return secondsPerLiquidityCumulativeX128s Cumulative seconds/liquidity at each time
function observe(uint32[] calldata secondsAgos)
    external
    view
    returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulativeX128s
    )
{
    return observations.observe(
        _blockTimestamp(),
        secondsAgos,
        slot0.tick,
        slot0.observationIndex,
        liquidity,
        slot0.observationCardinality
    );
}
```

## Oracle Observe Implementation

```solidity
// Oracle.sol

/// @notice Get observations at specific times in the past
function observe(
    Observation[65535] storage self,
    uint32 time,
    uint32[] memory secondsAgos,
    int24 tick,
    uint16 index,
    uint128 liquidity,
    uint16 cardinality
) internal view returns (
    int56[] memory tickCumulatives,
    uint160[] memory secondsPerLiquidityCumulativeX128s
) {
    require(cardinality > 0, "I");

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

/// @notice Get observation at a specific time in the past
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
        // Current observation
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
        return (beforeOrAt.tickCumulative, beforeOrAt.secondsPerLiquidityCumulativeX128);
    } else if (target == atOrAfter.blockTimestamp) {
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

## Increase Cardinality

```solidity
// CLPool.sol

/// @notice Increase the maximum number of observations stored
/// @param observationCardinalityNext The desired minimum number of observations
function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external lock {
    uint16 observationCardinalityNextOld = slot0.observationCardinalityNext;

    require(observationCardinalityNext > observationCardinalityNextOld, "LOK");

    slot0.observationCardinalityNext = observationCardinalityNext;

    emit IncreaseObservationCardinalityNext(observationCardinalityNextOld, observationCardinalityNext);
}
```

## TWAP Calculation Example

```solidity
// Calculate 30-minute TWAP

// Query observations
uint32[] memory secondsAgos = new uint32[](2);
secondsAgos[0] = 1800;  // 30 minutes ago
secondsAgos[1] = 0;      // Now

(int56[] memory tickCumulatives,) = pool.observe(secondsAgos);

// Calculate average tick
int56 tickDelta = tickCumulatives[1] - tickCumulatives[0];
int24 arithmeticMeanTick = int24(tickDelta / 1800);

// Adjust for negative rounding
if (tickDelta < 0 && (tickDelta % 1800 != 0)) arithmeticMeanTick--;

// Convert tick to price
uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(arithmeticMeanTick);

// price = (sqrtPriceX96 / 2^96)^2
uint256 price = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1 << 64) >> 128;
```

## Seconds Per Liquidity

```solidity
// Used for liquidity mining calculations
// Tracks how long each unit of liquidity has been active

// secondsPerLiquidityCumulativeX128 = integral of (1/liquidity) over time

// For position (tickLower, tickUpper):
// secondsInside = (current - position's snapshot) when price is in range

// This enables time-weighted liquidity rewards
```

## Oracle Security Considerations

```solidity
// 1. Observations only updated once per block
//    - Prevents manipulation within same block

// 2. Binary search for historical values
//    - Efficient O(log n) lookup

// 3. Interpolation between observations
//    - Smooth values even with sparse writes

// 4. Cardinality limits storage
//    - Default: 1 (only current)
//    - Maximum: 65,535 observations

// 5. TWAP resistant to manipulation
//    - Manipulator must sustain price for entire period
```

## Events

```solidity
event IncreaseObservationCardinalityNext(
    uint16 observationCardinalityNextOld,
    uint16 observationCardinalityNextNew
);
```

## Reference Files

- `contracts/core/CLPool.sol` - observe() function
- `contracts/core/libraries/Oracle.sol` - Oracle implementation
- `contracts/core/libraries/TickMath.sol` - Tick/price conversion
