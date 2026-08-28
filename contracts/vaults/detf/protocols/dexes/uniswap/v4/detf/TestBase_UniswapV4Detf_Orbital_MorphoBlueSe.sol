// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Orbital_MorphoBlueSe
 * @notice H-OR-MB: two Morpho Blue SEs, one Morpho singleton. loanToken = that pair.
 * @dev createMarket before deployVault. Dummy collateral not in tokens(). No borrow.
 */
abstract contract TestBase_UniswapV4Detf_Orbital_MorphoBlueSe is TestBase_UniswapV4Detf_Orbital_ProdSe {
    SeLib.MorphoStack internal morphoStack;
    MarketParams internal morphoMarket0;
    MarketParams internal morphoMarket1;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        SimpleMintableERC20 p0 = new SimpleMintableERC20("Pair0", "P0");
        SimpleMintableERC20 p1 = new SimpleMintableERC20("Pair1", "P1");
        if (address(p1) < address(p0)) (p0, p1) = (p1, p0);
        pairToken = p0;
        pm = IPoolManager(address(new PoolManager(address(this))));

        morphoStack = SeLib.deployMorphoStack(_craneCtx());
        address vault0;
        address vault1;
        (vault0, morphoMarket0) = SeLib.createMarketAndDeployVault(morphoStack, address(p0), owner);
        (vault1, morphoMarket1) = SeLib.createMarketAndDeployVault(morphoStack, address(p1), owner);

        _finishOrbitalDetf(address(p0), address(p1), vault0, vault1);
        _requireDummyCollateralNotInTokens();

        p0.mint(detfUser, 10_000_000 ether);
        p1.mint(detfUser, 10_000_000 ether);
        _approveUserPairs(detfUser);
    }

    function _requireDummyCollateralNotInTokens() internal view {
        address dummy = morphoStack.dummyCollateral;
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            require(toks[i] != dummy, "dummy collateral in tokens()");
        }
        require(dummy != detf, "dummy is DETF");
    }
}
