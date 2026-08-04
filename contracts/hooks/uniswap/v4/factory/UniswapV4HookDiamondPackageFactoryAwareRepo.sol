// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";

/**
 * @title UniswapV4HookDiamondPackageFactoryAwareRepo
 * @notice IndexedexManager storage for the hook diamond package callback factory.
 */
library UniswapV4HookDiamondPackageFactoryAwareRepo {
    bytes32 internal constant STORAGE_SLOT = bytes32(
        uint256(keccak256(abi.encode("indexedex.hooks.uniswap.v4.hookDiamondPackageFactory.aware"))) - 1
    );

    struct Storage {
        IUniswapV4HookDiamondPackageCallBackFactory hookDiamondPackageFactory;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, IUniswapV4HookDiamondPackageCallBackFactory factory_)
        internal
    {
        layoutStruct.hookDiamondPackageFactory = factory_;
    }

    function _initialize(IUniswapV4HookDiamondPackageCallBackFactory factory_) internal {
        _initialize(_layoutStruct(), factory_);
    }

    function _hookDiamondPackageFactory(Storage storage layoutStruct)
        internal
        view
        returns (IUniswapV4HookDiamondPackageCallBackFactory)
    {
        return layoutStruct.hookDiamondPackageFactory;
    }

    function _hookDiamondPackageFactory()
        internal
        view
        returns (IUniswapV4HookDiamondPackageCallBackFactory)
    {
        return _hookDiamondPackageFactory(_layoutStruct());
    }
}
