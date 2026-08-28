// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {TestBase_UniswapV4Detf_Quad_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_MorphoBlueSe
 * @notice H-QD-MB: Quad hook + three MorphoBlueStandardExchange vaults (one singleton, one market per pair).
 * @dev createMarket before deployVault. Dummy collateral not in hook.tokens(). No borrow.
 *      Unwrap may succeed with allowance 0 (msg.sender==owner); still assert allowance 0.
 *      Dual is not bound. ERC-4626 wrapper is not this SE.
 */
abstract contract TestBase_UniswapV4Detf_Quad_MorphoBlueSe is TestBase_UniswapV4Detf_Quad_ProdSe {
    function _deployProductionSes() internal override {
        pair1 = new SimpleMintableERC20("Pair1", "P1");
        pair2 = new SimpleMintableERC20("Pair2", "P2");
        hookPair0 = address(pair0);
        hookPair1 = address(pair1);
        hookPair2 = address(pair2);
        morphoStack = SeLib.deployMorphoStack(_craneCtx());
        (hookSe0,) = SeLib.createMarketAndDeployVault(morphoStack, hookPair0, owner);
        (hookSe1,) = SeLib.createMarketAndDeployVault(morphoStack, hookPair1, owner);
        (hookSe2,) = SeLib.createMarketAndDeployVault(morphoStack, hookPair2, owner);
    }
}
