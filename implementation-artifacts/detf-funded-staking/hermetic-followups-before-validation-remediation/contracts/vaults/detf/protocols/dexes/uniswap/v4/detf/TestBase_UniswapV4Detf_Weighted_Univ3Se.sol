// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Weighted_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Weighted_Univ3Se
 * @notice H-WE-GV3: Weighted n=3, two vanilla Uni V3 SE. Dual is not bound.
 */
abstract contract TestBase_UniswapV4Detf_Weighted_Univ3Se is TestBase_UniswapV4Detf_Weighted_ProdSe {
    IUniswapV3Factory internal univ3Factory;
    IUniswapV3Pool internal univ3Pool0;
    IUniswapV3Pool internal univ3Pool1;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new SimpleMintableERC20("Etch", "ETCH");
        pairA = address(new SimpleMintableERC20("Pair0", "P0"));
        pairB = address(new SimpleMintableERC20("Pair1", "P1"));
        SimpleMintableERC20 rate0 = new SimpleMintableERC20("Rate", "RATE");
        SimpleMintableERC20 rate1 = new SimpleMintableERC20("Rate", "RATE");
        pm = IPoolManager(address(new PoolManager(address(this))));

        univ3Factory = SeLib.newUniv3Factory();
        SeLib.Univ3SePkg memory v3pkg;
        v3pkg.factory = univ3Factory;
        v3pkg.pkg = SeLib.deployUniv3SePkg(_craneCtx(), univ3Factory);
        univ3Pool0 = SeLib.createUniv3PoolOneToOne(
            univ3Factory, pairA, address(rate0), SeLib.GENERIC_V3_FEE
        );
        univ3Pool1 = SeLib.createUniv3PoolOneToOne(
            univ3Factory, pairB, address(rate1), SeLib.GENERIC_V3_FEE
        );
        SeLib.seedUniv3Pool(univ3Pool0);
        SeLib.seedUniv3Pool(univ3Pool1);
        se0 = SeLib.deployUniv3Vault(v3pkg.pkg, univ3Pool0);
        se1 = SeLib.deployUniv3Vault(v3pkg.pkg, univ3Pool1);

        _finishWeightedProdSe();
        _mintMintablePairs(10_000_000 ether);
        _approveUserForPairs();
    }
}
