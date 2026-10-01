// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookJoinTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinTarget.sol";

/// @dev D19: mutating join/deposit selectors only. Previews live on LiquidityFacetExt.
contract UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet is
    UniswapV4StandardExchangeWeightedBufferHookJoinTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](5);
        funcs[0] = IUniswapV4StandardExchangeWeightedBufferHook.joinProportional.selector;
        funcs[1] = bytes4(keccak256("joinUnbalanced(uint256[],address,uint256,uint256)"));
        funcs[2] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactIn.selector;
        funcs[3] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactOut.selector;
        funcs[4] = IUniswapV4StandardExchangeWeightedBufferHook.depositSingle.selector;
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
