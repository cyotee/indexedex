// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    UniswapV4WeightedSwapHookTarget
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookTarget.sol";

/**
 * @title UniswapV4WeightedSwapHookLiquidityFacet
 * @notice Join/exit + previews (native V4 modifyLiquidity banned on hooks facet).
 */
contract UniswapV4WeightedSwapHookLiquidityFacet is UniswapV4WeightedSwapHookTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4WeightedSwapHookLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4WeightedSwapHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](14);
        funcs[0] = IUniswapV4WeightedSwapHook.previewJoinProportional.selector;
        funcs[1] = IUniswapV4WeightedSwapHook.previewJoinSingleAssetExactIn.selector;
        funcs[2] = IUniswapV4WeightedSwapHook.previewJoinSingleAssetExactOut.selector;
        funcs[3] = IUniswapV4WeightedSwapHook.previewJoinUnbalanced.selector;
        funcs[4] = IUniswapV4WeightedSwapHook.previewExitProportional.selector;
        funcs[5] = IUniswapV4WeightedSwapHook.previewExitSingleAssetExactIn.selector;
        funcs[6] = IUniswapV4WeightedSwapHook.previewExitSingleAssetExactOut.selector;
        funcs[7] = IUniswapV4WeightedSwapHook.joinProportional.selector;
        funcs[8] = IUniswapV4WeightedSwapHook.joinSingleAssetExactIn.selector;
        funcs[9] = IUniswapV4WeightedSwapHook.joinSingleAssetExactOut.selector;
        funcs[10] = IUniswapV4WeightedSwapHook.joinUnbalanced.selector;
        funcs[11] = IUniswapV4WeightedSwapHook.exitProportional.selector;
        funcs[12] = IUniswapV4WeightedSwapHook.exitSingleAssetExactIn.selector;
        funcs[13] = IUniswapV4WeightedSwapHook.exitSingleAssetExactOut.selector;
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
