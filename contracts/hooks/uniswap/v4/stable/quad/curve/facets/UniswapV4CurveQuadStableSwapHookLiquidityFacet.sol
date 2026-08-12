// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4CurveQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/curve/interfaces/IUniswapV4CurveQuadStableSwapHook.sol";
import {
    UniswapV4CurveQuadStableSwapHookTarget
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookTarget.sol";

/**
 * @title UniswapV4CurveQuadStableSwapHookLiquidityFacet
 * @notice Custom add/remove/zap liquidity + previews (native V4 modifyLiquidity banned on hooks facet).
 */
contract UniswapV4CurveQuadStableSwapHookLiquidityFacet is UniswapV4CurveQuadStableSwapHookTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4CurveQuadStableSwapHookLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4CurveQuadStableSwapHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IUniswapV4CurveQuadStableSwapHook.addLiquidity.selector;
        funcs[1] = IUniswapV4CurveQuadStableSwapHook.removeLiquidity.selector;
        funcs[2] = IUniswapV4CurveQuadStableSwapHook.zapIn.selector;
        funcs[3] = IUniswapV4CurveQuadStableSwapHook.previewAddLiquidity.selector;
        funcs[4] = IUniswapV4CurveQuadStableSwapHook.previewRemoveLiquidity.selector;
        funcs[5] = IUniswapV4CurveQuadStableSwapHook.previewZapIn.selector;
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
