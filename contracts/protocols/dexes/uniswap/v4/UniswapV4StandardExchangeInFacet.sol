// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
    IUniswapV4StandardExchangePositionImport,
    UniswapV4StandardExchangeInTarget
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";

contract UniswapV4StandardExchangeInFacet is UniswapV4StandardExchangeInTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV4StandardExchangeInFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IUniswapV4StandardExchangePositionImport).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](4);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs[2] = IUniswapV4StandardExchangePositionImport.importPosition.selector;
        funcs[3] = IUnlockCallback.unlockCallback.selector;
    }

    function facetMetadata()
        external
        pure
        override
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}