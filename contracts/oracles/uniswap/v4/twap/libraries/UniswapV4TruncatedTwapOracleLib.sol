// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    UniswapV4MultiPoolTwapOracleRepo
} from "contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleRepo.sol";

library UniswapV4TruncatedTwapOracleLib {
    int24 internal constant MAX_ABS_TICK_MOVE = 9116;

    struct WriteResult {
        bool written;
        int24 tick;
        uint32 timestamp;
        uint16 index;
        uint16 cardinality;
    }

    function truncate(int24 currentTick, int24 prevTick) internal pure returns (int24 recordedTick) {
        recordedTick = currentTick;
        int24 maxTick = prevTick + MAX_ABS_TICK_MOVE;
        int24 minTick = prevTick - MAX_ABS_TICK_MOVE;
        if (recordedTick > maxTick) {
            recordedTick = maxTick;
        } else if (recordedTick < minTick) {
            recordedTick = minTick;
        }
    }

    function cardinalityNextOrDefault(uint16 stored) internal pure returns (uint16) {
        return stored == 0 ? 1 : stored;
    }

    function write(
        UniswapV4MultiPoolTwapOracleRepo.Storage storage layoutStruct,
        PoolId id_,
        PoolKey memory key_,
        int24 tick_
    ) internal returns (WriteResult memory result) {
        UniswapV4MultiPoolTwapOracleRepo.ObservationState storage state_ = layoutStruct.states[id_];
        mapping(uint16 => IUniswapV4MultiPoolTwapOracle.Observation) storage obs =
            layoutStruct.observations[id_];
        uint32 time_ = uint32(block.timestamp);

        if (!obs[0].initialized) {
            obs[0] = IUniswapV4MultiPoolTwapOracle.Observation({
                blockTimestamp: time_, tickCumulative: 0, prevTick: tick_, initialized: true
            });
            state_.index = 0;
            state_.cardinality = 1;
            uint16 next_ = cardinalityNextOrDefault(state_.cardinalityNext);
            state_.cardinalityNext = next_;
            state_.prevTick = tick_;
            state_.lastTimestamp = time_;
            state_.key = key_;
            state_.keyStored = true;
            result = WriteResult({written: true, tick: tick_, timestamp: time_, index: 0, cardinality: 1});
            return result;
        }

        if (state_.keyStored) {
            PoolKey memory stored = state_.key;
            if (
                Currency.unwrap(stored.currency0) != Currency.unwrap(key_.currency0)
                    || Currency.unwrap(stored.currency1) != Currency.unwrap(key_.currency1)
                    || stored.fee != key_.fee || stored.tickSpacing != key_.tickSpacing
                    || address(stored.hooks) != address(key_.hooks)
            ) {
                revert IUniswapV4MultiPoolTwapOracle.PoolKeyMismatch();
            }
        }

        IUniswapV4MultiPoolTwapOracle.Observation memory last = obs[state_.index];
        if (last.blockTimestamp == time_) {
            return result;
        }

        int24 recordedTick = truncate(tick_, state_.prevTick);
        uint16 cardinality = state_.cardinality;
        uint16 cardinalityNext = cardinalityNextOrDefault(state_.cardinalityNext);
        uint16 indexUpdated;
        uint16 cardinalityUpdated;
        if (cardinalityNext > cardinality && state_.index == cardinality - 1) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }
        indexUpdated = uint16((uint256(state_.index) + 1) % uint256(cardinalityUpdated));

        uint32 delta;
        unchecked {
            delta = time_ - last.blockTimestamp;
        }
        obs[indexUpdated] = IUniswapV4MultiPoolTwapOracle.Observation({
            blockTimestamp: time_,
            tickCumulative: last.tickCumulative + int56(recordedTick) * int56(uint56(delta)),
            prevTick: recordedTick,
            initialized: true
        });
        state_.index = indexUpdated;
        state_.cardinality = cardinalityUpdated;
        state_.cardinalityNext = cardinalityNext;
        state_.prevTick = recordedTick;
        state_.lastTimestamp = time_;

        result = WriteResult({
            written: true,
            tick: recordedTick,
            timestamp: time_,
            index: indexUpdated,
            cardinality: cardinalityUpdated
        });
    }

    function grow(UniswapV4MultiPoolTwapOracleRepo.Storage storage layoutStruct, PoolId id_, uint16 next_)
        internal
        returns (uint16 oldNext, uint16 newNext)
    {
        UniswapV4MultiPoolTwapOracleRepo.ObservationState storage state_ = layoutStruct.states[id_];
        oldNext = cardinalityNextOrDefault(state_.cardinalityNext);
        if (next_ == 0 || next_ <= oldNext) {
            revert IUniswapV4MultiPoolTwapOracle.CardinalityNextTooLow();
        }
        state_.cardinalityNext = next_;
        newNext = next_;
    }

    function observe(
        UniswapV4MultiPoolTwapOracleRepo.Storage storage layoutStruct,
        PoolId id_,
        uint32 time_,
        uint32[] memory secondsAgos,
        int24 tick_
    ) internal view returns (int56[] memory tickCumulatives) {
        tickCumulatives = new int56[](secondsAgos.length);
        UniswapV4MultiPoolTwapOracleRepo.ObservationState storage state_ = layoutStruct.states[id_];
        mapping(uint16 => IUniswapV4MultiPoolTwapOracle.Observation) storage obs =
            layoutStruct.observations[id_];
        if (!obs[0].initialized || state_.cardinality == 0) {
            return tickCumulatives;
        }
        int24 truncatedTick = truncate(tick_, state_.prevTick);
        for (uint256 i; i < secondsAgos.length; ++i) {
            tickCumulatives[i] = observeSingle(
                obs, time_, secondsAgos[i], truncatedTick, state_.index, state_.cardinality
            );
        }
    }

    function consult(
        UniswapV4MultiPoolTwapOracleRepo.Storage storage layoutStruct,
        PoolId id_,
        uint32 time_,
        uint32 secondsAgo,
        int24 tick_
    ) internal view returns (int24 arithmeticMeanTick) {
        if (secondsAgo == 0) {
            revert IUniswapV4MultiPoolTwapOracle.InvalidSecondsAgo();
        }
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;
        int56[] memory tickCumulatives = observe(layoutStruct, id_, time_, secondsAgos, tick_);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        unchecked {
            arithmeticMeanTick = int24(tickCumulativesDelta / int56(uint56(secondsAgo)));
            if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(secondsAgo)) != 0)) {
                arithmeticMeanTick--;
            }
        }
    }

    function getQuoteAtTick(int24 tick, uint128 baseAmount, address baseToken, address quoteToken)
        internal
        pure
        returns (uint256 quoteAmount)
    {
        uint160 sqrtRatioX96 = TickMath.getSqrtPriceAtTick(tick);
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

    function observeSingle(
        mapping(uint16 => IUniswapV4MultiPoolTwapOracle.Observation) storage self,
        uint32 time_,
        uint32 secondsAgo,
        int24 tick_,
        uint16 index,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative) {
        if (secondsAgo == 0) {
            IUniswapV4MultiPoolTwapOracle.Observation memory last = self[index];
            if (last.blockTimestamp != time_) {
                last = transform(last, time_, tick_);
            }
            return last.tickCumulative;
        }

        uint32 target;
        unchecked {
            target = time_ - secondsAgo;
        }

        (IUniswapV4MultiPoolTwapOracle.Observation memory beforeOrAt, IUniswapV4MultiPoolTwapOracle.Observation memory atOrAfter)
        = getSurroundingObservations(self, time_, target, tick_, index, cardinality);

        if (target == beforeOrAt.blockTimestamp) {
            return beforeOrAt.tickCumulative;
        } else if (target == atOrAfter.blockTimestamp) {
            return atOrAfter.tickCumulative;
        } else {
            unchecked {
                uint32 observationTimeDelta = atOrAfter.blockTimestamp - beforeOrAt.blockTimestamp;
                uint32 targetDelta = target - beforeOrAt.blockTimestamp;
                return beforeOrAt.tickCumulative
                    + ((atOrAfter.tickCumulative - beforeOrAt.tickCumulative) / int56(uint56(observationTimeDelta)))
                        * int56(uint56(targetDelta));
            }
        }
    }

    function transform(IUniswapV4MultiPoolTwapOracle.Observation memory last, uint32 blockTimestamp, int24 tick_)
        internal
        pure
        returns (IUniswapV4MultiPoolTwapOracle.Observation memory)
    {
        unchecked {
            uint32 delta = blockTimestamp - last.blockTimestamp;
            return IUniswapV4MultiPoolTwapOracle.Observation({
                blockTimestamp: blockTimestamp,
                tickCumulative: last.tickCumulative + int56(tick_) * int56(uint56(delta)),
                prevTick: tick_,
                initialized: true
            });
        }
    }

    function lte(uint32 time_, uint32 a, uint32 b) internal pure returns (bool) {
        if (a <= time_ && b <= time_) return a <= b;
        uint256 aAdjusted = a > time_ ? a : a + 2 ** 32;
        uint256 bAdjusted = b > time_ ? b : b + 2 ** 32;
        return aAdjusted <= bAdjusted;
    }

    function getSurroundingObservations(
        mapping(uint16 => IUniswapV4MultiPoolTwapOracle.Observation) storage self,
        uint32 time_,
        uint32 target,
        int24 tick_,
        uint16 index,
        uint16 cardinality
    )
        internal
        view
        returns (
            IUniswapV4MultiPoolTwapOracle.Observation memory beforeOrAt,
            IUniswapV4MultiPoolTwapOracle.Observation memory atOrAfter
        )
    {
        beforeOrAt = self[index];

        if (lte(time_, beforeOrAt.blockTimestamp, target)) {
            if (beforeOrAt.blockTimestamp == target) {
                return (beforeOrAt, atOrAfter);
            } else {
                return (beforeOrAt, transform(beforeOrAt, target, tick_));
            }
        }

        beforeOrAt = self[uint16((uint256(index) + 1) % uint256(cardinality))];
        if (!beforeOrAt.initialized) {
            beforeOrAt = self[0];
        }

        if (!lte(time_, beforeOrAt.blockTimestamp, target)) {
            revert IUniswapV4MultiPoolTwapOracle.TargetPredatesOldestObservation(beforeOrAt.blockTimestamp, target);
        }

        return binarySearch(self, time_, target, index, cardinality);
    }

    function binarySearch(
        mapping(uint16 => IUniswapV4MultiPoolTwapOracle.Observation) storage self,
        uint32 time_,
        uint32 target,
        uint16 index,
        uint16 cardinality
    )
        internal
        view
        returns (
            IUniswapV4MultiPoolTwapOracle.Observation memory beforeOrAt,
            IUniswapV4MultiPoolTwapOracle.Observation memory atOrAfter
        )
    {
        uint256 l = (uint256(index) + 1) % uint256(cardinality);
        uint256 r = l + uint256(cardinality) - 1;
        uint256 i;
        while (true) {
            i = (l + r) / 2;
            beforeOrAt = self[uint16(i % uint256(cardinality))];
            if (!beforeOrAt.initialized) {
                l = i + 1;
                continue;
            }
            atOrAfter = self[uint16((i + 1) % uint256(cardinality))];
            bool targetAtOrAfter = lte(time_, beforeOrAt.blockTimestamp, target);
            if (targetAtOrAfter && lte(time_, target, atOrAfter.blockTimestamp)) {
                break;
            }
            if (!targetAtOrAfter) {
                r = i - 1;
            } else {
                l = i + 1;
            }
        }
    }
}
