// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Orbital_Univ3Se
 * @notice H-OR-GV3: Orbital n=3 + two vanilla Uni V3 Standard Exchanges.
 * @dev Dual is not bound. ERC-4626 is not these SEs. Two pairs do not share one SE.
 */
abstract contract TestBase_UniswapV4Detf_Orbital_Univ3Se is TestBase_UniswapV4Detf_Orbital_ProdSe {
    SimpleMintableERC20 internal seOther0;
    SimpleMintableERC20 internal seOther1;
    IUniswapV3Factory internal univ3Factory;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        SimpleMintableERC20 p0 = new SimpleMintableERC20("Pair0", "P0");
        SimpleMintableERC20 p1 = new SimpleMintableERC20("Pair1", "P1");
        if (address(p1) < address(p0)) (p0, p1) = (p1, p0);
        pairToken = p0;
        seOther0 = new SimpleMintableERC20("Rate0", "RATE0");
        seOther1 = new SimpleMintableERC20("Rate1", "RATE1");
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

        p0.mint(detfUser, 10_000_000 ether);
        p1.mint(detfUser, 10_000_000 ether);
        _approveUserPairs(detfUser);
    }
}
