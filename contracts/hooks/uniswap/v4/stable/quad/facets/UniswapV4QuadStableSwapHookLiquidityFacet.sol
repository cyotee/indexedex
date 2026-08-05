// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4QuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/interfaces/IUniswapV4QuadStableSwapHook.sol";
import {
    UniswapV4QuadStableSwapHookTarget
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookTarget.sol";

/**
 * @title UniswapV4QuadStableSwapHookLiquidityFacet
 * @notice Custom add/remove/zap liquidity + previews (native V4 modifyLiquidity banned on hooks facet).
 */
contract UniswapV4QuadStableSwapHookLiquidityFacet is UniswapV4QuadStableSwapHookTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4QuadStableSwapHookLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4QuadStableSwapHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IUniswapV4QuadStableSwapHook.addLiquidity.selector;
        funcs[1] = IUniswapV4QuadStableSwapHook.removeLiquidity.selector;
        funcs[2] = IUniswapV4QuadStableSwapHook.zapIn.selector;
        funcs[3] = IUniswapV4QuadStableSwapHook.previewAddLiquidity.selector;
        funcs[4] = IUniswapV4QuadStableSwapHook.previewRemoveLiquidity.selector;
        funcs[5] = IUniswapV4QuadStableSwapHook.previewZapIn.selector;
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
