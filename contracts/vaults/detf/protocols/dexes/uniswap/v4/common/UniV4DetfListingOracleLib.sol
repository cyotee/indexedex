// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

/// @title UniV4DetfListingOracleLib
/// @notice App-level listing-oracle observation ring + pair↔DETF exchange-rate helpers.
/// @dev V4 PoolManager core has no observation ring; hooks stay address(0). Storage lives on the DETF diamond.
library UniV4DetfListingOracleLib {
    uint256 internal constant ONE_WAD = 1e18;
    uint16 internal constant CARDINALITY = 32;
    uint32 internal constant DEFAULT_TWAP_SECONDS = 1800;

    error InvalidCreationPrice();
    error ObservationRingNotInitialized();

    /// @dev One ring sample: wall-clock timestamp + tick cumulative (V3 spirit).
    struct Observation {
        uint32 blockTimestamp;
        int56 tickCumulative;
        bool initialized;
    }

    /// @dev Diamond storage for the listing-oracle ring + last write block gate.
    struct Storage {
        Observation[CARDINALITY] observations;
        uint16 index;
        uint16 cardinality;
        bool initialized;
        uint256 lastObservationBlock;
        int24 lastTick;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("vault.detf.uniswap.v4.listing-oracle.repo");

    function _layout() internal pure returns (Storage storage s) {
        bytes32 slot_ = STORAGE_SLOT;
        assembly {
            s.slot := slot_
        }
    }

    /// @notice Bootstrap ring at deploy with first observation at `tick_`.
    function _initialize(int24 tick_) internal {
        Storage storage s = _layout();
        s.cardinality = CARDINALITY;
        s.index = 0;
        s.initialized = true;
        s.lastObservationBlock = block.number;
        s.lastTick = tick_;
        s.observations[0] = Observation({
            blockTimestamp: uint32(block.timestamp),
            tickCumulative: 0,
            initialized: true
        });
    }

    /// @notice Write a new observation from current slot0 tick iff `block.number > lastObservationBlock`.
    /// @return wrote_ True when a new sample was appended.
    function _poke(int24 currentTick_) internal returns (bool wrote_) {
        Storage storage s = _layout();
        if (!s.initialized) revert ObservationRingNotInitialized();
        if (block.number <= s.lastObservationBlock) return false;

        Observation memory last_ = s.observations[s.index];
        uint32 nowTs_ = uint32(block.timestamp);
        uint32 dt_ = nowTs_ - last_.blockTimestamp;
        // Same second is still a new block — accumulate 0 time with previous tick, then store current tick.
        int56 tickCumulative_ = last_.tickCumulative + int56(int256(s.lastTick)) * int56(uint56(dt_));

        uint16 nextIndex_ = uint16((uint256(s.index) + 1) % uint256(s.cardinality));
        s.observations[nextIndex_] = Observation({
            blockTimestamp: nowTs_,
            tickCumulative: tickCumulative_,
            initialized: true
        });
        s.index = nextIndex_;
        s.lastObservationBlock = block.number;
        s.lastTick = currentTick_;
        return true;
    }

    /// @notice True when ring has ≥2 points spanning `twapSeconds_` wall-clock.
    function _twapReady(uint32 twapSeconds_) internal view returns (bool ready_) {
        Storage storage s = _layout();
        if (!s.initialized || s.cardinality == 0) return false;
        // Avoid uint32 underflow when chain time is still below the TWAP window.
        if (block.timestamp < uint256(twapSeconds_)) return false;

        Observation memory newest_ = s.observations[s.index];
        if (!newest_.initialized) return false;

        // Walk backward for an observation at or before (now - twapSeconds).
        uint32 target_ = uint32(block.timestamp) - twapSeconds_;
        if (newest_.blockTimestamp <= target_) {
            // Newest is already older than window — not enough recent samples.
            return false;
        }

        // Need an older sample ≤ target.
        for (uint16 i = 1; i < s.cardinality; ++i) {
            uint16 idx_ = uint16((uint256(s.index) + s.cardinality - i) % uint256(s.cardinality));
            Observation memory obs_ = s.observations[idx_];
            if (!obs_.initialized) return false;
            if (obs_.blockTimestamp <= target_) {
                return true;
            }
        }
        return false;
    }

    /// @notice Geometric mean tick over `twapSeconds_` (V3 spirit via tick cumulative).
    function _consultTwapTick(uint32 twapSeconds_) internal view returns (int24 twapTick_) {
        Storage storage s = _layout();
        if (!s.initialized) revert ObservationRingNotInitialized();
        if (block.timestamp < uint256(twapSeconds_)) return s.lastTick;

        Observation memory newest_ = s.observations[s.index];
        uint32 target_ = uint32(block.timestamp) - twapSeconds_;

        // Interpolate between surrounding observations if needed.
        Observation memory beforeOrAt_;
        Observation memory atOrAfter_;
        bool foundBefore_;
        bool foundAfter_;

        // Include synthetic "now" observation using lastTick.
        uint32 nowTs_ = uint32(block.timestamp);
        int56 nowCumulative_ = newest_.tickCumulative
            + int56(int256(s.lastTick)) * int56(uint56(nowTs_ - newest_.blockTimestamp));

        // Find beforeOrAt (oldest side of window) and atOrAfter (newest side = now).
        atOrAfter_ = Observation({blockTimestamp: nowTs_, tickCumulative: nowCumulative_, initialized: true});
        foundAfter_ = true;

        for (uint16 i = 0; i < s.cardinality; ++i) {
            uint16 idx_ = uint16((uint256(s.index) + s.cardinality - i) % uint256(s.cardinality));
            Observation memory obs_ = s.observations[idx_];
            if (!obs_.initialized) break;
            if (obs_.blockTimestamp <= target_) {
                beforeOrAt_ = obs_;
                foundBefore_ = true;
                // Next newer sample (previous iteration) is atOrAfter for interpolation of target.
                if (i > 0) {
                    uint16 nextIdx_ = uint16((uint256(s.index) + s.cardinality - (i - 1)) % uint256(s.cardinality));
                    Observation memory next_ = s.observations[nextIdx_];
                    // Interpolate tickCumulative at exact target timestamp.
                    if (beforeOrAt_.blockTimestamp != target_ && next_.blockTimestamp > target_) {
                        uint32 span_ = next_.blockTimestamp - beforeOrAt_.blockTimestamp;
                        uint32 elapsed_ = target_ - beforeOrAt_.blockTimestamp;
                        int56 cumDelta_ = next_.tickCumulative - beforeOrAt_.tickCumulative;
                        beforeOrAt_.tickCumulative =
                            beforeOrAt_.tickCumulative + (cumDelta_ * int56(uint56(elapsed_))) / int56(uint56(span_));
                        beforeOrAt_.blockTimestamp = target_;
                    }
                }
                break;
            }
        }

        if (!foundBefore_ || !foundAfter_) {
            // Fallback: use newest tick.
            return s.lastTick;
        }

        int56 tickCumulativeDelta_ = atOrAfter_.tickCumulative - beforeOrAt_.tickCumulative;
        uint32 timeDelta_ = atOrAfter_.blockTimestamp - beforeOrAt_.blockTimestamp;
        if (timeDelta_ == 0) return s.lastTick;
        int56 averageTick_ = tickCumulativeDelta_ / int56(uint56(timeDelta_));
        // Round toward negative infinity for negative averages (V3 spirit).
        if (tickCumulativeDelta_ < 0 && (tickCumulativeDelta_ % int56(uint56(timeDelta_)) != 0)) {
            averageTick_--;
        }
        twapTick_ = int24(averageTick_);
    }

    /// @notice Convert sqrtPriceX96 → price of currency1 per currency0 in WAD (1e18).
    function _price1Per0Wad(uint160 sqrtPriceX96_) internal pure returns (uint256 price1Per0_) {
        if (sqrtPriceX96_ == 0) revert InvalidCreationPrice();
        // price = (sqrtP / 2^96)^2 = sqrtP^2 / 2^192
        // Use two-step mulDiv to avoid intermediate overflow: (sqrtP * 1e18 / 2^96) * sqrtP / 2^96
        uint256 num_ = Math.mulDiv(uint256(sqrtPriceX96_), ONE_WAD, uint256(1) << 96);
        price1Per0_ = Math.mulDiv(num_, uint256(sqrtPriceX96_), uint256(1) << 96);
    }

    /// @notice DETF per 1 pair in WAD, adjusting for decimals (DETF always 18).
    /// @param sqrtPriceX96_ Pool sqrt price.
    /// @param pairIsCurrency0_ True if pairToken == currency0 (DETF == currency1).
    /// @param pairDecimals_ IERC20Metadata.decimals of pairToken.
    function _priceDetfPerPairWad(uint160 sqrtPriceX96_, bool pairIsCurrency0_, uint8 pairDecimals_)
        internal
        pure
        returns (uint256 r_)
    {
        uint256 p1Per0_ = _price1Per0Wad(sqrtPriceX96_);
        if (pairIsCurrency0_) {
            // DETF is currency1: R = price1Per0 * 10^(18 - pairDecimals) / 1? already WAD for 18/18
            // price1Per0 is (token1/token0) in raw units as WAD-scaled for equal decimals.
            // Adjust: raw1/raw0 * 10^(dec0 - dec1) = human1/human0; we want humanDetf/humanPair.
            // DETF dec=18, pair dec=pairDecimals.
            // p1Per0_wad ≈ raw1/raw0 * 1e18. human1/human0 = raw1/raw0 * 10^(dec0-dec1).
            // detf per pair (human) = human1/human0 = raw1/raw0 * 10^(pairDecimals - 18)
            // = p1Per0_wad / 1e18 * 10^(pairDecimals - 18) → scale back to WAD:
            // R_wad = p1Per0_wad * 10^(pairDecimals - 18) when pairDecimals < 18 use div.
            r_ = _scalePriceForDecimals(p1Per0_, pairDecimals_, 18);
        } else {
            // DETF is currency0, pair is currency1: R = 1 / price1Per0 adjusted
            // price0Per1_wad = 1e18 * 1e18 / p1Per0
            if (p1Per0_ == 0) revert InvalidCreationPrice();
            uint256 p0Per1_ = Math.mulDiv(ONE_WAD, ONE_WAD, p1Per0_);
            // human0/human1 = raw0/raw1 * 10^(dec1 - dec0) = p0Per1 * 10^(pairDecimals - 18)
            r_ = _scalePriceForDecimals(p0Per1_, pairDecimals_, 18);
        }
    }

    /// @dev Scale a raw-unit WAD price (tokenOut/tokenIn with out=18, in=pairDecimals semantics)
    /// when `pWad` was computed as rawOut/rawIn * 1e18 without decimal adjust.
    /// target: humanOut/humanIn * 1e18 with outDec=18, inDec=pairDecimals.
    /// humanOut/humanIn = rawOut/rawIn * 10^(inDec - outDec) = rawOut/rawIn * 10^(pairDecimals - 18)
    /// R_wad = pWad * 10^(pairDecimals - 18)
    function _scalePriceForDecimals(uint256 pWad_, uint8 inDecimals_, uint8 outDecimals_)
        internal
        pure
        returns (uint256)
    {
        if (inDecimals_ == outDecimals_) return pWad_;
        if (inDecimals_ > outDecimals_) {
            return pWad_ * (10 ** (inDecimals_ - outDecimals_));
        }
        return pWad_ / (10 ** (outDecimals_ - inDecimals_));
    }

    /// @notice Gross DETF from pair notional at rate R (WAD).
    function _detfFromPairNotional(uint256 pairNotional_, uint256 rDetfPerPairWad_)
        internal
        pure
        returns (uint256 grossDetf_)
    {
        grossDetf_ = Math.mulDiv(pairNotional_, rDetfPerPairWad_, ONE_WAD);
    }

    /// @notice Option B: pool init assumed by caller; needs TWAP ready + active in-range L.
    function _isMarketMarkUsable(bool poolInitialized_, bool twapReady_, uint128 activeLiquidity_)
        internal
        pure
        returns (bool)
    {
        return poolInitialized_ && twapReady_ && activeLiquidity_ > 0;
    }

    /// @notice Synthetic = (P_twap / P_creation) * 1e18 when B usable; else 1e18.
    /// @dev Both prices as detf-per-pair WAD so synthetic > 1e18 means DETF richer vs creation.
    function _syntheticPrice(bool marketMarkUsable_, uint256 pTwapDetfPerPair_, uint256 pCreationDetfPerPair_)
        internal
        pure
        returns (uint256 synthetic_)
    {
        if (!marketMarkUsable_ || pCreationDetfPerPair_ == 0) return ONE_WAD;
        synthetic_ = Math.mulDiv(pTwapDetfPerPair_, ONE_WAD, pCreationDetfPerPair_);
    }

    /// @notice sqrtPriceX96 from tick via TickMath.
    function _sqrtPriceX96AtTick(int24 tick_) internal pure returns (uint160) {
        return TickMath.getSqrtPriceAtTick(tick_);
    }
}
