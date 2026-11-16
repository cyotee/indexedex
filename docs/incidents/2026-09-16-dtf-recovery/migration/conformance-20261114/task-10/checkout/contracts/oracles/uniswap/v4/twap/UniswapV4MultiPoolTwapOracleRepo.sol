// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";

library UniswapV4MultiPoolTwapOracleRepo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.oracles.uniswap.v4.twap.oracle"))) - 1);

    struct ObservationState {
        uint16 index;
        uint16 cardinality;
        uint16 cardinalityNext;
        int24 prevTick;
        uint32 lastTimestamp;
        PoolKey key;
        bool keyStored;
    }

    struct Storage {
        mapping(PoolId => mapping(uint16 => IUniswapV4MultiPoolTwapOracle.Observation)) observations;
        mapping(PoolId => ObservationState) states;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    function _state(Storage storage layoutStruct, PoolId id_)
        internal
        view
        returns (ObservationState storage)
    {
        return layoutStruct.states[id_];
    }

    function _state(PoolId id_) internal view returns (ObservationState storage) {
        return _state(_layoutStruct(), id_);
    }

    function _observations(Storage storage layoutStruct, PoolId id_)
        internal
        view
        returns (mapping(uint16 => IUniswapV4MultiPoolTwapOracle.Observation) storage)
    {
        return layoutStruct.observations[id_];
    }

    function _observations(PoolId id_)
        internal
        view
        returns (mapping(uint16 => IUniswapV4MultiPoolTwapOracle.Observation) storage)
    {
        return _observations(_layoutStruct(), id_);
    }

    function _isWritten(Storage storage layoutStruct, PoolId id_) internal view returns (bool) {
        ObservationState storage state_ = layoutStruct.states[id_];
        if (state_.cardinality == 0) {
            return false;
        }
        return layoutStruct.observations[id_][0].initialized;
    }

    function _isWritten(PoolId id_) internal view returns (bool) {
        return _isWritten(_layoutStruct(), id_);
    }
}
