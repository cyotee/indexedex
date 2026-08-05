// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHookTarget
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookTarget.sol";

/**
 * @title UniswapV4OrbitalSwapHookLiquidityFacet
 * @notice Custom add/remove liquidity + previews (native V4 modifyLiquidity banned on hooks facet).
 */
contract UniswapV4OrbitalSwapHookLiquidityFacet is UniswapV4OrbitalSwapHookTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4OrbitalSwapHookLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4OrbitalSwapHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](4);
        funcs[0] = IUniswapV4OrbitalSwapHook.addLiquidity.selector;
        funcs[1] = IUniswapV4OrbitalSwapHook.removeLiquidity.selector;
        funcs[2] = IUniswapV4OrbitalSwapHook.previewAddLiquidity.selector;
        funcs[3] = IUniswapV4OrbitalSwapHook.previewRemoveLiquidity.selector;
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
