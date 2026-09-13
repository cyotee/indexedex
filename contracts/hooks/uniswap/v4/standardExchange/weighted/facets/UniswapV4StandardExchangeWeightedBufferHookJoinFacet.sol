// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4SeBufferHookClaimQuote} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookJoinTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinTarget.sol";

/// @notice Join / deposit liquidity surface (Option 1d size split from LiquidityFacet).
contract UniswapV4StandardExchangeWeightedBufferHookJoinFacet is
    UniswapV4StandardExchangeWeightedBufferHookJoinTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeWeightedBufferHookJoinFacet).name;
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
