// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_Univ4Se
 * @notice H-QD-GV4: Quad SE buffer hook + three vanilla Uni V4 Standard Exchange vaults (same pm, TWAP).
 * @dev Burn/close revert TransferFromFailed (0x7939f424) if Quad unwrap lacks forceApprove.
 *      Dual is not bound. ERC-4626 is not this SE. PonsV2MemeHook is not the reserve hook.
 */
abstract contract TestBase_UniswapV4Detf_Quad_Univ4Se is TestBase_UniswapV4Detf_Quad_ProdSe {
    function _deployProductionSes() internal override {
        pair1 = new SimpleMintableERC20("Pair1", "P1");
        pair2 = new SimpleMintableERC20("Pair2", "P2");
        hookPair0 = address(pair0);
        hookPair1 = address(pair1);
        hookPair2 = address(pair2);
        hookSe0 = _deployVanillaUniv4Se(hookPair0);
        hookSe1 = _deployVanillaUniv4Se(hookPair1);
        hookSe2 = _deployVanillaUniv4Se(hookPair2);
    }
}
