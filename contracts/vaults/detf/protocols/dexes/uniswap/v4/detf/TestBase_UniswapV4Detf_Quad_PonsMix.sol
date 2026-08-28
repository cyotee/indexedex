// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_PonsMix
 * @notice M-QD-P1P2G4: [0] pons v1 → Uni V3 SE; [1] pons v2 → Uni V4 SE; [2] generic V4 → Uni V4 SE.
 * @dev mintToken is the pons v1 launch token (lowest pair address). Dual is not bound.
 */
abstract contract TestBase_UniswapV4Detf_Quad_PonsMix is TestBase_UniswapV4Detf_Quad_ProdSe {
    function _deployProductionSes() internal override {
        _ensureWeth();
        _ensureUniv3SePkg();
        ponsV1 = SeLib.deployPonsV1Stack(univ3Factory, weth);
        address v1 = _launchPonsV1Salted("M-QD-P1P2G4-v1");

        ponsV2 = SeLib.deployPonsV2Stack(pm, permit2, weth);
        address v2 = ponsV2.launchToken;
        PoolKey memory key2 = ponsV2.graduatedPoolKey;
        if (!(v1 < v2)) {
            (v2,, key2) = _launchPonsV2Above(v1);
        }

        pair2 = _mintableAbove(v2, "Pair2", "P2");
        require(v1 < v2 && v2 < address(pair2), "tokens() pair order");

        hookPair0 = v1;
        hookPair1 = v2;
        hookPair2 = address(pair2);
        hookSe0 = _deployPonsV1Univ3Se(v1);
        hookSe1 = _deployPonsV2Univ4Se(key2);
        hookSe2 = _deployVanillaUniv4Se(hookPair2);
    }

    function _launchPonsV2Above(address floor)
        internal
        returns (address token, address curve, PoolKey memory key)
    {
        for (uint256 i; i < 32; ++i) {
            bytes32 salt = keccak256(abi.encodePacked("M-QD-P1P2G4-v2", i));
            (token, curve, key) = SeLib.launchGraduatePonsV2(
                ponsV2, weth, salt, string(abi.encodePacked("PV2", vm.toString(i))), detfUser
            );
            if (token > floor) return (token, curve, key);
        }
        revert("pons v2 above v1 not found");
    }

    function _fundAndApprove() internal override {
        require(mintToken == hookPair0, "mintToken is pons v1");
        SeLib.warpPastPonsV1Restrictions(hookPair0);
        _buyPonsV1(hookPair0, detfUser, 5 ether);
        uint256 v2This = IERC20(hookPair1).balanceOf(address(this));
        if (v2This > 0) IERC20(hookPair1).transfer(detfUser, v2This);
        require(IERC20(hookPair1).balanceOf(detfUser) >= 110 ether, "need pons v2");
        _fundMintablePair(hookPair2, hookSe2);
        _approvePair(hookPair0, hookSe0);
        _approvePair(hookPair1, hookSe1);
    }
}
