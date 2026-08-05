// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHookTarget
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookTarget.sol";

/**
 * @title UniswapV4OrbitalSwapHookHooksFacet
 * @notice IHooks callbacks + product views + swap previews (size-split facet).
 */
contract UniswapV4OrbitalSwapHookHooksFacet is UniswapV4OrbitalSwapHookTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4OrbitalSwapHookHooksFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IUniswapV4OrbitalSwapHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        bytes4[] memory a = _a();
        bytes4[] memory b = _b();
        funcs = new bytes4[](a.length + b.length);
        for (uint256 i; i < a.length; ++i) {
            funcs[i] = a[i];
        }
        for (uint256 j; j < b.length; ++j) {
            funcs[a.length + j] = b[j];
        }
    }

    function _a() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](20);
        funcs[0] = IHooks.beforeInitialize.selector;
        funcs[1] = IHooks.afterInitialize.selector;
        funcs[2] = IHooks.beforeAddLiquidity.selector;
        funcs[3] = IHooks.afterAddLiquidity.selector;
        funcs[4] = IHooks.beforeRemoveLiquidity.selector;
        funcs[5] = IHooks.afterRemoveLiquidity.selector;
        funcs[6] = IHooks.beforeSwap.selector;
        funcs[7] = IHooks.afterSwap.selector;
        funcs[8] = IHooks.beforeDonate.selector;
        funcs[9] = IHooks.afterDonate.selector;
        funcs[10] = IUniswapV4OrbitalSwapHook.poolManager.selector;
        funcs[11] = IUniswapV4OrbitalSwapHook.feeOracle.selector;
        funcs[12] = IUniswapV4OrbitalSwapHook.token0.selector;
        funcs[13] = IUniswapV4OrbitalSwapHook.token1.selector;
        funcs[14] = IUniswapV4OrbitalSwapHook.token2.selector;
        funcs[15] = IUniswapV4OrbitalSwapHook.radius.selector;
        funcs[16] = IUniswapV4OrbitalSwapHook.dexSwapFee.selector;
        funcs[17] = IUniswapV4OrbitalSwapHook.usageFee.selector;
        funcs[18] = IUniswapV4OrbitalSwapHook.feeTo.selector;
        funcs[19] = IUniswapV4OrbitalSwapHook.kLast.selector;
    }

    function _b() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](8);
        funcs[0] = IUniswapV4OrbitalSwapHook.kLastMode.selector;
        funcs[1] = IUniswapV4OrbitalSwapHook.lSquared.selector;
        funcs[2] = IUniswapV4OrbitalSwapHook.reserveOf.selector;
        funcs[3] = IUniswapV4OrbitalSwapHook.previewSwapExactIn.selector;
        funcs[4] = IUniswapV4OrbitalSwapHook.previewSwapExactOut.selector;
        funcs[5] = this.permit2.selector;
        funcs[6] = IUniswapV4OrbitalSwapHook.pairPoolTickSpacing.selector;
        funcs[7] = IUniswapV4OrbitalSwapHook.pairPoolSqrtPriceX96.selector;
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
