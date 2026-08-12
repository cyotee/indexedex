// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookSeTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookSeTarget.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHookSeFacet is
    UniswapV4StandardExchangeBalancerQuadStableBufferHookSeTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeBalancerQuadStableBufferHookSeFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](3);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IStandardExchangeOut).interfaceId;
        interfaces[2] = type(IStandardExchangeMultiAssetLiquidity).interfaceId;
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
