// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_MorphoMix
 * @notice M-QD-MBGV4P1: [0] Morpho Blue SE (loanToken=pair0); [1] G-V4 Uni V4 SE; [2] pons v1 → Uni V3 SE.
 * @dev Morpho only on pair [0]. Dummy collateral not in hook.tokens(). No borrow. Dual is not bound.
 */
abstract contract TestBase_UniswapV4Detf_Quad_MorphoMix is TestBase_UniswapV4Detf_Quad_ProdSe {
    function _deployProductionSes() internal override {
        pair1 = _mintableAbove(address(pair0), "Pair1", "P1");
        _ensureWeth();
        _ensureUniv3SePkg();
        ponsV1 = SeLib.deployPonsV1Stack(univ3Factory, weth);
        address p1Launch = _launchPonsV1MinAddr("M-QD-MBGV4P1-v1", address(pair1));
        require(address(pair0) < address(pair1) && address(pair1) < p1Launch, "tokens() pair order");

        hookPair0 = address(pair0);
        hookPair1 = address(pair1);
        hookPair2 = p1Launch;

        morphoStack = SeLib.deployMorphoStack(_craneCtx());
        (hookSe0,) = SeLib.createMarketAndDeployVault(morphoStack, hookPair0, owner);
        hookSe1 = _deployVanillaUniv4Se(hookPair1);
        hookSe2 = _deployPonsV1Univ3Se(hookPair2);
    }

    function _fundAndApprove() internal override {
        require(mintToken == hookPair0, "mintToken is Morpho loanToken");
        _fundMintablePair(hookPair0, hookSe0);
        _fundMintablePair(hookPair1, hookSe1);
        SeLib.warpPastPonsV1Restrictions(hookPair2);
        _buyPonsV1(hookPair2, detfUser, 5 ether);
        _approvePair(hookPair2, hookSe2);
    }
}
