// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IUniswapV4MultiPoolTwapOracle} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";

/// @notice Creation and address prediction for Uniswap V4 TWAP adapters.
interface IUniswapV4TwapAdapterFactory {
    error AdapterDeployFailed();

    event MorphoAdapterCreated(
        address adapter,
        address oracle,
        bytes32 poolId,
        uint32 secondsAgo,
        bool collateralIsCurrency0,
        uint32 maxWriteAge
    );
    event AggregatorV3AdapterCreated(
        address adapter, address oracle, bytes32 poolId, uint32 secondsAgo, bool invert, uint32 maxWriteAge
    );

    function createMorphoOracle(
        IUniswapV4MultiPoolTwapOracle oracle,
        PoolKey calldata key,
        uint32 secondsAgo,
        bool collateralIsCurrency0,
        uint32 maxWriteAge
    ) external returns (address adapter);

    function createAggregatorV3(
        IUniswapV4MultiPoolTwapOracle oracle,
        PoolKey calldata key,
        uint32 secondsAgo,
        bool invert,
        uint32 maxWriteAge
    ) external returns (address adapter);

    function predictMorphoOracle(
        IUniswapV4MultiPoolTwapOracle oracle,
        PoolKey calldata key,
        uint32 secondsAgo,
        bool collateralIsCurrency0,
        uint32 maxWriteAge
    ) external view returns (address);

    function predictAggregatorV3(
        IUniswapV4MultiPoolTwapOracle oracle,
        PoolKey calldata key,
        uint32 secondsAgo,
        bool invert,
        uint32 maxWriteAge
    ) external view returns (address);
}
