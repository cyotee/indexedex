// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Weighted_Univ3Se_Decimals
 * @notice H-WE-GV3: Weighted n=3, two vanilla Uni V3 SE. Dual is not bound.
 */
abstract contract TestBase_UniswapV4Detf_Weighted_Univ3Se_Decimals is TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals {
    IUniswapV3Factory internal univ3Factory;
    IUniswapV3Pool internal univ3Pool0;
    IUniswapV3Pool internal univ3Pool1;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new MintableERC20Decimals("Etch", "ETCH", 18);
        pairA = address(new MintableERC20Decimals("Pair0", "P0", _pairDecimals()));
        pairB = address(new MintableERC20Decimals("Pair1", "P1", _rateDecimals()));
        MintableERC20Decimals rate0 = new MintableERC20Decimals("Rate", "RATE", 18);
        MintableERC20Decimals rate1 = new MintableERC20Decimals("Rate", "RATE", 18);
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
        _mintMintablePairs(10_000_000);
        _approveUserForPairs();
        SeLib.activatePositionVault(se0, pairA, detfUser, address(0));
        SeLib.activatePositionVault(se1, pairB, detfUser, address(0));
    }
}
