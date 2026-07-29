// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";

/**
 * @title UniswapV3FactoryAwareRepo
 * @notice Storage library for the expected Uniswap V3 factory used at vault init validation.
 */
library UniswapV3FactoryAwareRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v3.factory.aware");

    struct Storage {
        IUniswapV3Factory factory;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layoutStruct) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, IUniswapV3Factory factory_) internal {
        layoutStruct.factory = factory_;
    }

    function _initialize(IUniswapV3Factory factory_) internal {
        _initialize(_layout(), factory_);
    }

    function _uniswapV3Factory(Storage storage layoutStruct) internal view returns (IUniswapV3Factory factory_) {
        return layoutStruct.factory;
    }

    function _uniswapV3Factory() internal view returns (IUniswapV3Factory factory_) {
        return _uniswapV3Factory(_layout());
    }
}
