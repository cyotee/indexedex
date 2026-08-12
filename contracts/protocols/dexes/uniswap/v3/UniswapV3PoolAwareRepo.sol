// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";

/**
 * @title UniswapV3PoolAwareRepo
 * @notice Storage library for the bound Uniswap V3 pool dependency.
 */
library UniswapV3PoolAwareRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v3.pool.aware");

    struct Storage {
        IUniswapV3Pool pool;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layoutStruct) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, IUniswapV3Pool pool_) internal {
        layoutStruct.pool = pool_;
    }

    function _initialize(IUniswapV3Pool pool_) internal {
        _initialize(_layout(), pool_);
    }

    function _uniswapV3Pool(Storage storage layoutStruct) internal view returns (IUniswapV3Pool pool_) {
        return layoutStruct.pool;
    }

    function _uniswapV3Pool() internal view returns (IUniswapV3Pool pool_) {
        return _uniswapV3Pool(_layout());
    }
}
