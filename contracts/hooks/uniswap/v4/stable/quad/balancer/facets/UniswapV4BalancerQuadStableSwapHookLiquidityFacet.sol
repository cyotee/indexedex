// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {
    IUniswapV4BalancerQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/interfaces/IUniswapV4BalancerQuadStableSwapHook.sol";
import {
    UniswapV4BalancerQuadStableSwapHookTarget
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookTarget.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHookLiquidityFacet
 * @notice Custom add/remove/zap liquidity + multi-asset join/exit surface (native V4 modifyLiquidity banned).
 */
contract UniswapV4BalancerQuadStableSwapHookLiquidityFacet is UniswapV4BalancerQuadStableSwapHookTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4BalancerQuadStableSwapHookLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IUniswapV4BalancerQuadStableSwapHook).interfaceId;
        interfaces[1] = type(IStandardExchangeMultiAssetLiquidity).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        bytes4[] memory a = _productLp();
        bytes4[] memory b = _multiAssetA();
        bytes4[] memory c = _multiAssetB();
        funcs = new bytes4[](a.length + b.length + c.length);
        uint256 k;
        for (uint256 i; i < a.length; ++i) {
            funcs[k++] = a[i];
        }
        for (uint256 i; i < b.length; ++i) {
            funcs[k++] = b[i];
        }
        for (uint256 i; i < c.length; ++i) {
            funcs[k++] = c[i];
        }
    }

    function _productLp() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IUniswapV4BalancerQuadStableSwapHook.addLiquidity.selector;
        funcs[1] = IUniswapV4BalancerQuadStableSwapHook.removeLiquidity.selector;
        funcs[2] = IUniswapV4BalancerQuadStableSwapHook.zapIn.selector;
        funcs[3] = IUniswapV4BalancerQuadStableSwapHook.previewAddLiquidity.selector;
        funcs[4] = IUniswapV4BalancerQuadStableSwapHook.previewRemoveLiquidity.selector;
        funcs[5] = IUniswapV4BalancerQuadStableSwapHook.previewZapIn.selector;
    }

    function _multiAssetA() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](12);
        funcs[0] = IStandardExchangeMultiAssetLiquidity.previewJoinProportional.selector;
        funcs[1] = IStandardExchangeMultiAssetLiquidity.joinProportional.selector;
        funcs[2] = IStandardExchangeMultiAssetLiquidity.previewExitProportional.selector;
        funcs[3] = IStandardExchangeMultiAssetLiquidity.exitProportional.selector;
        funcs[4] = IStandardExchangeMultiAssetLiquidity.previewJoinUnbalanced.selector;
        funcs[5] = IStandardExchangeMultiAssetLiquidity.joinUnbalanced.selector;
        funcs[6] = IStandardExchangeMultiAssetLiquidity.previewJoinSingleAssetExactIn.selector;
        funcs[7] = IStandardExchangeMultiAssetLiquidity.joinSingleAssetExactIn.selector;
        funcs[8] = IStandardExchangeMultiAssetLiquidity.previewJoinSingleAssetExactOut.selector;
        funcs[9] = IStandardExchangeMultiAssetLiquidity.joinSingleAssetExactOut.selector;
        funcs[10] = IStandardExchangeMultiAssetLiquidity.previewExitSingleAssetExactBptIn.selector;
        funcs[11] = IStandardExchangeMultiAssetLiquidity.exitSingleAssetExactBptIn.selector;
    }

    function _multiAssetB() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](8);
        funcs[0] = IStandardExchangeMultiAssetLiquidity.previewExitSingleAssetExactTokenOut.selector;
        funcs[1] = IStandardExchangeMultiAssetLiquidity.exitSingleAssetExactTokenOut.selector;
        funcs[2] = IStandardExchangeMultiAssetLiquidity.depositSingle.selector;
        funcs[3] = IStandardExchangeMultiAssetLiquidity.previewDepositSingle.selector;
        funcs[4] = IStandardExchangeMultiAssetLiquidity.withdrawSingle.selector;
        funcs[5] = IStandardExchangeMultiAssetLiquidity.previewWithdrawSingle.selector;
        funcs[6] = IStandardExchangeMultiAssetLiquidity.withdrawSingleExactOut.selector;
        funcs[7] = IStandardExchangeMultiAssetLiquidity.previewWithdrawSingleExactOut.selector;
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
