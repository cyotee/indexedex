// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

library UniswapV4PoolManagerAwareRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v4.pool.manager.aware");

    struct Storage {
        IPoolManager poolManager;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, IPoolManager poolManager_) internal {
        layoutStruct.poolManager = poolManager_;
    }

    function _initialize(IPoolManager poolManager_) internal {
        _initialize(_layoutStruct(), poolManager_);
    }

    function _poolManager(Storage storage layoutStruct) internal view returns (IPoolManager poolManager_) {
        return layoutStruct.poolManager;
    }

    function _poolManager() internal view returns (IPoolManager poolManager_) {
        return _poolManager(_layoutStruct());
    }
}