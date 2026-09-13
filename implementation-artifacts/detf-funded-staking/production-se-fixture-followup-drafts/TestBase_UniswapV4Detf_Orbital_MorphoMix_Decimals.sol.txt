// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Orbital_MorphoMix_Decimals
 * @notice M-OR-MBGV4: [0] Morpho Blue SE (loanToken=pair0=mintToken); [1] G-V4 Uni V4 SE on pair1/Rate.
 * @dev Morpho only on pair [0]. Dummy collateral not in tokens(). No borrow. Same PoolManager as hook.
 */
abstract contract TestBase_UniswapV4Detf_Orbital_MorphoMix_Decimals is TestBase_UniswapV4Detf_Orbital_ProdSe_Decimals {
    SeLib.MorphoStack internal morphoStack;
    MarketParams internal morphoMarket;
    MintableERC20Decimals internal seOther1;
    IWETH internal weth;
    PoolKey internal sePoolKey1;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        MintableERC20Decimals p0 = new MintableERC20Decimals("Pair0", "P0", _pairDecimals());
        MintableERC20Decimals p1 = new MintableERC20Decimals("Pair1", "P1", _rateDecimals());
        if (address(p1) < address(p0)) (p0, p1) = (p1, p0);
        pairToken = p0;
        seOther1 = new MintableERC20Decimals("Rate1", "RATE1", 18);
        pm = IPoolManager(address(new PoolManager(address(this))));
        weth = SeLib.newWeth();

        morphoStack = SeLib.deployMorphoStack(_craneCtx());
        address vault0;
        (vault0, morphoMarket) = SeLib.createMarketAndDeployVault(morphoStack, address(p0), owner);

        SeLib.Univ4SePkg memory v4pkg = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        sePoolKey1 = SeLib.initAndSeedUniv4Pool(pm, address(p1), address(seOther1));
        address vault1 = SeLib.deployUniv4Vault(v4pkg.pkg, sePoolKey1);

        _finishOrbitalDetf(address(p0), address(p1), vault0, vault1);
        require(mintToken == address(p0), "mintToken is Morpho loanToken");
        address dummy = morphoStack.dummyCollateral;
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            require(toks[i] != dummy, "dummy collateral in tokens()");
        }

        p0.mint(detfUser, 10_000_000 * (10 ** uint256(p0.decimals())));
        p1.mint(detfUser, 10_000_000 * (10 ** uint256(p1.decimals())));
        _approveUserPairs(detfUser);
        SeLib.activatePositionVault(se0, pairAddr0, detfUser, address(weth));
        SeLib.activatePositionVault(se1, pairAddr1, detfUser, address(weth));
    }
}
