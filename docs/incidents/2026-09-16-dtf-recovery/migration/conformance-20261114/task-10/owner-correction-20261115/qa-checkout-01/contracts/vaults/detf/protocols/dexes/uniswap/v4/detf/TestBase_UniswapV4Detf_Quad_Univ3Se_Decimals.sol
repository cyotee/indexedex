// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe_Decimals.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_Univ3Se_Decimals
 * @notice H-QD-GV3: Quad SE buffer hook + three vanilla Uni V3 Standard Exchange vaults.
 * @dev Burn/close revert TransferFromFailed (0x7939f424) if Quad unwrap lacks forceApprove.
 *      Dual is not bound. ERC-4626 is not this SE.
 */
abstract contract TestBase_UniswapV4Detf_Quad_Univ3Se_Decimals is TestBase_UniswapV4Detf_Quad_ProdSe_Decimals {
    function _deployProductionSes() internal override {
        pair1 = new MintableERC20Decimals("Pair1", "P1", _rateDecimals());
        pair2 = new MintableERC20Decimals("Pair2", "P2", _dec2());
        hookPair0 = address(pair0);
        hookPair1 = address(pair1);
        hookPair2 = address(pair2);
        hookSe0 = _deployVanillaUniv3Se(hookPair0);
        hookSe1 = _deployVanillaUniv3Se(hookPair1);
        hookSe2 = _deployVanillaUniv3Se(hookPair2);
    }
}
