// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    UniswapV4TwapOraclePoolManagerAwareRepo
} from "contracts/oracles/uniswap/v4/twap/aware/UniswapV4TwapOraclePoolManagerAwareRepo.sol";
import {
    UniswapV4MultiPoolTwapOracleRepo
} from "contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleRepo.sol";
import {
    UniswapV4TruncatedTwapOracleLib
} from "contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol";

contract UniswapV4MultiPoolTwapOracleTarget is IUniswapV4MultiPoolTwapOracle {
    using StateLibrary for IPoolManager;

    function poolManager() public view returns (address) {
        return address(UniswapV4TwapOraclePoolManagerAwareRepo._poolManager());
    }

    function MAX_ABS_TICK_MOVE() public pure returns (int24) {
        return UniswapV4TruncatedTwapOracleLib.MAX_ABS_TICK_MOVE;
    }

    function update(PoolKey calldata key) public returns (bool written) {
        PoolId id_ = key.toId();
        IPoolManager manager_ = UniswapV4TwapOraclePoolManagerAwareRepo._poolManager();
        (uint160 sqrtPriceX96, int24 tick_,,) = StateLibrary.getSlot0(manager_, id_);
        if (sqrtPriceX96 == 0) {
            return false;
        }
        UniswapV4TruncatedTwapOracleLib.WriteResult memory result =
            UniswapV4TruncatedTwapOracleLib.write(UniswapV4MultiPoolTwapOracleRepo._layoutStruct(), id_, key, tick_);
        if (result.written) {
            emit ObservationWritten(id_, result.tick, result.timestamp, result.index, result.cardinality);
        }
        return result.written;
    }

    function update(PoolKey[] calldata keys) public returns (bool[] memory written) {
        written = new bool[](keys.length);
        for (uint256 i; i < keys.length; ++i) {
            written[i] = update(keys[i]);
        }
    }

    function increaseCardinalityNext(PoolId id, uint16 next) public {
        (uint16 oldNext, uint16 newNext) =
            UniswapV4TruncatedTwapOracleLib.grow(UniswapV4MultiPoolTwapOracleRepo._layoutStruct(), id, next);
        emit CardinalityNextIncreased(id, oldNext, newNext);
    }

    function observe(PoolId id, uint32[] calldata secondsAgos)
        public
        view
        returns (int56[] memory tickCumulatives)
    {
        UniswapV4MultiPoolTwapOracleRepo.Storage storage layoutStruct =
            UniswapV4MultiPoolTwapOracleRepo._layoutStruct();
        int24 tick_ = 0;
        if (UniswapV4MultiPoolTwapOracleRepo._isWritten(layoutStruct, id)) {
            IPoolManager manager_ = UniswapV4TwapOraclePoolManagerAwareRepo._poolManager();
            (uint160 sqrtPriceX96, int24 currentTick,,) = StateLibrary.getSlot0(manager_, id);
            if (sqrtPriceX96 == 0) {
                tick_ = 0;
            } else {
                tick_ = currentTick;
            }
        }
        return UniswapV4TruncatedTwapOracleLib.observe(
            layoutStruct, id, uint32(block.timestamp), secondsAgos, tick_
        );
    }

    function consult(PoolId id, uint32 secondsAgo) public view returns (int24 arithmeticMeanTick) {
        UniswapV4MultiPoolTwapOracleRepo.Storage storage layoutStruct =
            UniswapV4MultiPoolTwapOracleRepo._layoutStruct();
        int24 tick_ = 0;
        if (UniswapV4MultiPoolTwapOracleRepo._isWritten(layoutStruct, id)) {
            IPoolManager manager_ = UniswapV4TwapOraclePoolManagerAwareRepo._poolManager();
            (uint160 sqrtPriceX96, int24 currentTick,,) = StateLibrary.getSlot0(manager_, id);
            if (sqrtPriceX96 == 0) {
                tick_ = 0;
            } else {
                tick_ = currentTick;
            }
        }
        return UniswapV4TruncatedTwapOracleLib.consult(
            layoutStruct, id, uint32(block.timestamp), secondsAgo, tick_
        );
    }

    function getPoolKey(PoolId id) public view returns (PoolKey memory) {
        return UniswapV4MultiPoolTwapOracleRepo._state(id).key;
    }

    function getState(PoolId id)
        public
        view
        returns (uint16 index, uint16 cardinality, uint16 cardinalityNext, int24 prevTick, uint32 lastTimestamp)
    {
        UniswapV4MultiPoolTwapOracleRepo.ObservationState storage state_ =
            UniswapV4MultiPoolTwapOracleRepo._state(id);
        index = state_.index;
        cardinality = state_.cardinality;
        cardinalityNext = UniswapV4TruncatedTwapOracleLib.cardinalityNextOrDefault(state_.cardinalityNext);
        prevTick = state_.prevTick;
        lastTimestamp = state_.lastTimestamp;
    }

    function getObservation(PoolId id, uint16 index)
        public
        view
        returns (IUniswapV4MultiPoolTwapOracle.Observation memory)
    {
        return UniswapV4MultiPoolTwapOracleRepo._observations(id)[index];
    }

    function writeAge(PoolId id) public view returns (uint256) {
        UniswapV4MultiPoolTwapOracleRepo.Storage storage layoutStruct =
            UniswapV4MultiPoolTwapOracleRepo._layoutStruct();
        if (!UniswapV4MultiPoolTwapOracleRepo._isWritten(layoutStruct, id)) {
            return 0;
        }
        return uint256(block.timestamp) - uint256(layoutStruct.states[id].lastTimestamp);
    }
}
