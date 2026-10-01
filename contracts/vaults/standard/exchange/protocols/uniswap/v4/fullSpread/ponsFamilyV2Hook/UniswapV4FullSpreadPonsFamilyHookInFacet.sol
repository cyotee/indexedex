// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4FullSpreadPonsFamilyHookInExecutionBinding} from "./interfaces/IUniswapV4FullSpreadPonsFamilyHookComponentBindings.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4FullSpreadPonsFamilyHookInTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookInTarget.sol";

contract UniswapV4FullSpreadPonsFamilyHookInFacet is UniswapV4FullSpreadPonsFamilyHookInTarget, IFacet {
    constructor(address executionDelegate) UniswapV4FullSpreadPonsFamilyHookInTarget(executionDelegate) {}

    function facetName() public pure override returns (string memory name) {
        return type(UniswapV4FullSpreadPonsFamilyHookInFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[1] = type(IUniswapV4FullSpreadPonsFamilyHookInExecutionBinding).interfaceId;
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[2] = IUniswapV4FullSpreadPonsFamilyHookInExecutionBinding.UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.selector;
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
