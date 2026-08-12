// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    UniswapV4WeightedSwapHookHooksTarget
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookHooksTarget.sol";

/**
 * @title UniswapV4WeightedSwapHookHooksFacet
 * @notice IHooks callbacks + product views + swap previews (size-split facet).
 * @dev Does not cut IERC20 / IBasicVault.reserves (shared facets).
 */
contract UniswapV4WeightedSwapHookHooksFacet is UniswapV4WeightedSwapHookHooksTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4WeightedSwapHookHooksFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IUniswapV4WeightedSwapHook).interfaceId;
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
        funcs[10] = IUniswapV4WeightedSwapHook.poolManager.selector;
        funcs[11] = IUniswapV4WeightedSwapHook.feeOracle.selector;
        funcs[12] = IUniswapV4WeightedSwapHook.numTokens.selector;
        funcs[13] = IUniswapV4WeightedSwapHook.tokens.selector;
        funcs[14] = IUniswapV4WeightedSwapHook.token.selector;
        funcs[15] = IUniswapV4WeightedSwapHook.getNormalizedWeights.selector;
        funcs[16] = IUniswapV4WeightedSwapHook.rateProvider.selector;
        funcs[17] = IUniswapV4WeightedSwapHook.effectiveRate.selector;
        funcs[18] = IUniswapV4WeightedSwapHook.reserveOf.selector;
        funcs[19] = IUniswapV4WeightedSwapHook.dexSwapFee.selector;
    }

    function _b() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](10);
        funcs[0] = IUniswapV4WeightedSwapHook.usageFee.selector;
        funcs[1] = IUniswapV4WeightedSwapHook.feeTo.selector;
        funcs[2] = IUniswapV4WeightedSwapHook.kLast.selector;
        funcs[3] = IUniswapV4WeightedSwapHook.kLastMode.selector;
        funcs[4] = IUniswapV4WeightedSwapHook.isFullBook.selector;
        funcs[5] = IUniswapV4WeightedSwapHook.previewSwapExactIn.selector;
        funcs[6] = IUniswapV4WeightedSwapHook.previewSwapExactOut.selector;
        funcs[7] = this.permit2.selector;
        funcs[8] = IUniswapV4WeightedSwapHook.pairPoolTickSpacing.selector;
        funcs[9] = IUniswapV4WeightedSwapHook.pairPoolSqrtPriceX96.selector;
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
