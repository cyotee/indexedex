// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Weighted_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Weighted_MorphoMix
 * @notice M-WE-MBGV4: [0] Morpho Blue SE (mintToken=pair0); [1] G-V4 Uni V4 SE.
 *         Morpho only on pair [0]. Dual is not bound. No borrow.
 */
abstract contract TestBase_UniswapV4Detf_Weighted_MorphoMix is TestBase_UniswapV4Detf_Weighted_ProdSe {
    SeLib.MorphoStack internal morphoStack;
    MarketParams internal morphoMarket;
    IWETH internal weth;
    PoolKey internal sePoolKey1;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new SimpleMintableERC20("Etch", "ETCH");
        pairA = address(new SimpleMintableERC20("Pair0", "P0"));
        pairB = address(new SimpleMintableERC20("Pair1", "P1"));
        while (pairB <= pairA) {
            pairB = address(new SimpleMintableERC20("Pair1", "P1"));
        }
        SimpleMintableERC20 rate1 = new SimpleMintableERC20("Rate", "RATE");
        pm = IPoolManager(address(new PoolManager(address(this))));
        weth = SeLib.newWeth();

        morphoStack = SeLib.deployMorphoStack(_craneCtx());
        (se0, morphoMarket) = SeLib.createMarketAndDeployVault(morphoStack, pairA, owner);
        require(morphoMarket.loanToken == pairA, "loan = pair0");
        require(morphoMarket.collateralToken == morphoStack.dummyCollateral, "dummy coll");

        SeLib.Univ4SePkg memory v4pkg = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        sePoolKey1 = SeLib.initAndSeedUniv4Pool(pm, pairB, address(rate1));
        se1 = SeLib.deployUniv4Vault(v4pkg.pkg, sePoolKey1);

        _finishWeightedProdSe();
        require(mintToken == pairA, "mintToken is Morpho pair0");
        require(morphoStack.dummyCollateral != pairA, "coll not pair");
        require(morphoStack.dummyCollateral != pairB, "coll not pair");
        require(morphoStack.dummyCollateral != detf, "coll not detf");

        _mintMintablePairs(10_000_000 ether);
        _approveUserForPairs();
    }
}
