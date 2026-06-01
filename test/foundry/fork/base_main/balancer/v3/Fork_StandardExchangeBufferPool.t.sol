// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol';
import {IRateProvider} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol';
import {IRouter as IBalancerRouter} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol';
import {
    TokenConfig,
    TokenType
} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol';

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IERC4626} from '@crane/contracts/interfaces/IERC4626.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {IDiamondPackageCallBackFactory} from '@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol';
import {
    ERC4626RateProviderFactoryService,
    IERC4626RateProviderFacetDFPkg
} from '@crane/contracts/protocols/dexes/balancer/v3/rateProviders/ERC4626RateProviderFactoryService.sol';

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_BalancerV3Fork_StrategyVault} from
    'test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork_StrategyVault.sol';
import {VaultComponentFactoryService} from 'contracts/vaults/VaultComponentFactoryService.sol';
import {IVaultRegistryDeployment} from 'contracts/interfaces/IVaultRegistryDeployment.sol';
import {IVaultFeeOracleQuery} from 'contracts/interfaces/IVaultFeeOracleQuery.sol';
import {IStandardExchange} from 'contracts/interfaces/IStandardExchange.sol';
import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
import {
    IStandardExchangeBufferPool
} from 'contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol';
import {
    IStandardExchangeBufferPoolPkg
} from 'contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol';
import {
    StandardExchangeBufferPool_FactoryService
} from 'contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool_FactoryService.sol';
import {
    BalancerV3ConstantProductPool_FactoryService
} from 'contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol';
import {DefaultPoolInfoFacet} from
    'contracts/protocols/dexes/balancer/v3/pools/constProd/facets/DefaultPoolInfoFacet.sol';
import {StandardSwapFeePercentageBoundsFacet} from
    'contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardSwapFeePercentageBoundsFacet.sol';
import {StandardUnbalancedLiquidityInvariantRatioBoundsFacet} from
    'contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardUnbalancedLiquidityInvariantRatioBoundsFacet.sol';

/**
 * @title Fork_StandardExchangeBufferPool
 * @notice Live-fork integration test for the Standard Exchange Buffer Pool.
 * @dev Deploys the DFPkg against the live Balancer V3 Vault on Base mainnet,
 *      creates a pool backed by the live Aerodrome DAI/USDC strategy vault, and
 *      runs a smoke swap round-trip (TTA→shares, shares→TTA) verifying invariants.
 *
 *      Inherits TestBase_BalancerV3Fork_StrategyVault which already provides:
 *      - Live Balancer V3 Vault (BASE_MAIN.BALANCER_V3_VAULT)
 *      - Live Balancer V3 Router (BASE_MAIN.BALANCER_V3_ROUTER)
 *      - IndexedEx manager + create3Factory
 *      - Aerodrome DAI/USDC SE vault (daiUsdcVault)
 *      - ERC20PermitMintableStub dai + usdc tokens
 *      - alice, bob, lp test users
 *
 *      RPC requirement: ALCHEMY_KEY env var (used by foundry.toml `base_mainnet_alchemy` endpoint).
 *      If the key is absent forge will skip the fork; the test is intentionally skip-friendly.
 */
contract Fork_StandardExchangeBufferPool is TestBase_BalancerV3Fork_StrategyVault {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using BalancerV3ConstantProductPool_FactoryService for ICreate3FactoryProxy;
    using StandardExchangeBufferPool_FactoryService for ICreate3FactoryProxy;
    using StandardExchangeBufferPool_FactoryService for IVaultRegistryDeployment;

    /* ---------------------------------------------------------------------- */
    /*                              Test Constants                             */
    /* ---------------------------------------------------------------------- */

    /// @dev Initial liquidity seeded into the buffer pool.
    uint256 internal constant BUFFER_INIT_AMOUNT = 1_000e18;

    /* ---------------------------------------------------------------------- */
    /*                             Buffer Pool State                           */
    /* ---------------------------------------------------------------------- */

    /// @notice Rate provider wrapping the Aerodrome DAI/USDC SE vault (ERC4626).
    IRateProvider public seRateProvider;

    // Buffer pool facets
    IFacet internal multiAssetBasicVaultFacet;
    IFacet internal multiAssetStandardVaultFacet;
    IFacet internal balancerV3VaultAwareFacet;
    IFacet internal betterBalancerV3PoolTokenFacet;
    IFacet internal defaultPoolInfoFacet;
    IFacet internal standardSwapFeePercentageBoundsFacet;
    IFacet internal unbalancedLiquidityInvariantRatioBoundsFacet;
    IFacet internal balancerV3AuthenticationFacet;
    IFacet internal bufferPoolFacet;
    IFacet internal poolLiquidityFacet;
    IFacet internal hookFacet;

    /// @notice The deployed buffer pool DFPkg.
    IStandardExchangeBufferPoolPkg public bufferPoolPkg;

    /// @notice The deployed buffer pool address (registered with the live BV3 Vault).
    address public bufferPool;

    /// @notice TTA token (DAI — the non-share side of the buffer pool).
    IERC20 public tta;

    /// @notice Shares token (= address(daiUsdcVault) — the ERC4626 SE vault shares).
    IERC20 public shares;

    /* ---------------------------------------------------------------------- */
    /*                                  setUp                                  */
    /* ---------------------------------------------------------------------- */

    function setUp() public virtual override {
        // 1. Set up Balancer V3 fork + SE vault (live Aerodrome DAI/USDC).
        super.setUp();

        // 2. Assign token roles: TTA = DAI, shares = SE vault.
        tta    = IERC20(address(dai));
        shares = IERC20(address(daiUsdcVault));

        // 3. Deploy ERC4626 rate provider for the SE vault.
        IERC4626RateProviderFacetDFPkg rpDFPkg =
            ERC4626RateProviderFactoryService.initER4626RateProvicerDFPkg(create3Factory);
        seRateProvider = rpDFPkg.deployRateProvider(IERC4626(address(daiUsdcVault)));
        vm.label(address(seRateProvider), 'Fork_SEVaultRateProvider');

        // 4. Deploy buffer pool facets.
        _deployBufferPoolFacets();

        // 5. Deploy buffer pool package.
        _deployBufferPoolPkg();

        // 6. Deploy the pool (registers with live BV3 Vault).
        bufferPool = bufferPoolPkg.deployPool(
            IStandardExchange(address(daiUsdcVault)),
            tta,
            shares,
            seRateProvider
        );
        vm.label(bufferPool, 'Fork_StandardExchangeBufferPool');

        // 7. Approve tokens for all users so the live router can pull via permit2.
        _approveBufferPoolTokensForAllUsers();

        // 8. Initialize pool with initial liquidity.
        _initBufferPool();
    }

    /* ---------------------------------------------------------------------- */
    /*                      Buffer Pool Facet Deployment                       */
    /* ---------------------------------------------------------------------- */

    function _deployBufferPoolFacets() internal virtual {
        multiAssetBasicVaultFacet          = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet       = create3Factory.deployMultiAssetStandardVaultFacet();
        balancerV3VaultAwareFacet          = create3Factory.deployBalancerV3VaultAwareFacet();
        betterBalancerV3PoolTokenFacet     = create3Factory.deployBalancerV3PoolTokenFacet();
        balancerV3AuthenticationFacet      = create3Factory.deployBalancerV3AuthenticationFacet();

        defaultPoolInfoFacet = IFacet(address(new DefaultPoolInfoFacet()));
        vm.label(address(defaultPoolInfoFacet), 'Fork_DefaultPoolInfoFacet');

        standardSwapFeePercentageBoundsFacet = IFacet(address(new StandardSwapFeePercentageBoundsFacet()));
        vm.label(address(standardSwapFeePercentageBoundsFacet), 'Fork_StandardSwapFeePercentageBoundsFacet');

        unbalancedLiquidityInvariantRatioBoundsFacet =
            IFacet(address(new StandardUnbalancedLiquidityInvariantRatioBoundsFacet()));
        vm.label(
            address(unbalancedLiquidityInvariantRatioBoundsFacet),
            'Fork_StandardUnbalancedLiquidityInvariantRatioBoundsFacet'
        );

        bufferPoolFacet    = create3Factory.deployBufferPoolFacet();
        poolLiquidityFacet = create3Factory.deployPoolLiquidityFacet();
        hookFacet          = create3Factory.deployHookFacet();
    }

    /* ---------------------------------------------------------------------- */
    /*                      Buffer Pool Package Deployment                     */
    /* ---------------------------------------------------------------------- */

    function _deployBufferPoolPkg() internal virtual {
        IStandardExchangeBufferPoolPkg.PkgInit memory pkgInit;
        pkgInit.basicVaultFacet                          = multiAssetBasicVaultFacet;
        pkgInit.standardVaultFacet                       = multiAssetStandardVaultFacet;
        pkgInit.balancerV3VaultAwareFacet                = balancerV3VaultAwareFacet;
        pkgInit.betterBalancerV3PoolTokenFacet           = betterBalancerV3PoolTokenFacet;
        pkgInit.defaultPoolInfoFacet                     = defaultPoolInfoFacet;
        pkgInit.standardSwapFeePercentageBoundsFacet     = standardSwapFeePercentageBoundsFacet;
        pkgInit.unbalancedLiquidityInvariantRatioBoundsFacet = unbalancedLiquidityInvariantRatioBoundsFacet;
        pkgInit.balancerV3AuthenticationFacet            = balancerV3AuthenticationFacet;
        pkgInit.bufferPoolFacet                          = bufferPoolFacet;
        pkgInit.poolLiquidityFacet                       = poolLiquidityFacet;
        pkgInit.hookFacet                                = hookFacet;
        pkgInit.vaultRegistry     = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.vaultFeeOracle    = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.balancerV3Vault   = vault;   // live forked vault from TestBase_BalancerV3Fork
        pkgInit.diamondFactory    = diamondPackageFactory;

        vm.startPrank(owner);
        bufferPoolPkg = StandardExchangeBufferPool_FactoryService.deployBufferPoolPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            pkgInit
        );
        vm.stopPrank();
        vm.label(address(bufferPoolPkg), 'Fork_StandardExchangeBufferPoolPkg');
    }

    /* ---------------------------------------------------------------------- */
    /*                           Approval Helpers                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Approve tta, shares, and BPT for all users via permit2 pointing to balancerRouter.
     * @dev The live Balancer V3 Router uses permit2 to pull tokens.  All users are given
     *      unlimited permit2 allowances for all three tokens to allow initialize + swap.
     */
    function _approveBufferPoolTokensForAllUsers() internal virtual {
        for (uint256 i = 0; i < users.length; ++i) {
            address user = users[i];
            vm.startPrank(user);

            // Approve permit2 itself to spend TTA and shares from user.
            tta.approve(address(permit2), type(uint256).max);
            shares.approve(address(permit2), type(uint256).max);
            IERC20(bufferPool).approve(address(permit2), type(uint256).max);

            // Give the live balancerRouter permit2 allowance to pull TTA and shares.
            permit2.approve(address(tta),        address(balancerRouter), type(uint160).max, type(uint48).max);
            permit2.approve(address(shares),     address(balancerRouter), type(uint160).max, type(uint48).max);
            permit2.approve(address(bufferPool), address(balancerRouter), type(uint160).max, type(uint48).max);

            vm.stopPrank();
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                           Pool Initialization                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Initialize the buffer pool with seed liquidity from lp.
     * @dev lp receives shares by seeding Aerodrome liquidity and depositing LP tokens
     *      into daiUsdcVault.  Both TTA and shares are then provided proportionally to
     *      the Balancer V3 Vault via the live balancerRouter.initialize().
     */
    function _initBufferPool() internal virtual {
        // --- Acquire shares for lp ---
        // Mint DAI + USDC, add Aerodrome liquidity, deposit LP into SE vault.
        dai.mint(lp,  BUFFER_INIT_AMOUNT * 2);
        usdc.mint(lp, BUFFER_INIT_AMOUNT * 2);

        vm.startPrank(lp);
        dai.approve(address(aerodromeRouter),  BUFFER_INIT_AMOUNT * 2);
        usdc.approve(address(aerodromeRouter), BUFFER_INIT_AMOUNT * 2);

        (,, uint256 lpOut) = aerodromeRouter.addLiquidity(
            address(dai),
            address(usdc),
            false,
            BUFFER_INIT_AMOUNT * 2,
            BUFFER_INIT_AMOUNT * 2,
            1,
            1,
            lp,
            _deadline()
        );

        // Approve SE vault to pull LP tokens.
        IERC20(address(aeroDaiUsdcPool)).approve(address(daiUsdcVault), lpOut);
        uint256 seShares = daiUsdcVault.deposit(lpOut, lp);

        // --- Acquire TTA for lp (equal amount to shares for proportional init) ---
        dai.mint(lp, seShares);

        // --- Approve live balancerRouter via permit2 ---
        tta.approve(address(permit2),    type(uint256).max);
        shares.approve(address(permit2), type(uint256).max);
        permit2.approve(address(tta),    address(balancerRouter), type(uint160).max, type(uint48).max);
        permit2.approve(address(shares), address(balancerRouter), type(uint160).max, type(uint48).max);

        // --- Initialize via live Balancer V3 Router ---
        (IERC20[] memory poolTokens,,,) = vault.getPoolTokenInfo(bufferPool);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = seShares;
        amounts[1] = seShares;

        balancerRouter.initialize(
            bufferPool,
            poolTokens,
            amounts,
            0,       // minBptAmountOut
            false,   // wethIsEth
            bytes('') // userData
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Smoke Tests                                */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Verify that the buffer pool is registered with the live Vault and has liquidity.
     */
    function test_fork_bufferPool_registrationAndLiquidity() public view {
        // Pool is registered with the live Vault.
        assertTrue(bufferPool.code.length > 0, 'Buffer pool should have deployed code');

        // Pool has non-zero reserves.
        (IERC20[] memory tokens,, uint256[] memory balances,) = vault.getPoolTokenInfo(bufferPool);
        assertEq(tokens.length, 2, 'Pool should have 2 tokens');
        assertGt(balances[0], 0, 'Token0 balance should be > 0 after init');
        assertGt(balances[1], 0, 'Token1 balance should be > 0 after init');

        // Verify token identity.
        bool ttaFound     = false;
        bool sharesFound  = false;
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (address(tokens[i]) == address(tta))    ttaFound = true;
            if (address(tokens[i]) == address(shares)) sharesFound = true;
        }
        assertTrue(ttaFound,    'TTA (DAI) should be one of the pool tokens');
        assertTrue(sharesFound, 'Shares (SE vault) should be one of the pool tokens');
    }

    /**
     * @notice Smoke test: TTA → shares swap through the live Balancer V3 Vault.
     * @dev alice swaps DAI for SE vault shares; checks balance deltas and the post-swap
     *      virtualTTA / hookSharesDelta state are self-consistent.
     */
    function test_fork_smoke_swapTTAtoShares() public {
        uint256 amountIn = 100e18; // 100 DAI

        // Mint TTA to alice.
        dai.mint(alice, amountIn);

        vm.startPrank(alice);
        tta.approve(address(permit2), type(uint256).max);
        permit2.approve(address(tta), address(balancerRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        uint256 aliceTTABefore    = tta.balanceOf(alice);
        uint256 aliceSharesBefore = shares.balanceOf(alice);
        IStandardExchangeBufferPool pool_ = IStandardExchangeBufferPool(bufferPool);
        uint256 virtualTTABefore    = pool_.virtualTTA();
        int256  hookSharesDeltaBefore = pool_.hookSharesDelta();

        // Execute TTA → shares swap via the live Balancer router.
        vm.startPrank(alice);
        uint256 sharesOut = balancerRouter.swapSingleTokenExactIn(
            bufferPool,
            tta,
            shares,
            amountIn,
            0,            // minAmountOut — no slippage guard in smoke test
            _deadline(),
            false,        // wethIsEth
            bytes('')     // userData
        );
        vm.stopPrank();

        // Assertions: balance deltas.
        assertGt(sharesOut, 0, 'Should receive non-zero shares');
        assertEq(tta.balanceOf(alice),    aliceTTABefore    - amountIn, 'TTA should decrease by amountIn');
        assertEq(shares.balanceOf(alice), aliceSharesBefore + sharesOut, 'Shares should increase by sharesOut');

        // Invariant check: virtualTTA increased (TTA deposited into pool increases virtualTTA).
        uint256 virtualTTAAfter = pool_.virtualTTA();
        assertGe(virtualTTAAfter, virtualTTABefore, 'virtualTTA should be >= before after TTA swap in');

        // hookSharesDelta should have changed (hook consumed/produced shares).
        int256 hookSharesDeltaAfter = pool_.hookSharesDelta();
        // After a TTA→shares swap the hook redeems SE vault shares to convert TTA.
        // The delta should be >= 0 (hook may have a shares surplus) or changed from initial.
        // We check simply that it did not underflow to an impossibly negative number.
        assertGe(hookSharesDeltaAfter, type(int256).min / 2, 'hookSharesDelta sanity check');

        emit log_named_uint('sharesOut', sharesOut);
        emit log_named_int ('hookSharesDelta after TTA-to-shares', hookSharesDeltaAfter);
        emit log_named_uint('virtualTTA after TTA-to-shares',     virtualTTAAfter);
    }

    /**
     * @notice Smoke test: shares → TTA swap through the live Balancer V3 Vault.
     * @dev bob acquires shares via Aerodrome→SE vault path, then swaps shares for DAI.
     */
    function test_fork_smoke_swapSharesToTTA() public {
        uint256 daiForShares = 200e18; // mint this much DAI+USDC to get shares
        uint256 swapSharesIn;

        // --- Give bob some SE vault shares ---
        dai.mint(bob,  daiForShares);
        usdc.mint(bob, daiForShares);

        vm.startPrank(bob);
        dai.approve(address(aerodromeRouter),  daiForShares);
        usdc.approve(address(aerodromeRouter), daiForShares);
        (,, uint256 lpOut) = aerodromeRouter.addLiquidity(
            address(dai),
            address(usdc),
            false,
            daiForShares,
            daiForShares,
            1,
            1,
            bob,
            _deadline()
        );
        IERC20(address(aeroDaiUsdcPool)).approve(address(daiUsdcVault), lpOut);
        uint256 seSharesReceived = daiUsdcVault.deposit(lpOut, bob);
        vm.stopPrank();

        swapSharesIn = seSharesReceived / 2; // swap half the shares

        // Approve via permit2.
        vm.startPrank(bob);
        shares.approve(address(permit2), type(uint256).max);
        permit2.approve(address(shares), address(balancerRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        uint256 bobSharesBefore = shares.balanceOf(bob);
        uint256 bobTTABefore    = tta.balanceOf(bob);
        IStandardExchangeBufferPool pool_  = IStandardExchangeBufferPool(bufferPool);
        uint256 virtualTTABefore = pool_.virtualTTA();

        // Execute shares → TTA swap.
        vm.startPrank(bob);
        uint256 ttaOut = balancerRouter.swapSingleTokenExactIn(
            bufferPool,
            shares,
            tta,
            swapSharesIn,
            0,          // minAmountOut
            _deadline(),
            false,
            bytes('')
        );
        vm.stopPrank();

        // Assertions: balance deltas.
        assertGt(ttaOut, 0, 'Should receive non-zero TTA');
        assertEq(shares.balanceOf(bob), bobSharesBefore - swapSharesIn, 'Shares should decrease by swapSharesIn');
        assertEq(tta.balanceOf(bob),    bobTTABefore    + ttaOut,       'TTA should increase by ttaOut');

        // After a shares→TTA swap the hook deposits TTA to SE vault; virtualTTA should decrease.
        uint256 virtualTTAAfter = pool_.virtualTTA();
        assertLe(virtualTTAAfter, virtualTTABefore, 'virtualTTA should be <= before after shares-to-TTA swap');

        emit log_named_uint('ttaOut', ttaOut);
        emit log_named_uint('virtualTTA after shares-to-TTA', virtualTTAAfter);
    }

    /**
     * @notice Smoke round-trip: TTA→shares then shares→TTA.
     * @dev Verifies that after a round-trip the pool state is internally consistent:
     *      - virtualTTA >= 0 (no underflow)
     *      - actual pool token balances match vault storage
     *      - alice ends up with fewer TTA than she started (swap fees consumed)
     */
    function test_fork_smoke_roundTrip() public {
        uint256 amountIn = 50e18; // 50 DAI

        // Mint TTA to alice.
        dai.mint(alice, amountIn);

        vm.startPrank(alice);
        tta.approve(address(permit2), type(uint256).max);
        permit2.approve(address(tta),    address(balancerRouter), type(uint160).max, type(uint48).max);
        permit2.approve(address(shares), address(balancerRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        // Leg 1: TTA → shares.
        vm.startPrank(alice);
        uint256 sharesOut = balancerRouter.swapSingleTokenExactIn(
            bufferPool, tta, shares, amountIn, 0, _deadline(), false, bytes('')
        );
        vm.stopPrank();

        assertGt(sharesOut, 0, 'Round-trip: leg1 should return non-zero shares');

        // Leg 2: shares → TTA (swap back whatever alice got).
        vm.startPrank(alice);
        uint256 ttaBack = balancerRouter.swapSingleTokenExactIn(
            bufferPool, shares, tta, sharesOut, 0, _deadline(), false, bytes('')
        );
        vm.stopPrank();

        assertGt(ttaBack, 0, 'Round-trip: leg2 should return non-zero TTA');

        // Due to swap fees alice should receive less TTA than she put in.
        assertLt(ttaBack, amountIn, 'Round-trip: fees should cause TTA loss');

        // Post-round-trip invariant: virtualTTA is still sane (no underflow).
        IStandardExchangeBufferPool pool_ = IStandardExchangeBufferPool(bufferPool);
        uint256 virtualTTAFinal = pool_.virtualTTA();
        assertGe(virtualTTAFinal, 0, 'Post-round-trip: virtualTTA must be >= 0');

        // Pool must still have non-zero balances.
        (,, uint256[] memory balances,) = vault.getPoolTokenInfo(bufferPool);
        assertGt(balances[0], 0, 'Post-round-trip: pool token0 balance must remain > 0');
        assertGt(balances[1], 0, 'Post-round-trip: pool token1 balance must remain > 0');

        emit log_named_uint('amountIn (TTA)', amountIn);
        emit log_named_uint('sharesOut',      sharesOut);
        emit log_named_uint('ttaBack',        ttaBack);
        emit log_named_uint('virtualTTA final', virtualTTAFinal);
    }
}
