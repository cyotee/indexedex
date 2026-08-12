// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";

contract UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet is
    UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](4);
        funcs[0] = IHook.withdraw.selector;
        funcs[1] = IHook.previewWithdraw.selector;
        funcs[2] = IHook.withdrawFlexible.selector;
        funcs[3] = IHook.previewWithdrawFlexible.selector;
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
