// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet
 * @notice M3: IStandardExchangeIn / Out for pair0↔pair1 book swaps on the dual diamond.
 */
contract UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet is
    UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](4);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs[2] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[3] = IStandardExchangeOut.exchangeOut.selector;
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
