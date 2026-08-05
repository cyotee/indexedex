// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

library UniswapV4PoolKeyAwareRepo {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v4.pool.key.aware");

    struct Storage {
        PoolKey poolKey;
        PoolId poolId;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, PoolKey memory poolKey_) internal {
        layoutStruct.poolKey = poolKey_;
        layoutStruct.poolId = poolKey_.toId();
    }

    function _initialize(PoolKey memory poolKey_) internal {
        _initialize(_layoutStruct(), poolKey_);
    }

    function _poolKey(Storage storage layoutStruct) internal view returns (PoolKey memory poolKey_) {
        return layoutStruct.poolKey;
    }

    function _poolKey() internal view returns (PoolKey memory poolKey_) {
        return _poolKey(_layoutStruct());
    }

    function _poolId(Storage storage layoutStruct) internal view returns (PoolId poolId_) {
        return layoutStruct.poolId;
    }

    function _poolId() internal view returns (PoolId poolId_) {
        return _poolId(_layoutStruct());
    }

    function _currency0(Storage storage layoutStruct) internal view returns (Currency currency0_) {
        return layoutStruct.poolKey.currency0;
    }

    function _currency0() internal view returns (Currency currency0_) {
        return _currency0(_layoutStruct());
    }

    function _currency1(Storage storage layoutStruct) internal view returns (Currency currency1_) {
        return layoutStruct.poolKey.currency1;
    }

    function _currency1() internal view returns (Currency currency1_) {
        return _currency1(_layoutStruct());
    }

    function _fee(Storage storage layoutStruct) internal view returns (uint24 fee_) {
        return layoutStruct.poolKey.fee;
    }

    function _fee() internal view returns (uint24 fee_) {
        return _fee(_layoutStruct());
    }

    function _tickSpacing(Storage storage layoutStruct) internal view returns (int24 tickSpacing_) {
        return layoutStruct.poolKey.tickSpacing;
    }

    function _tickSpacing() internal view returns (int24 tickSpacing_) {
        return _tickSpacing(_layoutStruct());
    }

    function _hooks(Storage storage layoutStruct) internal view returns (IHooks hooks_) {
        return layoutStruct.poolKey.hooks;
    }

    function _hooks() internal view returns (IHooks hooks_) {
        return _hooks(_layoutStruct());
    }
}
