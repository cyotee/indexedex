// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Crane                                    */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {UniV2Factory} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Factory.sol";
import {UniV2Router02} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Router02.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IUniswapV2StandardExchangeDFPkg,
    UniswapV2StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {
    UniswapV2_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol";

/* -------------------------------------------------------------------------- */
/*                              Buffer Pool Base                               */
/* -------------------------------------------------------------------------- */

import {
    TestBase_StandardExchangeBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title TestBase_StandardExchangeBufferPool_UniswapV2
 * @notice Variant of the Standard Exchange Buffer Pool integration test base that
 *         uses a Uniswap V2 SE Vault as the pool's underlying, instead of the default
 *         Aerodrome SE Vault.
 *
 * @dev Override strategy:
 *      - `_deploySEVault()` — deploys UniV2Factory + Router stubs, creates a fresh pair
 *        of (dai, usdc) test tokens, seeds liquidity, then deploys UniswapV2StandardExchangeDFPkg
 *        and the SE vault wrapping that pair. Sets `seVault`, `tta`, `ttb`, and `shares`.
 *      - `mintShares()` — overrides the Aerodrome-specific LP → deposit flow with the V2
 *        addLiquidity → SE vault deposit flow.
 *      - `_initPool()` — overrides the Aerodrome-specific pool init flow with the V2 path.
 *      - `mintTTA()` — inherited as-is (still calls dai.mint), so no override needed.
 *
 *      The Aerodrome infrastructure fields (`aeroForwarder`, etc.) remain at their zero-values
 *      because `_deploySEVault()` is fully overridden and never calls `_deployAerodromeInfrastructure`.
 *
 *      All behavior libraries continue to work unchanged because they consume only the abstract
 *      `TestBase_StandardExchangeBufferPool` interface.
 */
abstract contract TestBase_StandardExchangeBufferPool_UniswapV2 is TestBase_StandardExchangeBufferPool {
    using UniswapV2_Component_FactoryService for IFacet;
    using UniswapV2_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV2_Component_FactoryService for IUniswapV2StandardExchangeDFPkg;

    /* ---------------------------------------------------------------------- */
    /*                        Uniswap V2 Infrastructure                        */
    /* ---------------------------------------------------------------------- */

    address internal uniV2FeeToSetter;
    IUniswapV2Factory internal uniV2Factory;
    IUniswapV2Router internal uniV2Router;
    IUniswapV2Pair internal uniV2DaiUsdcPair;
    IUniswapV2StandardExchangeDFPkg internal uniV2StdExDFPkg;

    /// @dev Amount of DAI + USDC used to seed initial reserves in the V2 pair.
    ///      The V2 ZapIn path (single-token deposit) involves swapping half the TTA for
    ///      USDC before adding liquidity, which incurs price impact.  Seeding with a large
    ///      amount (10M ether each) ensures the 10 DAI test swap has negligible slippage
    ///      and the hook's exchangeIn output closely matches the pool's rated amountOut.
    uint256 internal constant V2_SEED_AMOUNT = 10_000_000e18;

    /* ---------------------------------------------------------------------- */
    /*                       SE Vault Deployment Override                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Deploys a Uniswap V2 SE Vault wrapping a fresh DAI/USDC V2 pair.
     *
     * @dev Steps:
     *      1. Deploy UniV2Factory + UniV2Router02 stubs.
     *      2. Create a DAI/USDC pair via the factory.
     *      3. Seed the pair with balanced liquidity so `previewExchangeOut` returns a non-zero rate.
     *      4. Deploy UniswapV2StandardExchangeDFPkg (via UniswapV2_Component_FactoryService).
     *      5. Deploy the SE vault diamond wrapping the pair.
     *      6. Set `seVault`, `tta`, `ttb`, `shares` and approve all actors.
     */
    function _deploySEVault() internal virtual override {
        // ------------------------------------------------------------------ //
        // 1. Deploy UniV2 infrastructure (factory + router stubs).
        // ------------------------------------------------------------------ //
        uniV2FeeToSetter = makeAddr("uniV2FeeToSetter");
        vm.label(uniV2FeeToSetter, "uniV2FeeToSetter");

        uniV2Factory = IUniswapV2Factory(new UniV2Factory(uniV2FeeToSetter));
        vm.label(address(uniV2Factory), "UniV2Factory");

        uniV2Router = IUniswapV2Router(new UniV2Router02(address(uniV2Factory), address(weth)));
        vm.label(address(uniV2Router), "UniV2Router02");

        // ------------------------------------------------------------------ //
        // 2. Create DAI/USDC pair.
        //    dai and usdc are ERC20TestToken instances from TestBase_BalancerV3Vault.
        // ------------------------------------------------------------------ //
        address pairAddr = uniV2Factory.createPair(address(dai), address(usdc));
        uniV2DaiUsdcPair = IUniswapV2Pair(pairAddr);
        vm.label(pairAddr, "UniV2DaiUsdcPair");

        // ------------------------------------------------------------------ //
        // 3. Seed the pair with initial reserves (needed for non-zero rate).
        // ------------------------------------------------------------------ //
        _seedUniV2Liquidity();

        // ------------------------------------------------------------------ //
        // 4a. Ensure the shared ERC20/ERC4626 facets are deployed.
        //     The parent's Aerodrome path calls _deploySeVaultFacets() which
        //     populates erc20Facet, erc4626Facet, etc.  Since we skip that path
        //     we call it explicitly here so the V2 PkgInit has non-zero facets.
        // ------------------------------------------------------------------ //
        _deploySeVaultFacets();

        // ------------------------------------------------------------------ //
        // 4b. Deploy UniswapV2StandardExchangeDFPkg.
        // ------------------------------------------------------------------ //
        _deployUniV2SEVaultPkg();

        // ------------------------------------------------------------------ //
        // 5. Deploy the SE vault wrapping the V2 pair.
        // ------------------------------------------------------------------ //
        address vaultAddr = uniV2StdExDFPkg.deployVault(uniV2DaiUsdcPair);
        seVault = IStandardExchangeProxy(vaultAddr);
        vm.label(vaultAddr, "UniV2DaiUsdcSeVault");

        // ------------------------------------------------------------------ //
        // 6. Set parent state vars.
        //    tta  = DAI  (the TTA side of the buffer pool)
        //    ttb  = USDC (the other side of the SE vault underlying)
        //    shares = SE vault itself (ERC20 whose address == vaultAddr)
        // ------------------------------------------------------------------ //
        tta    = IERC20(address(dai));
        ttb    = IERC20(address(usdc));
        shares = IERC20(vaultAddr);

        // ------------------------------------------------------------------ //
        // 7. Approve all test actors so the BV3 router can pull tokens.
        //    The V2 pair LP token must be approved to the SE vault;
        //    the SE vault share token (= vaultAddr) must be approved to permit2
        //    and the BV3 router.
        // ------------------------------------------------------------------ //
        for (uint256 i = 0; i < users.length; ++i) {
            vm.startPrank(users[i]);
            // V2 pair LP token → SE vault (needed for depositVault / mintShares)
            IERC20(pairAddr).approve(vaultAddr, type(uint256).max);
            // SE vault share token → permit2 (so BV3 router can pull shares)
            IERC20(vaultAddr).approve(address(permit2), type(uint256).max);
            permit2.approve(vaultAddr, address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                    Uniswap V2 SE Vault Pkg Deployment                   */
    /* ---------------------------------------------------------------------- */

    function _deployUniV2SEVaultPkg() internal virtual {
        // Deploy the two SE-vault-specific facets via the factory service.
        IFacet v2ExchangeInFacet  = create3Factory.deployUniswapV2StandardExchangeInFacet();
        IFacet v2ExchangeOutFacet = create3Factory.deployUniswapV2StandardExchangeOutFacet();

        // Build PkgInit — mirrors TestBase_UniswapV2StandardExchange.setUp() exactly.
        IUniswapV2StandardExchangeDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet                        = erc20Facet;
        pkgInit.erc2612Facet                      = erc2612Facet;
        pkgInit.erc5267Facet                      = erc5267Facet;
        pkgInit.erc4626Facet                      = erc4626Facet;
        pkgInit.erc4626BasicVaultFacet            = erc4626BasicVaultFacet;
        pkgInit.erc4626StandardVaultFacet         = erc4626StandardVaultFacet;
        pkgInit.uniswapV2StandardExchangeInFacet  = v2ExchangeInFacet;
        pkgInit.uniswapV2StandardExchangeOutFacet = v2ExchangeOutFacet;
        pkgInit.vaultFeeOracleQuery               = indexedexManager;
        pkgInit.vaultRegistryDeployment           = indexedexManager;
        pkgInit.permit2                           = permit2;
        pkgInit.uniswapV2Factory                  = uniV2Factory;
        pkgInit.uniswapV2Router                   = uniV2Router;

        vm.startPrank(owner);
        uniV2StdExDFPkg = UniswapV2_Component_FactoryService.deployUniswapV2StandardExchangeDFPkg(
            indexedexManager,
            pkgInit
        );
        vm.stopPrank();
        vm.label(address(uniV2StdExDFPkg), "UniswapV2StandardExchangeDFPkg");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Uniswap V2 Pool Seeding                         */
    /* ---------------------------------------------------------------------- */

    function _seedUniV2Liquidity() internal virtual {
        dai.mint(lp, V2_SEED_AMOUNT);
        usdc.mint(lp, V2_SEED_AMOUNT);

        vm.startPrank(lp);
        dai.approve(address(uniV2Router), V2_SEED_AMOUNT);
        usdc.approve(address(uniV2Router), V2_SEED_AMOUNT);
        uniV2Router.addLiquidity(
            address(dai),
            address(usdc),
            V2_SEED_AMOUNT,
            V2_SEED_AMOUNT,
            1,
            1,
            lp,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                       mintShares Override (V2 path)                     */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mint SE vault shares by going through the V2 addLiquidity → SE vault deposit path.
     * @dev Mints `daiAmount` DAI and an equal amount of USDC to `recipient`, adds liquidity to
     *      the V2 DAI/USDC pair, then deposits the resulting LP tokens into the SE vault.
     *      Permit2 approvals for the SE vault share token were set in `_deploySEVault`.
     * @param recipient  Address that will receive SE vault shares.
     * @param daiAmount  Amount of DAI (and USDC) to use for V2 liquidity.
     * @return sharesOut Number of SE vault shares minted to `recipient`.
     */
    function mintShares(address recipient, uint256 daiAmount) public override returns (uint256 sharesOut) {
        dai.mint(recipient, daiAmount);
        usdc.mint(recipient, daiAmount);

        vm.startPrank(recipient);
        dai.approve(address(uniV2Router), daiAmount);
        usdc.approve(address(uniV2Router), daiAmount);

        (,, uint256 lpOut) = uniV2Router.addLiquidity(
            address(dai),
            address(usdc),
            daiAmount,
            daiAmount,
            1,
            1,
            recipient,
            block.timestamp + 1 hours
        );

        // Approve the SE vault to pull the LP tokens, then deposit.
        IERC20(address(uniV2DaiUsdcPair)).approve(address(seVault), lpOut);
        sharesOut = seVault.deposit(lpOut, recipient);
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         _initPool Override (V2 path)                    */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Initializes the buffer pool using V2-derived SE vault shares.
     * @dev Mirrors the Aerodrome path but uses the V2 router + pair instead.
     *      Alice adds liquidity to the V2 pair, deposits LP tokens into the SE vault,
     *      then initializes the buffer pool with the received shares.
     */
    function _initPool() internal virtual override {
        // Step 1: Mint DAI + USDC to alice and add liquidity to the V2 pair.
        dai.mint(alice, INITIAL_SHARES_RAW * 2);
        usdc.mint(alice, INITIAL_SHARES_RAW * 2);

        vm.startPrank(alice);
        dai.approve(address(uniV2Router), INITIAL_SHARES_RAW * 2);
        usdc.approve(address(uniV2Router), INITIAL_SHARES_RAW * 2);
        (,, uint256 lpOut) = uniV2Router.addLiquidity(
            address(dai),
            address(usdc),
            INITIAL_SHARES_RAW * 2,
            INITIAL_SHARES_RAW * 2,
            1,
            1,
            alice,
            block.timestamp + 1 hours
        );

        // Step 2: Deposit V2 LP tokens into SE vault to receive shares.
        IERC20(address(uniV2DaiUsdcPair)).approve(address(seVault), lpOut);
        uint256 seSharesOut = seVault.deposit(lpOut, alice);

        // Step 3: Mint TTA (DAI) to alice for the TTA side of the buffer pool initialization.
        dai.mint(alice, seSharesOut);

        // Step 4: Approve the BV3 router for both tokens (via permit2, already set for DAI;
        //         SE vault share token approval was set in _deploySEVault).
        IERC20(address(dai)).approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);

        // Step 5: Initialize the buffer pool via the BV3 RouterMock.
        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(bufferPool);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = seSharesOut;
        amounts[1] = seSharesOut;

        router.initialize(bufferPool, poolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }
}
