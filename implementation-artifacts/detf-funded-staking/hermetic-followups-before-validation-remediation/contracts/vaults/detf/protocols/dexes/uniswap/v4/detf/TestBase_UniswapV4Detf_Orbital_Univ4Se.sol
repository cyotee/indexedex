// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Orbital_Univ4Se
 * @notice H-OR-GV4: Orbital n=3 + two vanilla Uni V4 SEs (same PoolManager, TWAP required).
 * @dev Dual is not bound. PonsV2MemeHook is not the reserve hook. Two pairs do not share one SE.
 */
abstract contract TestBase_UniswapV4Detf_Orbital_Univ4Se is TestBase_UniswapV4Detf_Orbital_ProdSe {
    SimpleMintableERC20 internal seOther0;
    SimpleMintableERC20 internal seOther1;
    IWETH internal weth;
    PoolKey internal sePoolKey0;
    PoolKey internal sePoolKey1;

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
        weth = SeLib.newWeth();

        SeLib.Univ4SePkg memory v4pkg = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        sePoolKey0 = SeLib.initAndSeedUniv4Pool(pm, address(p0), address(seOther0));
        sePoolKey1 = SeLib.initAndSeedUniv4Pool(pm, address(p1), address(seOther1));
        address vault0 = SeLib.deployUniv4Vault(v4pkg.pkg, sePoolKey0);
        address vault1 = SeLib.deployUniv4Vault(v4pkg.pkg, sePoolKey1);

        _finishOrbitalDetf(address(p0), address(p1), vault0, vault1);

        p0.mint(detfUser, 10_000_000 ether);
        p1.mint(detfUser, 10_000_000 ether);
        _approveUserPairs(detfUser);
    }
}
