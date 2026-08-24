// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    UniswapV4TwapMorphoOracle
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapMorphoOracle.sol";
import {
    UniswapV4TwapAggregatorV3Adapter
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapAggregatorV3Adapter.sol";

contract UniswapV4TwapAdapterFactory {
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
    ) external returns (address adapter) {
        bytes32 salt = keccak256(abi.encode(oracle, key, secondsAgo, collateralIsCurrency0, maxWriteAge));
        bytes memory bytecode = abi.encodePacked(
            type(UniswapV4TwapMorphoOracle).creationCode,
            abi.encode(oracle, key, secondsAgo, collateralIsCurrency0, maxWriteAge)
        );
        address predicted = _predict(bytecode, salt);
        if (predicted.code.length > 0) {
            return predicted;
        }
        adapter = address(
            new UniswapV4TwapMorphoOracle{salt: salt}(
                oracle, key, secondsAgo, collateralIsCurrency0, maxWriteAge
            )
        );
        emit MorphoAdapterCreated(
            adapter, address(oracle), PoolId.unwrap(key.toId()), secondsAgo, collateralIsCurrency0, maxWriteAge
        );
    }

    function createAggregatorV3(
        IUniswapV4MultiPoolTwapOracle oracle,
        PoolKey calldata key,
        uint32 secondsAgo,
        bool invert,
        uint32 maxWriteAge
    ) external returns (address adapter) {
        bytes32 salt = keccak256(abi.encode(oracle, key, secondsAgo, invert, maxWriteAge));
        bytes memory bytecode = abi.encodePacked(
            type(UniswapV4TwapAggregatorV3Adapter).creationCode,
            abi.encode(oracle, key, secondsAgo, invert, maxWriteAge)
        );
        address predicted = _predict(bytecode, salt);
        if (predicted.code.length > 0) {
            return predicted;
        }
        adapter = address(new UniswapV4TwapAggregatorV3Adapter{salt: salt}(oracle, key, secondsAgo, invert, maxWriteAge));
        emit AggregatorV3AdapterCreated(
            adapter, address(oracle), PoolId.unwrap(key.toId()), secondsAgo, invert, maxWriteAge
        );
    }

    function predictMorphoOracle(
        IUniswapV4MultiPoolTwapOracle oracle,
        PoolKey calldata key,
        uint32 secondsAgo,
        bool collateralIsCurrency0,
        uint32 maxWriteAge
    ) external view returns (address) {
        bytes32 salt = keccak256(abi.encode(oracle, key, secondsAgo, collateralIsCurrency0, maxWriteAge));
        bytes memory bytecode = abi.encodePacked(
            type(UniswapV4TwapMorphoOracle).creationCode,
            abi.encode(oracle, key, secondsAgo, collateralIsCurrency0, maxWriteAge)
        );
        return _predict(bytecode, salt);
    }

    function predictAggregatorV3(
        IUniswapV4MultiPoolTwapOracle oracle,
        PoolKey calldata key,
        uint32 secondsAgo,
        bool invert,
        uint32 maxWriteAge
    ) external view returns (address) {
        bytes32 salt = keccak256(abi.encode(oracle, key, secondsAgo, invert, maxWriteAge));
        bytes memory bytecode = abi.encodePacked(
            type(UniswapV4TwapAggregatorV3Adapter).creationCode,
            abi.encode(oracle, key, secondsAgo, invert, maxWriteAge)
        );
        return _predict(bytecode, salt);
    }

    function _predict(bytes memory bytecode, bytes32 salt) internal view returns (address) {
        return address(
            uint160(
                uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))))
            )
        );
    }
}
