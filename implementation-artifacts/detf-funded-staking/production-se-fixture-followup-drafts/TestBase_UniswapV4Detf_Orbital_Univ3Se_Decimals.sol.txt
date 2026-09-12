// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Orbital_Univ3Se_Decimals
 * @notice H-OR-GV3: Orbital n=3 + two vanilla Uni V3 Standard Exchanges.
 * @dev Dual is not bound. ERC-4626 is not these SEs. Two pairs do not share one SE.
 */
abstract contract TestBase_UniswapV4Detf_Orbital_Univ3Se_Decimals is TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals {
    MintableERC20Decimals internal seOther0;
    MintableERC20Decimals internal seOther1;
    IUniswapV3Factory internal univ3Factory;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        MintableERC20Decimals p0 = new MintableERC20Decimals("Pair0", "P0", _pairDecimals());
        MintableERC20Decimals p1 = new MintableERC20Decimals("Pair1", "P1", _rateDecimals());
        if (address(p1) < address(p0)) (p0, p1) = (p1, p0);
        pairToken = p0;
        seOther0 = new MintableERC20Decimals("Rate0", "RATE0", 18);
        seOther1 = new MintableERC20Decimals("Rate1", "RATE1", 18);
        pm = IPoolManager(address(new PoolManager(address(this))));

        univ3Factory = SeLib.newUniv3Factory();
        SeLib.Univ3SePkg memory v3pkg;
        v3pkg.factory = univ3Factory;
        v3pkg.pkg = SeLib.deployUniv3SePkg(_craneCtx(), univ3Factory);
        IUniswapV3Pool pool0 =
            SeLib.createUniv3PoolOneToOne(univ3Factory, address(p0), address(seOther0), SeLib.GENERIC_V3_FEE);
        IUniswapV3Pool pool1 =
            SeLib.createUniv3PoolOneToOne(univ3Factory, address(p1), address(seOther1), SeLib.GENERIC_V3_FEE);
        SeLib.seedUniv3Pool(pool0);
        SeLib.seedUniv3Pool(pool1);
        address vault0 = SeLib.deployUniv3Vault(v3pkg.pkg, pool0);
        address vault1 = SeLib.deployUniv3Vault(v3pkg.pkg, pool1);

        _finishOrbitalDetf(address(p0), address(p1), vault0, vault1);

        p0.mint(detfUser, 10_000_000 * (10 ** uint256(p0.decimals())));
        p1.mint(detfUser, 10_000_000 * (10 ** uint256(p1.decimals())));
        _approveUserPairs(detfUser);
        SeLib.activatePositionVault(se0, pairAddr0, detfUser, address(0));
        SeLib.activatePositionVault(se1, pairAddr1, detfUser, address(0));
    }
}
