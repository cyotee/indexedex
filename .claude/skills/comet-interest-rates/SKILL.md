---
name: Comet Interest Rates
description: This skill should be used when the user asks about "interest rates", "APR", "APY", "utilization", "kink", "supply rate", "borrow rate", "accrueInternal", or needs to understand Comet's interest rate model.
version: 0.1.0
---

# Comet Interest Rate Model

Comet uses a kinked interest rate model where rates are lower below the kink utilization and higher above it. This encourages optimal utilization and discourages over-borrowing.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│               KINKED INTEREST RATE MODEL                     │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Rate                                                        │
│   ▲                                                          │
│   │                                    ╱                     │
│   │                                  ╱   High Slope          │
│   │                                ╱                         │
│   │                              ╱                           │
│   │                            ╱                             │
│   │                          *───── Kink Point               │
│   │                        ╱                                 │
│   │                      ╱   Low Slope                       │
│   │                    ╱                                     │
│   │──────────────────╱                                       │
│   │    Base Rate                                             │
│   └──────────────────────────────────────────────────────►   │
│   0%               Kink (e.g., 80%)                 100%     │
│                        Utilization                           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Interest Rate Configuration

```solidity
// Comet.sol immutable configuration
uint public immutable supplyKink;                            // e.g., 80% = 0.8e18
uint public immutable supplyPerSecondInterestRateSlopeLow;   // Rate below kink
uint public immutable supplyPerSecondInterestRateSlopeHigh;  // Rate above kink
uint public immutable supplyPerSecondInterestRateBase;       // Base rate

uint public immutable borrowKink;
uint public immutable borrowPerSecondInterestRateSlopeLow;
uint public immutable borrowPerSecondInterestRateSlopeHigh;
uint public immutable borrowPerSecondInterestRateBase;

// Converted from annual rates at deploy time
constructor(Configuration memory config) {
    supplyPerSecondInterestRateSlopeLow = config.supplyPerYearInterestRateSlopeLow / SECONDS_PER_YEAR;
    supplyPerSecondInterestRateSlopeHigh = config.supplyPerYearInterestRateSlopeHigh / SECONDS_PER_YEAR;
    // ... etc
}
```

## Utilization Calculation

```solidity
/// @notice Get current utilization rate
function getUtilization() public view returns (uint) {
    uint totalSupply_ = presentValueSupply(baseSupplyIndex, totalSupplyBase);
    uint totalBorrow_ = presentValueBorrow(baseBorrowIndex, totalBorrowBase);

    if (totalSupply_ == 0) {
        return 0;
    } else {
        return totalBorrow_ * FACTOR_SCALE / totalSupply_;
    }
}

// FACTOR_SCALE = 1e18
// Utilization of 80% = 0.8e18
```

## Supply Rate Calculation

```solidity
/// @notice Get supply rate at given utilization
/// @dev Does not accrue interest first
function getSupplyRate(uint utilization) public view returns (uint64) {
    if (utilization <= supplyKink) {
        // Below kink: base + slopeLow × utilization
        return safe64(
            supplyPerSecondInterestRateBase +
            mulFactor(supplyPerSecondInterestRateSlopeLow, utilization)
        );
    } else {
        // Above kink: base + slopeLow × kink + slopeHigh × (utilization - kink)
        return safe64(
            supplyPerSecondInterestRateBase +
            mulFactor(supplyPerSecondInterestRateSlopeLow, supplyKink) +
            mulFactor(supplyPerSecondInterestRateSlopeHigh, (utilization - supplyKink))
        );
    }
}

// mulFactor(n, factor) = n * factor / FACTOR_SCALE
```

## Borrow Rate Calculation

```solidity
/// @notice Get borrow rate at given utilization
/// @dev Does not accrue interest first
function getBorrowRate(uint utilization) public view returns (uint64) {
    if (utilization <= borrowKink) {
        return safe64(
            borrowPerSecondInterestRateBase +
            mulFactor(borrowPerSecondInterestRateSlopeLow, utilization)
        );
    } else {
        return safe64(
            borrowPerSecondInterestRateBase +
            mulFactor(borrowPerSecondInterestRateSlopeLow, borrowKink) +
            mulFactor(borrowPerSecondInterestRateSlopeHigh, (utilization - borrowKink))
        );
    }
}
```

## Interest Accrual

### Index System

```solidity
// Storage variables
uint64 internal baseSupplyIndex;   // Accumulates supply interest
uint64 internal baseBorrowIndex;   // Accumulates borrow interest
uint40 internal lastAccrualTime;   // Last accrual timestamp

// BASE_INDEX_SCALE = 1e15
// Indices start at 1e15 (BASE_INDEX_SCALE)
```

### Accrual Logic

```solidity
/// @dev Accrue interest for the market
function accrueInternal() internal {
    uint40 now_ = getNowInternal();
    uint timeElapsed = uint256(now_ - lastAccrualTime);

    if (timeElapsed > 0) {
        // Update interest indices
        (baseSupplyIndex, baseBorrowIndex) = accruedInterestIndices(timeElapsed);

        // Update reward tracking indices
        if (totalSupplyBase >= baseMinForRewards) {
            trackingSupplyIndex += safe64(
                divBaseWei(baseTrackingSupplySpeed * timeElapsed, totalSupplyBase)
            );
        }
        if (totalBorrowBase >= baseMinForRewards) {
            trackingBorrowIndex += safe64(
                divBaseWei(baseTrackingBorrowSpeed * timeElapsed, totalBorrowBase)
            );
        }

        lastAccrualTime = now_;
    }
}

/// @dev Calculate accrued indices
function accruedInterestIndices(uint timeElapsed) internal view returns (uint64, uint64) {
    uint64 baseSupplyIndex_ = baseSupplyIndex;
    uint64 baseBorrowIndex_ = baseBorrowIndex;

    if (timeElapsed > 0) {
        uint utilization = getUtilization();
        uint supplyRate = getSupplyRate(utilization);
        uint borrowRate = getBorrowRate(utilization);

        // index += index × rate × time
        baseSupplyIndex_ += safe64(mulFactor(baseSupplyIndex_, supplyRate * timeElapsed));
        baseBorrowIndex_ += safe64(mulFactor(baseBorrowIndex_, borrowRate * timeElapsed));
    }

    return (baseSupplyIndex_, baseBorrowIndex_);
}
```

## Present Value Calculations

```solidity
/// @dev Convert principal to present value
function presentValue(int104 principal) internal view returns (int256) {
    if (principal >= 0) {
        return signed256(presentValueSupply(baseSupplyIndex, unsigned104(principal)));
    } else {
        return -signed256(presentValueBorrow(baseBorrowIndex, unsigned104(-principal)));
    }
}

/// @dev Present value for supply principal
function presentValueSupply(uint64 supplyIndex, uint104 principal)
    internal pure returns (uint256)
{
    return uint256(principal) * supplyIndex / BASE_INDEX_SCALE;
}

/// @dev Present value for borrow principal
function presentValueBorrow(uint64 borrowIndex, uint104 principal)
    internal pure returns (uint256)
{
    return uint256(principal) * borrowIndex / BASE_INDEX_SCALE;
}
```

## Principal Value Calculations

```solidity
/// @dev Convert present value back to principal
function principalValue(int256 presentValue_) internal view returns (int104) {
    if (presentValue_ >= 0) {
        return signed104(principalValueSupply(baseSupplyIndex, uint256(presentValue_)));
    } else {
        return -signed104(principalValueBorrow(baseBorrowIndex, uint256(-presentValue_)));
    }
}

/// @dev Principal for supply present value
function principalValueSupply(uint64 supplyIndex, uint256 presentValue_)
    internal pure returns (uint104)
{
    return safe104((presentValue_ * BASE_INDEX_SCALE + supplyIndex - 1) / supplyIndex);
}

/// @dev Principal for borrow present value (rounds up)
function principalValueBorrow(uint64 borrowIndex, uint256 presentValue_)
    internal pure returns (uint104)
{
    return safe104((presentValue_ * BASE_INDEX_SCALE + borrowIndex - 1) / borrowIndex);
}
```

## View Functions with Accrual

```solidity
/// @notice Total supply with interest accrued
function totalSupply() external view returns (uint256) {
    (uint64 baseSupplyIndex_, ) = accruedInterestIndices(getNowInternal() - lastAccrualTime);
    return presentValueSupply(baseSupplyIndex_, totalSupplyBase);
}

/// @notice Total borrow with interest accrued
function totalBorrow() external view returns (uint256) {
    (, uint64 baseBorrowIndex_) = accruedInterestIndices(getNowInternal() - lastAccrualTime);
    return presentValueBorrow(baseBorrowIndex_, totalBorrowBase);
}

/// @notice User supply balance with interest accrued
function balanceOf(address account) public view returns (uint256) {
    (uint64 baseSupplyIndex_, ) = accruedInterestIndices(getNowInternal() - lastAccrualTime);
    int104 principal = userBasic[account].principal;
    return principal > 0 ? presentValueSupply(baseSupplyIndex_, unsigned104(principal)) : 0;
}

/// @notice User borrow balance with interest accrued
function borrowBalanceOf(address account) public view returns (uint256) {
    (, uint64 baseBorrowIndex_) = accruedInterestIndices(getNowInternal() - lastAccrualTime);
    int104 principal = userBasic[account].principal;
    return principal < 0 ? presentValueBorrow(baseBorrowIndex_, unsigned104(-principal)) : 0;
}
```

## Rate Math Example

```
Given:
- supplyKink = 80% (0.8e18)
- supplyPerSecondInterestRateBase = 0% (0)
- supplyPerSecondInterestRateSlopeLow = 3% APR / SECONDS_PER_YEAR
- supplyPerSecondInterestRateSlopeHigh = 50% APR / SECONDS_PER_YEAR
- Current utilization = 90% (0.9e18)

Calculation:
Rate = base + slopeLow × kink + slopeHigh × (utilization - kink)
Rate = 0 + (3% × 0.8) + (50% × 0.1)
Rate = 2.4% + 5% = 7.4% APR

At 90% utilization, supply rate would be ~7.4% APR
```

## Interest Spread

The protocol earns the spread between borrow and supply rates:

```
Protocol Revenue = (Borrow Rate × Total Borrows) - (Supply Rate × Total Supply)

Since Total Borrows = Total Supply × Utilization:
Revenue = Borrows × (Borrow Rate - Supply Rate)
```

## Reference Files

- `contracts/Comet.sol:449-486` - getSupplyRate, getBorrowRate, getUtilization
- `contracts/Comet.sol:402-432` - accruedInterestIndices, accrueInternal
- `contracts/CometCore.sol` - Present/principal value functions
- `contracts/CometConfiguration.sol` - Rate configuration struct
