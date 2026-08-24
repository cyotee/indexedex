// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4TwapAdapterErrors
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4TwapAdapterErrors.sol";
import {
    UniswapV4TruncatedTwapOracleLib
} from "contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol";

/// @notice Frozen AggregatorV3 monomorph. Example `maxWriteAge` is 300 seconds. `decimals()` is 18.
contract UniswapV4TwapAggregatorV3Adapter is IUniswapV4TwapAdapterErrors {
    IUniswapV4MultiPoolTwapOracle public immutable oracle;
    Currency public immutable currency0;
    Currency public immutable currency1;
    uint24 public immutable fee;
    int24 public immutable tickSpacing;
    IHooks public immutable hooks;
    PoolId public immutable poolId;
    uint32 public immutable secondsAgo;
    bool public immutable invert;
    uint32 public immutable maxWriteAge;
    address public immutable baseToken;
    address public immutable quoteToken;

    constructor(
        IUniswapV4MultiPoolTwapOracle oracle_,
        PoolKey memory key_,
        uint32 secondsAgo_,
        bool invert_,
        uint32 maxWriteAge_
    ) {
        if (address(oracle_) == address(0)) revert ZeroOracle();
        if (secondsAgo_ == 0) revert ZeroSecondsAgo();
        if (maxWriteAge_ == 0) revert ZeroMaxWriteAge();
        if (oracle_.poolManager() == address(0)) revert IUniswapV4MultiPoolTwapOracle.ZeroPoolManager();

        oracle = oracle_;
        currency0 = key_.currency0;
        currency1 = key_.currency1;
        fee = key_.fee;
        tickSpacing = key_.tickSpacing;
        hooks = key_.hooks;
        poolId = key_.toId();
        secondsAgo = secondsAgo_;
        invert = invert_;
        maxWriteAge = maxWriteAge_;

        address currency0_ = Currency.unwrap(key_.currency0);
        address currency1_ = Currency.unwrap(key_.currency1);
        if (invert_) {
            baseToken = currency1_;
            quoteToken = currency0_;
        } else {
            baseToken = currency0_;
            quoteToken = currency1_;
        }
        _requireDecimals(currency0_);
        _requireDecimals(currency1_);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function latestAnswer() external view returns (int256) {
        (, int256 answer,,,) = latestRoundData();
        return answer;
    }

    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        uint16 cardinality;
        uint32 lastTimestamp;
        {
            uint16 index_;
            uint16 cardinalityNext_;
            int24 prevTick_;
            (index_, cardinality, cardinalityNext_, prevTick_, lastTimestamp) = oracle.getState(poolId);
            index_;
            cardinalityNext_;
            prevTick_;
        }
        IUniswapV4MultiPoolTwapOracle.Observation memory first = oracle.getObservation(poolId, 0);
        if (cardinality == 0 || !first.initialized) {
            return (0, 0, 0, 0, 0);
        }
        uint256 age = oracle.writeAge(poolId);
        if (age > maxWriteAge) {
            revert StaleObservation(age, maxWriteAge);
        }
        int24 tick_ = oracle.consult(poolId, secondsAgo);
        uint256 quoteAmount =
            UniswapV4TruncatedTwapOracleLib.getQuoteAtTick(tick_, 1e18, baseToken, quoteToken);
        answer = int256(quoteAmount);
        updatedAt = lastTimestamp;
        return (1, answer, updatedAt, updatedAt, 1);
    }

    function getRoundData(uint80 roundId)
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 latestId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            latestRoundData();
        if (latestId != 1 || roundId != 1) {
            revert RoundNotFound(roundId);
        }
        return (latestId, answer, startedAt, updatedAt, answeredInRound);
    }

    function _requireDecimals(address token_) internal view {
        if (token_ == address(0)) {
            return;
        }
        try IERC20Metadata(token_).decimals() returns (uint8) {}
        catch {
            revert DecimalsQueryFailed();
        }
    }
}
