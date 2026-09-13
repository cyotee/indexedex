// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe_Decimals.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_MorphoBlueSe_Decimals
 * @notice H-QD-MB: Quad hook + three MorphoBlueStandardExchange vaults (one singleton, one market per pair).
 * @dev createMarket before deployVault. Dummy collateral not in hook.tokens(). No borrow.
 *      Unwrap may succeed with allowance 0 (msg.sender==owner); still assert allowance 0.
 *      Dual is not bound. ERC-4626 wrapper is not this SE.
 */
abstract contract TestBase_UniswapV4Detf_Quad_MorphoBlueSe_Decimals is TestBase_UniswapV4Detf_Quad_ProdSe_Decimals {
    function _deployProductionSes() internal override {
        pair1 = new MintableERC20Decimals("Pair1", "P1", _rateDecimals());
        pair2 = new MintableERC20Decimals("Pair2", "P2", _dec2());
        hookPair0 = address(pair0);
        hookPair1 = address(pair1);
        hookPair2 = address(pair2);
        morphoStack = SeLib.deployMorphoStack(_craneCtx());
        (hookSe0,) = SeLib.createMarketAndDeployVault(morphoStack, hookPair0, owner);
        (hookSe1,) = SeLib.createMarketAndDeployVault(morphoStack, hookPair1, owner);
        (hookSe2,) = SeLib.createMarketAndDeployVault(morphoStack, hookPair2, owner);
    }
}
