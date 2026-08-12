// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleTarget.sol";

/// @notice Flexible SE-share join surface (Option 1d size split from JoinFacet).
contract UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet is
    UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinProportionalFlexible.selector;
        funcs[1] = IUniswapV4StandardExchangeWeightedBufferHook.joinProportionalFlexible.selector;
        funcs[2] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinSingleAssetExactInFlexible.selector;
        funcs[3] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactInFlexible.selector;
        funcs[4] = IUniswapV4StandardExchangeWeightedBufferHook.previewDepositSingleFlexible.selector;
        funcs[5] = IUniswapV4StandardExchangeWeightedBufferHook.depositSingleFlexible.selector;
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
