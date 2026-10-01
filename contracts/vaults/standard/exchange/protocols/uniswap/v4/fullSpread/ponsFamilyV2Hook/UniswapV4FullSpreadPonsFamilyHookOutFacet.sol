// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4FullSpreadPonsFamilyHookOutExecutionBinding} from "./interfaces/IUniswapV4FullSpreadPonsFamilyHookComponentBindings.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol";

/// @notice Execute-only exchangeOut (Option 1b + 2b delegate). Preview is on OutQueryFacet.
contract UniswapV4FullSpreadPonsFamilyHookOutFacet is UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget, IFacet {
    constructor(address executionDelegate) UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget(executionDelegate) {}

    function facetName() public pure returns (string memory name) {
        return type(UniswapV4FullSpreadPonsFamilyHookOutFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[1] = type(IUniswapV4FullSpreadPonsFamilyHookOutExecutionBinding).interfaceId;
        interfaces[0] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[1] = IUniswapV4FullSpreadPonsFamilyHookOutExecutionBinding.UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE.selector;
        funcs[0] = IStandardExchangeOut.exchangeOut.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
