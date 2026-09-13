// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISwapRouter} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/ISwapRouter.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe_Decimals.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_PonsV1Se_Decimals
 * @notice H-QD-P1: Quad hook pairs = three pons v1 launch tokens (not WETH); Uni V3 SE wraps each v1 pool.
 * @dev One UniswapV3Factory for v1 launches and Uni V3 SE PkgInit. Does not diamond-inherit TestBase_PonsFamily.
 *      Dual is not bound. ERC-4626 is not this SE.
 */
abstract contract TestBase_UniswapV4Detf_Quad_PonsV1Se_Decimals is TestBase_UniswapV4Detf_Quad_ProdSe_Decimals {
    function _deployProductionSes() internal override {
        _ensureWeth();
        _ensureUniv3SePkg();
        ponsV1 = SeLib.deployPonsV1Stack(univ3Factory, weth);
        hookPair0 = _launchPonsV1Salted("H-QD-P1-0");
        hookPair1 = _launchPonsV1Salted("H-QD-P1-1");
        hookPair2 = _launchPonsV1Salted("H-QD-P1-2");
        hookSe0 = _deployPonsV1Univ3Se(hookPair0);
        hookSe1 = _deployPonsV1Univ3Se(hookPair1);
        hookSe2 = _deployPonsV1Univ3Se(hookPair2);
    }

    function _fundAndApprove() internal override {
        SeLib.warpPastPonsV1Restrictions(hookPair0);
        SeLib.warpPastPonsV1Restrictions(hookPair1);
        SeLib.warpPastPonsV1Restrictions(hookPair2);
        _buyPonsV1(hookPair0, detfUser, 5 ether);
        _buyPonsV1(hookPair1, detfUser, 5 ether);
        _buyPonsV1(hookPair2, detfUser, 5 ether);
        _approvePair(hookPair0, hookSe0);
        _approvePair(hookPair1, hookSe1);
        _approvePair(hookPair2, hookSe2);
        require(mintToken == hookPair0 || mintToken == hookPair1 || mintToken == hookPair2, "mintToken is launch");
    }

    function _fundBondLegFallback(address token_, address to_, uint256 amount_) internal virtual override {
        if (token_ != hookPair0 && token_ != hookPair1 && token_ != hookPair2) return;
        SeLib.warpPastPonsV1Restrictions(token_);
        for (uint256 i; i < 16 && IERC20(token_).balanceOf(to_) < amount_; ++i) {
            uint256 ethIn = 5 ether;
            vm.deal(to_, to_.balance + ethIn);
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: address(weth),
                tokenOut: token_,
                fee: SeLib.PONS_V1_POOL_FEE,
                recipient: to_,
                deadline: block.timestamp + 1 hours,
                amountIn: ethIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
            vm.prank(to_);
            try ponsV1.swapRouter.exactInputSingle{value: ethIn}(params) {} catch {
                break;
            }
        }
    }
}
