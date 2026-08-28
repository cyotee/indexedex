// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_PonsV1Se
 * @notice H-QD-P1: Quad hook pairs = three pons v1 launch tokens (not WETH); Uni V3 SE wraps each v1 pool.
 * @dev One UniswapV3Factory for v1 launches and Uni V3 SE PkgInit. Does not diamond-inherit TestBase_PonsFamily.
 *      Dual is not bound. ERC-4626 is not this SE.
 */
abstract contract TestBase_UniswapV4Detf_Quad_PonsV1Se is TestBase_UniswapV4Detf_Quad_ProdSe {
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
}
