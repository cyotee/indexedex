// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

library UniswapV4PoolManagerAwareRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v4.pool.manager.aware");

    struct Storage {
        IPoolManager poolManager;
    }

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout) {
        assembly {
            layout.slot := slot_
        }
    }

    function _layout() internal pure returns (Storage storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layout, IPoolManager poolManager_) internal {
        layout.poolManager = poolManager_;
    }

    function _initialize(IPoolManager poolManager_) internal {
        _initialize(_layout(), poolManager_);
    }

    function _poolManager(Storage storage layout) internal view returns (IPoolManager poolManager_) {
        return layout.poolManager;
    }

    function _poolManager() internal view returns (IPoolManager poolManager_) {
        return _poolManager(_layout());
    }
}