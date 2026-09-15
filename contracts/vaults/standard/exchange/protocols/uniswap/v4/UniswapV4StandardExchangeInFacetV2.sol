// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangePretransfer} from "../IStandardExchangePretransfer.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeInTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeInTargetV2.sol";

contract UniswapV4StandardExchangeInFacetV2 is UniswapV4StandardExchangeInTargetV2, IFacet {
    constructor(address executionDelegate) UniswapV4StandardExchangeInTargetV2(executionDelegate) {}

    function facetName() public pure override returns (string memory name) {
        return type(UniswapV4StandardExchangeInFacetV2).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[1] = type(IStandardExchangePretransfer).interfaceId;
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[2] = IStandardExchangePretransfer.preparePretransfer.selector;
        funcs[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs[1] = IUnlockCallback.unlockCallback.selector;
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
