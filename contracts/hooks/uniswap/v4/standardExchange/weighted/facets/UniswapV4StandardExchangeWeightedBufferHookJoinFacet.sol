// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
        funcs = new bytes4[](18);
        funcs[0] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinProportional.selector;
        funcs[1] = IUniswapV4StandardExchangeWeightedBufferHook.joinProportional.selector;
        funcs[2] = bytes4(keccak256("previewJoinUnbalanced(uint256[])"));
        funcs[3] = bytes4(keccak256("joinUnbalanced(uint256[],address,uint256,uint256)"));
        funcs[4] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[5] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactIn.selector;
        funcs[6] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[7] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactOut.selector;
        funcs[8] = IUniswapV4StandardExchangeWeightedBufferHook.previewDepositSingle.selector;
        funcs[9] = IUniswapV4StandardExchangeWeightedBufferHook.depositSingle.selector;
        funcs[10] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinProportionalFlexible.selector;
        funcs[11] = IUniswapV4StandardExchangeWeightedBufferHook.joinProportionalFlexible.selector;
        funcs[12] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinSingleAssetExactInFlexible.selector;
        funcs[13] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactInFlexible.selector;
        funcs[14] = IUniswapV4StandardExchangeWeightedBufferHook.previewDepositSingleFlexible.selector;
        funcs[15] = IUniswapV4StandardExchangeWeightedBufferHook.depositSingleFlexible.selector;
        funcs[16] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        funcs[17] = IUniswapV4SeBufferHook.joinUnbalanced.selector;
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
