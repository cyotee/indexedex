// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_PonsV2Se
 * @notice H-QD-P2: Quad hook pairs = three pons v2 launch tokens; Uni V4 SE wraps each graduated pool.
 * @dev Same PoolManager as hook + Uni V4 SE. Reserve hook is the Quad buffer, never PonsV2MemeHook.
 *      Dual is not bound. ERC-4626 is not this SE.
 */
abstract contract TestBase_UniswapV4Detf_Quad_PonsV2Se is TestBase_UniswapV4Detf_Quad_ProdSe {
    function _deployProductionSes() internal override {
        _ensureWeth();
        ponsV2 = SeLib.deployPonsV2Stack(pm, permit2, weth);
        hookPair0 = ponsV2.launchToken;
        PoolKey memory key0 = ponsV2.graduatedPoolKey;
        PoolKey memory key1;
        PoolKey memory key2;
        (hookPair1,, key1) =
            SeLib.launchGraduatePonsV2(ponsV2, weth, keccak256("H-QD-P2-1"), "PSE1", detfUser);
        (hookPair2,, key2) =
            SeLib.launchGraduatePonsV2(ponsV2, weth, keccak256("H-QD-P2-2"), "PSE2", detfUser);
        hookSe0 = _deployPonsV2Univ4Se(key0);
        hookSe1 = _deployPonsV2Univ4Se(key1);
        hookSe2 = _deployPonsV2Univ4Se(key2);
    }

    function _fundAndApprove() internal override {
        uint256 leftover = IERC20(hookPair0).balanceOf(address(this));
        if (leftover > 0) IERC20(hookPair0).transfer(detfUser, leftover);
        require(IERC20(hookPair0).balanceOf(detfUser) >= 110 ether, "need pons v2 0");
        require(IERC20(hookPair1).balanceOf(detfUser) >= 110 ether, "need pons v2 1");
        require(IERC20(hookPair2).balanceOf(detfUser) >= 110 ether, "need pons v2 2");
        _approvePair(hookPair0, hookSe0);
        _approvePair(hookPair1, hookSe1);
        _approvePair(hookPair2, hookSe2);
    }
}
