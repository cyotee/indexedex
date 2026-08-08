// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4BalancerQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/interfaces/IUniswapV4BalancerQuadStableSwapHook.sol";
import {
    UniswapV4BalancerQuadStableSwapHookTarget
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookTarget.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHookHooksFacet
 * @notice IHooks callbacks + product binding views + swap previews (size-split facet).
 */
contract UniswapV4BalancerQuadStableSwapHookHooksFacet is UniswapV4BalancerQuadStableSwapHookTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4BalancerQuadStableSwapHookHooksFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IUniswapV4BalancerQuadStableSwapHook).interfaceId;
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
        funcs[10] = IUniswapV4BalancerQuadStableSwapHook.poolManager.selector;
        funcs[11] = IUniswapV4BalancerQuadStableSwapHook.token0.selector;
        funcs[12] = IUniswapV4BalancerQuadStableSwapHook.token1.selector;
        funcs[13] = IUniswapV4BalancerQuadStableSwapHook.token2.selector;
        funcs[14] = IUniswapV4BalancerQuadStableSwapHook.token3.selector;
        funcs[15] = IUniswapV4BalancerQuadStableSwapHook.tokens.selector;
        funcs[16] = IUniswapV4BalancerQuadStableSwapHook.lpFeePips.selector;
        funcs[17] = IUniswapV4BalancerQuadStableSwapHook.baseAmp.selector;
        funcs[18] = IUniswapV4BalancerQuadStableSwapHook.getCurrentAmp.selector;
        funcs[19] = IUniswapV4BalancerQuadStableSwapHook.rateProvider.selector;
    }

    function _b() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](9);
        funcs[0] = IUniswapV4BalancerQuadStableSwapHook.rateProviders.selector;
        funcs[1] = IUniswapV4BalancerQuadStableSwapHook.reserveOf.selector;
        funcs[2] = IUniswapV4BalancerQuadStableSwapHook.effectiveRate.selector;
        funcs[3] = IUniswapV4BalancerQuadStableSwapHook.previewSwapExactIn.selector;
        funcs[4] = IUniswapV4BalancerQuadStableSwapHook.previewSwapExactOut.selector;
        funcs[5] = this.getHookPermissions.selector;
        funcs[6] = this.zapQuoteExactInExternal.selector;
        funcs[7] = this.tryGetYForZap.selector;
        funcs[8] = this.tryGetDExternal.selector;
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
