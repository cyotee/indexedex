// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Test} from "forge-std/Test.sol";

/* -------------------------------------------------------------------------- */
/*                                Open Zeppelin                               */
/* -------------------------------------------------------------------------- */

import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {PoolFactoryMock} from "contracts/test/balancer/v3/PoolFactoryMock.sol";
import {PoolHooksMock} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/PoolHooksMock.sol";
import {TokenConfig, HookFlags} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {
    CastingHelpers
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/CastingHelpers.sol";
import {ArrayHelpers} from "contracts/test/balancer/v3/ArrayHelpers.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TestBase_BalancerV3Vault
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3Vault.sol";
import {SenderGuardFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {PoolFactory} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/PoolFactory.sol";
import {Router} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Router.sol";
import {FactoryRegistry} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/FactoryRegistry.sol";
import {
    VotingRewardsFactory
} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/VotingRewardsFactory.sol";
import {GaugeFactory} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/GaugeFactory.sol";
import {
    ManagedRewardsFactory
} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/ManagedRewardsFactory.sol";
import {Forwarder} from "@crane/contracts/protocols/utils/gsn/forwarder/Forwarder.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    IBalancerV3StandardExchangeRouterDFPkg
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";
import {
    BalancerV3StandardExchangeRouter_FactoryService
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    IAerodromeStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";
import {
    Aerodrome_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol";

/**
 * @title TestBase_BalancerV3StandardExchangeRouter
 * @notice Base test contract for Balancer V3 Standard Exchange Router tests.
 * @dev Provides infrastructure for testing all router routes:
 *      - Direct Balancer swaps
 *      - Strategy vault deposits/withdrawals
 *      - Combined vault + swap operations
 */
contract TestBase_BalancerV3StandardExchangeRouter is TestBase_BalancerV3Vault, IndexedexTest {
    using CastingHelpers for address[];
    using FixedPoint for uint256;
    using ArrayHelpers for *;
    using BalancerV3StandardExchangeRouter_FactoryService for *;
    using VaultComponentFactoryService for *;
    using Aerodrome_Component_FactoryService for *;

    /* ---------------------------------------------------------------------- */
    /*                              Test Constants                            */
    /* ---------------------------------------------------------------------- */

    uint256 internal constant TEST_AMOUNT = 1000e18;
    uint256 internal constant POOL_INIT_AMOUNT = 10_000e18;
    uint256 internal constant AERODROME_POOL_INIT_AMOUNT = 10_000e18;

    /* ---------------------------------------------------------------------- */
    /*                           Router Components                            */
    /* ---------------------------------------------------------------------- */

    IFacet internal senderGuardFacet;
    IFacet internal exactInQueryFacet;
    IFacet internal exactInSwapFacet;
    IFacet internal exactOutQueryFacet;
    IFacet internal exactOutSwapFacet;
    IFacet internal batchExactInFacet;
    IFacet internal batchExactOutFacet;
    IFacet internal prepayFacet;
    IFacet internal prepayHooksFacet;
    IFacet internal permit2WitnessFacet;

    IBalancerV3StandardExchangeRouterDFPkg internal seRouterDFPkg;
    IBalancerV3StandardExchangeRouterProxy internal seRouter;

    /* ---------------------------------------------------------------------- */
    /*                          Balancer V3 Pools                             */
    /* ---------------------------------------------------------------------- */

    // DAI/USDC constant product pool for direct swaps
    address internal daiUsdcPool;
    uint256 internal daiUsdcPoolInitAmount = POOL_INIT_AMOUNT;

    // DAI/WETH pool for ETH wrapping tests
    address internal daiWethPool;
    uint256 internal daiWethPoolInitAmount = POOL_INIT_AMOUNT;

    // Pool factory and hooks
    address internal testPoolFactory;
    address internal testPoolHooksContract;

    /* ---------------------------------------------------------------------- */
    /*                       Aerodrome Infrastructure                         */
    /* ---------------------------------------------------------------------- */

    Forwarder internal aeroForwarder;
    Pool internal aeroPoolImplementation;
    PoolFactory internal aerodromePoolFactory;
    FactoryRegistry internal aerodromeFactoryRegistry;
    VotingRewardsFactory internal aeroVotingRewardsFactory;
    GaugeFactory internal aeroGaugeFactory;
    ManagedRewardsFactory internal aeroManagedRewardsFactory;
    Router internal aerodromeRouter;

    // Aerodrome pool wrapping DAI/USDC for vault testing
    Pool internal aeroDaiUsdcPool;

    /* ---------------------------------------------------------------------- */
    /*                           Vault Components                             */
    /* ---------------------------------------------------------------------- */

    // Vault facets
    IFacet internal erc20Facet;
    IFacet internal erc5267Facet;
    IFacet internal erc2612Facet;
    IFacet internal erc4626Facet;
    IFacet internal erc4626BasicVaultFacet;
    IFacet internal erc4626StandardVaultFacet;
    IFacet internal aerodromeStandardExchangeInFacet;
    IFacet internal aerodromeStandardExchangeOutFacet;

    // Aerodrome vault package and vault instances
    IAerodromeStandardExchangeDFPkg internal aerodromeStandardExchangeDFPkg;
    IStandardExchangeProxy internal daiUsdcVault;

    /* ---------------------------------------------------------------------- */
    /*                               Setup                                    */
    /* ---------------------------------------------------------------------- */

    function setUp() public virtual override(TestBase_BalancerV3Vault, IndexedexTest) {
        // Initialize Balancer V3 infrastructure (vault, tokens, permit2)
        TestBase_BalancerV3Vault.setUp();
        // Initialize Indexedex infrastructure (factories, fee collector, manager)
        IndexedexTest.setUp();

        // Deploy router components
        _deployRouterFacets();
        _deployRouterPackage();
        _deployRouter();

        // Approve router for all users
        _approveRouterForAllUsers();

        // Create test pools
        _createTestPools();

        // Deploy vault infrastructure for vault route testing
        _deployAerodromeInfrastructure();
        _deployVaultFacets();
        _deployAerodromeVaultPackage();
        _createAerodromeTestPool();
        _deployTestVault();
    }

    /* ---------------------------------------------------------------------- */
    /*                        Router Deployment                               */
    /* ---------------------------------------------------------------------- */

    function _deployRouterFacets() internal virtual {
        // Deploy SenderGuardFacet directly
        senderGuardFacet = IFacet(address(new SenderGuardFacet()));
        vm.label(address(senderGuardFacet), "SenderGuardFacet");

        exactInQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInQueryFacet();
        exactInSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInSwapFacet();
        exactOutQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutQueryFacet();
        exactOutSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutSwapFacet();
        batchExactInFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactInFacet();
        batchExactOutFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactOutFacet();
        prepayFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayFacet();
        prepayHooksFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayHooksFacet();
        permit2WitnessFacet = create3Factory.deployBalancerV3StandardExchangeRouterPermit2WitnessFacet();
    }

    function _deployRouterPackage() internal virtual {
        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit;
        {
            pkgInit.senderGuardFacet = senderGuardFacet;
            pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet = exactInQueryFacet;
            pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet = exactInSwapFacet;
            pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet = exactOutQueryFacet;
            pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet = exactOutSwapFacet;
            pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet = batchExactInFacet;
            pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet = batchExactOutFacet;
            pkgInit.balancerV3StandardExchangeRouterPrepayFacet = prepayFacet;
            pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet = prepayHooksFacet;
            pkgInit.balancerV3StandardExchangePermit2WitnessFacet = permit2WitnessFacet;
            pkgInit.balancerV3Vault = IVault(address(vault));
            pkgInit.permit2 = permit2;
            pkgInit.weth = IWETH(address(weth));
        }

        // seRouterDFPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(
        //     senderGuardFacet,
        //     exactInQueryFacet,
        //     exactOutQueryFacet,
        //     exactInSwapFacet,
        //     exactOutSwapFacet,
        //     prepayFacet,
        //     prepayHooksFacet,
        //     batchExactInFacet,
        //     batchExactOutFacet,
        //     permit2WitnessFacet,
        //     IVault(address(vault)),
        //     permit2,
        //     IWETH(address(weth))
        // );
        seRouterDFPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(
            pkgInit
        );
        vm.label(address(seRouterDFPkg), "BalancerV3StandardExchangeRouterDFPkg");
    }

    function _deployRouter() internal virtual {
        seRouter = diamondPackageFactory.deployBalancerV3StandardExchangeRouter(seRouterDFPkg);
        vm.label(address(seRouter), "BalancerV3StandardExchangeRouter");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Pool Creation                                 */
    /* ---------------------------------------------------------------------- */

    function _createTestPools() internal virtual {
        // Create pool factory
        testPoolFactory = _createPoolFactory();

        // Create hooks
        testPoolHooksContract = _createHook();

        // Create DAI/USDC pool for direct swap tests
        daiUsdcPool = _createDaiUsdcPool();

        // Initialize pool with liquidity
        _initDaiUsdcPool();

        // Create DAI/WETH pool for ETH wrapping tests
        daiWethPool = _createDaiWethPool();

        // Initialize pool with liquidity
        _initDaiWethPool();
    }

    function _createPoolFactory() internal virtual returns (address) {
        PoolFactoryMock factory = new PoolFactoryMock(IVault(address(vault)), 365 days);
        vm.label(address(factory), "PoolFactoryMock");
        return address(factory);
    }

    function _createHook() internal virtual returns (address) {
        HookFlags memory hookFlags;
        PoolHooksMock newHook = new PoolHooksMock(IVault(address(vault)));
        newHook.allowFactory(testPoolFactory);
        newHook.setHookFlags(hookFlags);
        vm.label(address(newHook), "PoolHooksMock");
        return address(newHook);
    }

    function _createDaiUsdcPool() internal virtual returns (address) {
        string memory name = "DAI-USDC Pool";
        string memory symbol = "DAI-USDC";

        address newPool = PoolFactoryMock(testPoolFactory).createPool(name, symbol);
        vm.label(newPool, "daiUsdcPool");

        // Register with sorted tokens
        address[] memory poolTokens = new address[](2);
        if (address(dai) < address(usdc)) {
            poolTokens[0] = address(dai);
            poolTokens[1] = address(usdc);
        } else {
            poolTokens[0] = address(usdc);
            poolTokens[1] = address(dai);
        }

        PoolFactoryMock(testPoolFactory)
            .registerTestPool(newPool, vault.buildTokenConfig(poolTokens.asIERC20()), testPoolHooksContract, lp);

        // Approve pool BPT for all users
        approveForPool(OZIERC20(newPool));

        return newPool;
    }

    function _initDaiUsdcPool() internal virtual {
        // Mint tokens to lp
        dai.mint(lp, daiUsdcPoolInitAmount);
        usdc.mint(lp, daiUsdcPoolInitAmount);

        vm.startPrank(lp);

        // Get sorted token order
        (OZIERC20[] memory poolTokens,,,) = vault.getPoolTokenInfo(daiUsdcPool);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = daiUsdcPoolInitAmount;
        amounts[1] = daiUsdcPoolInitAmount;

        // Use Balancer's RouterMock for pool initialization
        router.initialize(daiUsdcPool, poolTokens, amounts, 0, false, bytes(""));

        vm.stopPrank();
    }

    function _createDaiWethPool() internal virtual returns (address) {
        string memory name = "DAI-WETH Pool";
        string memory symbol = "DAI-WETH";

        address newPool = PoolFactoryMock(testPoolFactory).createPool(name, symbol);
        vm.label(newPool, "daiWethPool");

        // Register with sorted tokens
        address[] memory poolTokens = new address[](2);
        if (address(dai) < address(weth)) {
            poolTokens[0] = address(dai);
            poolTokens[1] = address(weth);
        } else {
            poolTokens[0] = address(weth);
            poolTokens[1] = address(dai);
        }

        PoolFactoryMock(testPoolFactory)
            .registerTestPool(newPool, vault.buildTokenConfig(poolTokens.asIERC20()), testPoolHooksContract, lp);

        // Approve pool BPT for all users
        approveForPool(OZIERC20(newPool));

        return newPool;
    }

    function _initDaiWethPool() internal virtual {
        // Mint tokens to lp
        dai.mint(lp, daiWethPoolInitAmount);
        deal(lp, daiWethPoolInitAmount);

        vm.startPrank(lp);

        // Wrap ETH to WETH
        weth.deposit{value: daiWethPoolInitAmount}();

        // Get sorted token order
        (OZIERC20[] memory poolTokens,,,) = vault.getPoolTokenInfo(daiWethPool);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = daiWethPoolInitAmount;
        amounts[1] = daiWethPoolInitAmount;

        // Use Balancer's RouterMock for pool initialization
        router.initialize(daiWethPool, poolTokens, amounts, 0, false, bytes(""));

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                          Approval Helpers                              */
    /* ---------------------------------------------------------------------- */

    function _approveRouterForAllUsers() internal virtual {
        _approveSpenderForAllUsers(address(seRouter));
    }

    /* ---------------------------------------------------------------------- */
    /*                           Query Helpers                                */
    /* ---------------------------------------------------------------------- */

    function _queryExactIn(
        address pool,
        OZIERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        OZIERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountIn
    ) internal returns (uint256 amountOut) {
        // Query functions require tx.origin = address(0)
        vm.prank(address(0), address(0));
        amountOut = seRouter.querySwapSingleTokenExactIn(
            pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountIn, lp, ""
        );
    }

    function _queryExactOut(
        address pool,
        OZIERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        OZIERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountOut
    ) internal returns (uint256 amountIn) {
        vm.prank(address(0), address(0));
        amountIn = seRouter.querySwapSingleTokenExactOut(
            pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountOut, lp, ""
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                           Swap Helpers                                 */
    /* ---------------------------------------------------------------------- */

    function _swapExactIn(
        address pool,
        OZIERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        OZIERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountIn,
        uint256 minAmountOut
    ) internal returns (uint256 amountOut) {
        amountOut = seRouter.swapSingleTokenExactIn(
            pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountIn, minAmountOut, _deadline(), false, ""
        );
    }

    function _swapExactOut(
        address pool,
        OZIERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        OZIERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountOut,
        uint256 maxAmountIn
    ) internal returns (uint256 amountIn) {
        amountIn = seRouter.swapSingleTokenExactOut(
            pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountOut, maxAmountIn, _deadline(), false, ""
        );
    }

    function _swapExactInWithEth(
        address pool,
        OZIERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        OZIERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        bool wethIsEth
    ) internal returns (uint256 amountOut) {
        uint256 ethValue = wethIsEth && address(tokenIn) == address(weth) ? exactAmountIn : 0;
        amountOut = seRouter.swapSingleTokenExactIn{value: ethValue}(
            pool,
            tokenIn,
            tokenInVault,
            tokenOut,
            tokenOutVault,
            exactAmountIn,
            minAmountOut,
            _deadline(),
            wethIsEth,
            ""
        );
    }

    function _swapExactOutWithEth(
        address pool,
        OZIERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        OZIERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountOut,
        uint256 maxAmountIn,
        bool wethIsEth
    ) internal returns (uint256 amountIn) {
        uint256 ethValue = wethIsEth && address(tokenIn) == address(weth) ? maxAmountIn : 0;
        amountIn = seRouter.swapSingleTokenExactOut{value: ethValue}(
            pool,
            tokenIn,
            tokenInVault,
            tokenOut,
            tokenOutVault,
            exactAmountOut,
            maxAmountIn,
            _deadline(),
            wethIsEth,
            ""
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                          Utility Helpers                               */
    /* ---------------------------------------------------------------------- */

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _noVault() internal pure returns (IStandardExchangeProxy) {
        return IStandardExchangeProxy(address(0));
    }

    function _mintAndApprove(address token, address to, uint256 amount) internal {
        if (token == address(dai)) {
            dai.mint(to, amount);
        } else if (token == address(usdc)) {
            usdc.mint(to, amount);
        } else if (token == address(weth)) {
            deal(to, amount);
            vm.prank(to);
            weth.deposit{value: amount}();
        }

        vm.prank(to);
        OZIERC20(token).approve(address(permit2), type(uint256).max);
        vm.prank(to);
        permit2.approve(token, address(seRouter), type(uint160).max, type(uint48).max);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Token Sorting Helpers                             */
    /* ---------------------------------------------------------------------- */

    function _getPoolTokens(address pool) internal view returns (OZIERC20 token0, OZIERC20 token1) {
        (OZIERC20[] memory tokens,,,) = vault.getPoolTokenInfo(pool);
        return (tokens[0], tokens[1]);
    }

    function _isToken0(address pool, address token) internal view returns (bool) {
        (OZIERC20 token0,) = _getPoolTokens(pool);
        return address(token0) == token;
    }

    /* ---------------------------------------------------------------------- */
    /*                    Aerodrome Infrastructure Deployment                 */
    /* ---------------------------------------------------------------------- */

    function _deployAerodromeInfrastructure() internal virtual {
        // Deploy forwarder
        aeroForwarder = new Forwarder();
        vm.label(address(aeroForwarder), "AeroForwarder");

        // Deploy pool implementation
        aeroPoolImplementation = new Pool();
        vm.label(address(aeroPoolImplementation), "AeroPoolImplementation");

        // Deploy pool factory
        aerodromePoolFactory = new PoolFactory(address(aeroPoolImplementation));
        vm.label(address(aerodromePoolFactory), "AerodromePoolFactory");

        // Deploy supporting factories
        aeroVotingRewardsFactory = new VotingRewardsFactory();
        vm.label(address(aeroVotingRewardsFactory), "AeroVotingRewardsFactory");

        aeroGaugeFactory = new GaugeFactory();
        vm.label(address(aeroGaugeFactory), "AeroGaugeFactory");

        aeroManagedRewardsFactory = new ManagedRewardsFactory();
        vm.label(address(aeroManagedRewardsFactory), "AeroManagedRewardsFactory");

        // Deploy factory registry
        aerodromeFactoryRegistry = new FactoryRegistry(
            address(aerodromePoolFactory),
            address(aeroVotingRewardsFactory),
            address(aeroGaugeFactory),
            address(aeroManagedRewardsFactory)
        );
        vm.label(address(aerodromeFactoryRegistry), "AerodromeFactoryRegistry");

        // Deploy router (note: voter is set to address(0) for testing)
        aerodromeRouter = new Router(
            address(aeroForwarder),
            address(aerodromeFactoryRegistry),
            address(aerodromePoolFactory),
            address(0), // voter
            address(weth)
        );
        vm.label(address(aerodromeRouter), "AerodromeRouter");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Vault Facet Deployment                         */
    /* ---------------------------------------------------------------------- */

    function _deployVaultFacets() internal virtual {
        erc20Facet = create3Factory.deployERC20Facet();
        erc2612Facet = create3Factory.deployERC2612Facet();
        erc5267Facet = create3Factory.deployERCC5267Facet();
        erc4626Facet = create3Factory.deployERC4626Facet();
        erc4626BasicVaultFacet = create3Factory.deployERC4626BasedBasicVaultFacet();
        erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();
        aerodromeStandardExchangeInFacet = create3Factory.deployAerodromeStandardExchangeInFacet();
        aerodromeStandardExchangeOutFacet = create3Factory.deployAerodromeStandardExchangeOutFacet();
    }

    /* ---------------------------------------------------------------------- */
    /*                      Aerodrome Vault Package Deployment                */
    /* ---------------------------------------------------------------------- */

    function _deployAerodromeVaultPackage() internal virtual {
        vm.startPrank(owner);
        aerodromeStandardExchangeDFPkg = indexedexManager.deployAerodromeStandardExchangeDFPkg(
            erc20Facet,
            erc2612Facet,
            erc5267Facet,
            erc4626Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            aerodromeStandardExchangeInFacet,
            aerodromeStandardExchangeOutFacet,
            indexedexManager, // vaultFeeOracleQuery
            indexedexManager, // vaultRegistryDeployment
            permit2,
            IRouter(address(aerodromeRouter)),
            aerodromePoolFactory
        );
        vm.stopPrank();
        vm.label(address(aerodromeStandardExchangeDFPkg), "AerodromeStandardExchangeDFPkg");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Aerodrome Pool Creation                           */
    /* ---------------------------------------------------------------------- */

    function _createAerodromeTestPool() internal virtual {
        // Create DAI/USDC pool on Aerodrome
        address poolAddr = aerodromePoolFactory.createPool(
            address(dai),
            address(usdc),
            false // not stable
        );
        aeroDaiUsdcPool = Pool(poolAddr);
        vm.label(address(aeroDaiUsdcPool), "AeroDaiUsdcPool");

        // Initialize pool with liquidity
        _initAerodromePool();
    }

    function _initAerodromePool() internal virtual {
        // Mint tokens to lp
        dai.mint(lp, AERODROME_POOL_INIT_AMOUNT);
        usdc.mint(lp, AERODROME_POOL_INIT_AMOUNT);

        vm.startPrank(lp);

        // Approve router
        dai.approve(address(aerodromeRouter), AERODROME_POOL_INIT_AMOUNT);
        usdc.approve(address(aerodromeRouter), AERODROME_POOL_INIT_AMOUNT);

        // Add liquidity
        aerodromeRouter.addLiquidity(
            address(dai),
            address(usdc),
            false, // not stable
            AERODROME_POOL_INIT_AMOUNT,
            AERODROME_POOL_INIT_AMOUNT,
            1, // min amount A
            1, // min amount B
            lp,
            block.timestamp + 1 hours
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Test Vault Deployment                          */
    /* ---------------------------------------------------------------------- */

    function _deployTestVault() internal virtual {
        // Deploy vault wrapping the Aerodrome DAI/USDC pool
        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(address(aeroDaiUsdcPool)));
        daiUsdcVault = IStandardExchangeProxy(vaultAddr);
        vm.label(vaultAddr, "DaiUsdcVault");

        // Approve vault for all users
        _approveVaultForAllUsers();
    }

    function _approveVaultForAllUsers() internal virtual {
        // Approve vault to spend LP tokens and underlying tokens
        for (uint256 i = 0; i < users.length; ++i) {
            address user = users[i];
            vm.startPrank(user);

            // Approve vault for LP tokens (the pool itself)
            OZIERC20(address(aeroDaiUsdcPool)).approve(address(daiUsdcVault), type(uint256).max);
            OZIERC20(address(aeroDaiUsdcPool)).approve(address(permit2), type(uint256).max);
            permit2.approve(address(aeroDaiUsdcPool), address(daiUsdcVault), type(uint160).max, type(uint48).max);
            permit2.approve(address(aeroDaiUsdcPool), address(seRouter), type(uint160).max, type(uint48).max);

            // Approve vault shares for router
            OZIERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
            permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

            vm.stopPrank();
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                        Vault Helper Functions                          */
    /* ---------------------------------------------------------------------- */

    function _depositToVault(address user, uint256 lpAmount) internal returns (uint256 shares) {
        // Mint LP tokens to user and deposit to vault
        dai.mint(user, lpAmount);
        usdc.mint(user, lpAmount);

        vm.startPrank(user);

        // Approve and add liquidity to Aerodrome pool
        dai.approve(address(aerodromeRouter), lpAmount);
        usdc.approve(address(aerodromeRouter), lpAmount);

        (,, uint256 liquidity) = aerodromeRouter.addLiquidity(
            address(dai), address(usdc), false, lpAmount, lpAmount, 1, 1, user, block.timestamp + 1 hours
        );

        // Approve vault to take LP tokens
        OZIERC20(address(aeroDaiUsdcPool)).approve(address(daiUsdcVault), liquidity);

        // Deposit LP tokens to vault
        shares = daiUsdcVault.deposit(liquidity, user);

        vm.stopPrank();
    }

    function _mintVaultShares(address user, uint256 shareAmount) internal returns (uint256 assets) {
        // First deposit enough to get the shares
        uint256 previewAssets = daiUsdcVault.previewMint(shareAmount);

        // Need to add some buffer for slippage
        uint256 lpToAdd = previewAssets * 11 / 10;

        // Mint LP tokens to user
        dai.mint(user, lpToAdd);
        usdc.mint(user, lpToAdd);

        vm.startPrank(user);

        // Approve and add liquidity
        dai.approve(address(aerodromeRouter), lpToAdd);
        usdc.approve(address(aerodromeRouter), lpToAdd);

        (,, uint256 liquidity) = aerodromeRouter.addLiquidity(
            address(dai), address(usdc), false, lpToAdd, lpToAdd, 1, 1, user, block.timestamp + 1 hours
        );

        // Approve vault
        OZIERC20(address(aeroDaiUsdcPool)).approve(address(daiUsdcVault), liquidity);

        // Mint exact shares
        assets = daiUsdcVault.mint(shareAmount, user);

        vm.stopPrank();
    }

    function _vaultAsset() internal view returns (OZIERC20) {
        return OZIERC20(address(aeroDaiUsdcPool));
    }

    function _vaultShares() internal view returns (OZIERC20) {
        return OZIERC20(address(daiUsdcVault));
    }
}
