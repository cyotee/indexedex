// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Weighted_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Weighted_MorphoBlueSe
 * @notice H-WE-MB: Weighted n=3, two Morpho Blue SE (one singleton). loanToken = pair.
 *         Dummy collateral not in tokens(). createMarket before deployVault. No borrow.
 *         Dual is not bound. Does not diamond-inherit TestBase_MorphoBlue.
 */
abstract contract TestBase_UniswapV4Detf_Weighted_MorphoBlueSe is TestBase_UniswapV4Detf_Weighted_ProdSe {
    SeLib.MorphoStack internal morphoStack;
    MarketParams internal morphoMarket0;
    MarketParams internal morphoMarket1;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new SimpleMintableERC20("Etch", "ETCH");
        pairA = address(new SimpleMintableERC20("Pair0", "P0"));
        pairB = address(new SimpleMintableERC20("Pair1", "P1"));
        pm = IPoolManager(address(new PoolManager(address(this))));

        morphoStack = SeLib.deployMorphoStack(_craneCtx());
        (se0, morphoMarket0) = SeLib.createMarketAndDeployVault(morphoStack, pairA, owner);
        (se1, morphoMarket1) = SeLib.createMarketAndDeployVault(morphoStack, pairB, owner);
        require(morphoMarket0.collateralToken == morphoStack.dummyCollateral, "dummy coll");
        require(morphoMarket1.collateralToken == morphoStack.dummyCollateral, "dummy coll");
        require(morphoMarket0.loanToken == pairA, "loan0");
        require(morphoMarket1.loanToken == pairB, "loan1");

        _finishWeightedProdSe();
        require(mintToken == pairA || mintToken == pairB, "mintToken is pair");
        require(morphoStack.dummyCollateral != pairA, "coll not pair");
        require(morphoStack.dummyCollateral != pairB, "coll not pair");
        require(morphoStack.dummyCollateral != detf, "coll not detf");

        _mintMintablePairs(10_000_000 ether);
        _approveUserForPairs();
    }
}
