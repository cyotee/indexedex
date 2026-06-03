// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TestBase_BalancerV3Vault
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3Vault.sol";

/* -------------------------------------------------------------------------- */
/*                                   Crane                                    */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {CastingHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/CastingHelpers.sol";
import {ArrayHelpers} from "contracts/test/balancer/v3/ArrayHelpers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Aerodrome                                 */
/* -------------------------------------------------------------------------- */

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
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IAerodromeStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";
import {
    Aerodrome_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";

/* Buffer Pool specific */
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {
    IStandardExchangeBufferPoolPkg,
    StandardExchangeBufferPoolStandardVaultPkg
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol";
import {
    StandardExchangeBufferPool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool_FactoryService.sol";
import {
    BalancerV3ConstantProductPool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";
import {DefaultPoolInfoFacet} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/DefaultPoolInfoFacet.sol";
import {StandardSwapFeePercentageBoundsFacet} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardSwapFeePercentageBoundsFacet.sol";
import {StandardUnbalancedLiquidityInvariantRatioBoundsFacet} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardUnbalancedLiquidityInvariantRatioBoundsFacet.sol";

/**
 * @title TestBase_StandardExchangeBufferPool
 * @notice Integration test base that wires a real Balancer V3 Vault mock, a Standard Exchange Vault
 *         (Aerodrome DAI/USDC), and a Standard Exchange Buffer Pool Diamond, ready for end-to-end tests.
 *
 * @dev Inheritance:
 *      - TestBase_BalancerV3Vault  — provides `vault` (VaultMock), `router` (RouterMock), `dai`, `usdc`,
 *                                    `alice`, `bob`, `lp`, `permit2`, `erc4626RateProviderDFPkg`
 *      - IndexedexTest             — provides `create3Factory`, `diamondPackageFactory`, `indexedexManager`
 *
 * After setUp():
 *   bv3Vault     — Balancer V3 VaultMock (IVault)
 *   seVault      — Aerodrome DAI/USDC Standard Exchange vault (IStandardExchangeProxy)
 *   tta          — DAI (the TTA side of the buffer pool, IERC20)
 *   ttb          — USDC (the other underlying of the SE vault, for reference)
 *   shares       — SE vault shares token (= IERC20(address(seVault)))
 *   rateProvider — ERC4626-based rate provider for the SE vault
 *   bufferPoolPkg — deployed StandardExchangeBufferPoolStandardVaultPkg
 *   pool         — deployed buffer pool address (registered with BV3 Vault, initialized)
 */
abstract contract TestBase_StandardExchangeBufferPool is TestBase_BalancerV3Vault, IndexedexTest {
    using BetterEfficientHashLib for bytes;
    using CastingHelpers for address[];
    using ArrayHelpers for *;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;
    using Aerodrome_Component_FactoryService for IIndexedexManagerProxy;
    using StandardExchangeBufferPool_FactoryService for ICreate3FactoryProxy;
    using StandardExchangeBufferPool_FactoryService for IVaultRegistryDeployment;
    using BalancerV3ConstantProductPool_FactoryService for ICreate3FactoryProxy;

    /* ---------------------------------------------------------------------- */
    /*                              Test Constants                             */
    /* ---------------------------------------------------------------------- */

    /// @dev Initial liquidity added to the Aerodrome pool.
    uint256 internal constant AERODROME_INIT_AMOUNT = 10_000e18;
    /// @dev Shares seeded into the buffer pool during initialize().
    uint256 internal constant INITIAL_SHARES_RAW = 1_000e18;

    /* ---------------------------------------------------------------------- */
    /*                          Public State (exposed to sub-tests)            */
    /* ---------------------------------------------------------------------- */

    IVault public bv3Vault;

    /// @notice Exposes the internally-declared `alice` address from BaseTest to behavior libraries.
    function getAlice() public view virtual returns (address) {
        return alice;
    }

    /// @notice Exposes the internally-declared `bob` address from BaseTest to behavior libraries and handlers.
    function getBob() public view virtual returns (address) {
        return bob;
    }

    // Aerodrome infrastructure
    Forwarder internal aeroForwarder;
    Pool internal aeroPoolImpl;
    PoolFactory internal aeroPoolFactory;
    FactoryRegistry internal aeroFactoryRegistry;
    VotingRewardsFactory internal aeroVotingRewardsFactory;
    GaugeFactory internal aeroGaugeFactory;
    ManagedRewardsFactory internal aeroManagedRewardsFactory;
    Router internal aeroRouter;
    Pool internal aeroDaiUsdcPool;

    // SE vault facets
    IFacet internal erc20Facet;
    IFacet internal erc5267Facet;
    IFacet internal erc2612Facet;
    IFacet internal erc4626Facet;
    IFacet internal erc4626BasicVaultFacet;
    IFacet internal erc4626StandardVaultFacet;
    IFacet internal aeroExchangeInFacet;
    IFacet internal aeroExchangeOutFacet;
    IAerodromeStandardExchangeDFPkg internal aeroStdExDFPkg;

    IStandardExchangeProxy public seVault;
    IERC20 public tta;
    IERC20 public ttb;
    IERC20 public shares;
    IRateProvider public seRateProvider;
    IStandardExchangeRateProviderDFPkg public seRateProviderPkg;

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

    IStandardExchangeBufferPoolPkg public bufferPoolPkg;
    address public bufferPool;

    /* ---------------------------------------------------------------------- */
    /*                                  setUp                                  */
    /* ---------------------------------------------------------------------- */

    function setUp()
        public
        virtual
        override(TestBase_BalancerV3Vault, IndexedexTest)
    {
        // 1. Deploy Balancer V3 Vault (also sets up permit2, CraneTest, etc.)
        _deployVault();

        // 2. Deploy Indexedex manager infrastructure (create3Factory already init'd above via CraneTest)
        IndexedexTest.setUp();

        // 3. Record the BV3 vault reference for convenience.
        bv3Vault = IVault(address(vault));

        // 4. Deploy the Standard Exchange Vault (default: Aerodrome DAI/USDC).
        _deploySEVault();

        // 5. Deploy the rate provider for the SE vault (ERC4626-based).
        _deployRateProvider();

        // 6. Deploy buffer pool facets, package, and the pool itself.
        _deployBufferPool();

        // 7. Initialize the pool with initial liquidity (alice provides seed shares).
        _initPool();

        // 8. Fund actors with tokens for test use.
        _fundActors();
    }

    /* ---------------------------------------------------------------------- */
    /*                        Virtual Deployment Hooks                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Deploys the Balancer V3 Vault and base test infrastructure.
     * @dev Subclasses that need to override the Vault type (e.g. a real on-chain fork)
     *      can override this hook.  The default calls the parent setUp() pair which
     *      deploy the Crane VaultMock and router.
     */
    function _deployVault() internal virtual {
        TestBase_BalancerV3Vault.setUp();
    }

    /**
     * @notice Deploys the Standard Exchange Vault used as the pool's underlying.
     * @dev The default implementation deploys an Aerodrome (volatile) DAI/USDC pool and wraps it
     *      in an Aerodrome Standard Exchange Vault.  Subclasses (e.g. a Uniswap V2-backed variant)
     *      override this hook to swap in a different SE vault without touching setUp().
     *      Implementations MUST populate `seVault`, `tta`, `ttb`, and `shares`.
     */
    function _deploySEVault() internal virtual {
        // Deploy Aerodrome infrastructure.
        _deployAerodromeInfrastructure();

        // Deploy SE vault facets and DFPkg, then the SE vault itself.
        _deploySeVaultFacets();
        _deploySeVaultPkg();
        _deploySeVault();

        // Seed liquidity into the Aerodrome pool so the SE vault has a non-zero rate.
        _seedAerodromeLiquidity();
    }

    /**
     * @notice Deploys (or recovers) the canonical rate provider for the SE vault via
     *         `StandardExchangeRateProviderDFPkg`.  The DFPkg is stored in `seRateProviderPkg`
     *         and the deployed rate provider instance in `seRateProvider`.
     * @dev Uses the same DFPkg the Buffer Pool Package calls internally (via its `RATE_PROVIDER_PKG`
     *      immutable), so `seRateProvider` and the pool's stored rate provider are guaranteed to be
     *      the same address (DPF idempotency).
     */
    function _deployRateProvider() internal virtual {
        // Deploy the rate provider facet.
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("StandardExchangeRateProviderFacet")
            )
        );
        vm.label(address(rateProviderFacet), "StandardExchangeRateProviderFacet");

        // Deploy the rate provider DFPkg.
        IStandardExchangeRateProviderDFPkg.PkgInit memory rpPkgInit = IStandardExchangeRateProviderDFPkg.PkgInit({
            rateProviderFacet: rateProviderFacet,
            diamondFactory: diamondPackageFactory
        });
        seRateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(rpPkgInit),
                    keccak256("StandardExchangeRateProviderDFPkg")
                )
            )
        );
        vm.label(address(seRateProviderPkg), "StandardExchangeRateProviderDFPkg");

        // Deploy (or idempotently recover) the canonical rate provider for this (seVault, tta) pair.
        seRateProvider = seRateProviderPkg.deployRateProvider(IStandardExchange(address(seVault)), tta);
        vm.label(address(seRateProvider), "StandardExchangeRateProvider");
    }

    /**
     * @notice Deploys the buffer pool facets, package, and the pool diamond itself.
     * @dev Registers the pool with the Balancer V3 Vault.  Subclasses can override to vary
     *      construction args (e.g. different facet sets, different DFPkg) but typically the
     *      default is sufficient.
     */
    function _deployBufferPool() internal virtual {
        _deployBufferPoolFacets();
        _deployBufferPoolPkg();

        bufferPool = bufferPoolPkg.deployPool(
            IStandardExchange(address(seVault)),
            tta
        );
        vm.label(bufferPool, "StandardExchangeBufferPool");
        approveForPool(IERC20(bufferPool));
    }

    /**
     * @notice Seeds actors with tokens after the pool is initialized.
     * @dev The default is a no-op because individual behavior libraries call mintTTA /
     *      mintShares as needed.  Subclasses can override to pre-fund actors for
     *      scenarios where every test in the file needs a common starting balance.
     */
    function _fundActors() internal virtual {
        // no-op by default
    }

    /* ---------------------------------------------------------------------- */
    /*                       Aerodrome Infrastructure                          */
    /* ---------------------------------------------------------------------- */

    function _deployAerodromeInfrastructure() internal virtual {
        aeroForwarder = new Forwarder();
        vm.label(address(aeroForwarder), "AeroForwarder");

        aeroPoolImpl = new Pool();
        vm.label(address(aeroPoolImpl), "AeroPoolImpl");

        aeroPoolFactory = new PoolFactory(address(aeroPoolImpl));
        vm.label(address(aeroPoolFactory), "AeroPoolFactory");

        aeroVotingRewardsFactory = new VotingRewardsFactory();
        aeroGaugeFactory = new GaugeFactory();
        aeroManagedRewardsFactory = new ManagedRewardsFactory();

        aeroFactoryRegistry = new FactoryRegistry(
            address(aeroPoolFactory),
            address(aeroVotingRewardsFactory),
            address(aeroGaugeFactory),
            address(aeroManagedRewardsFactory)
        );
        vm.label(address(aeroFactoryRegistry), "AeroFactoryRegistry");

        aeroRouter = new Router(
            address(aeroForwarder),
            address(aeroFactoryRegistry),
            address(aeroPoolFactory),
            address(0), // voter — unused in tests
            address(weth)
        );
        vm.label(address(aeroRouter), "AeroRouter");

        // Create the DAI/USDC volatile pool.
        address poolAddr = aeroPoolFactory.createPool(address(dai), address(usdc), false);
        aeroDaiUsdcPool = Pool(poolAddr);
        vm.label(address(aeroDaiUsdcPool), "AeroDaiUsdcPool");
    }

    /* ---------------------------------------------------------------------- */
    /*                            SE Vault Deployment                          */
    /* ---------------------------------------------------------------------- */

    function _deploySeVaultFacets() internal virtual {
        erc20Facet = create3Factory.deployERC20Facet();
        erc2612Facet = create3Factory.deployERC2612Facet();
        erc5267Facet = create3Factory.deployERCC5267Facet();
        erc4626Facet = create3Factory.deployERC4626Facet();
        erc4626BasicVaultFacet = create3Factory.deployERC4626BasedBasicVaultFacet();
        erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();
        aeroExchangeInFacet = create3Factory.deployAerodromeStandardExchangeInFacet();
        aeroExchangeOutFacet = create3Factory.deployAerodromeStandardExchangeOutFacet();
    }

    function _deploySeVaultPkg() internal virtual {
        vm.startPrank(owner);
        aeroStdExDFPkg = indexedexManager.deployAerodromeStandardExchangeDFPkg(
            erc20Facet,
            erc2612Facet,
            erc5267Facet,
            erc4626Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            aeroExchangeInFacet,
            aeroExchangeOutFacet,
            indexedexManager, // vaultFeeOracleQuery
            indexedexManager, // vaultRegistryDeployment
            permit2,
            IRouter(address(aeroRouter)),
            aeroPoolFactory
        );
        vm.stopPrank();
        vm.label(address(aeroStdExDFPkg), "AerodromeStdExDFPkg");
    }

    function _deploySeVault() internal virtual {
        address vaultAddr = aeroStdExDFPkg.deployVault(IPool(address(aeroDaiUsdcPool)));
        seVault = IStandardExchangeProxy(vaultAddr);
        vm.label(vaultAddr, "AeroDaiUsdcSeVault");

        // TTA is DAI (the TTA side of the buffer pool).
        // Shares is the SE vault itself (an ERC4626 whose asset is the Aerodrome LP token).
        tta = IERC20(address(dai));
        ttb = IERC20(address(usdc));
        shares = IERC20(vaultAddr);

        // Approve the SE vault and permit2 for all test users so the BV3 router can pull tokens.
        for (uint256 i = 0; i < users.length; ++i) {
            vm.startPrank(users[i]);
            // SE vault needs the LP token approved so it can pull on deposit.
            IERC20(address(aeroDaiUsdcPool)).approve(vaultAddr, type(uint256).max);
            // Permit2 needs to be approved to pull SE vault shares (for router.initialize).
            IERC20(vaultAddr).approve(address(permit2), type(uint256).max);
            permit2.approve(vaultAddr, address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         Aerodrome Pool Seeding                          */
    /* ---------------------------------------------------------------------- */

    function _seedAerodromeLiquidity() internal virtual {
        dai.mint(lp, AERODROME_INIT_AMOUNT);
        usdc.mint(lp, AERODROME_INIT_AMOUNT);

        vm.startPrank(lp);
        dai.approve(address(aeroRouter), AERODROME_INIT_AMOUNT);
        usdc.approve(address(aeroRouter), AERODROME_INIT_AMOUNT);
        aeroRouter.addLiquidity(
            address(dai),
            address(usdc),
            false,
            AERODROME_INIT_AMOUNT,
            AERODROME_INIT_AMOUNT,
            1,
            1,
            lp,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                      Buffer Pool Facet Deployment                       */
    /* ---------------------------------------------------------------------- */

    function _deployBufferPoolFacets() internal virtual {
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
        balancerV3VaultAwareFacet = create3Factory.deployBalancerV3VaultAwareFacet();
        betterBalancerV3PoolTokenFacet = create3Factory.deployBalancerV3PoolTokenFacet();
        balancerV3AuthenticationFacet = create3Factory.deployBalancerV3AuthenticationFacet();

        // These three facets are deployed directly (no FactoryService helper needed).
        defaultPoolInfoFacet = IFacet(address(new DefaultPoolInfoFacet()));
        vm.label(address(defaultPoolInfoFacet), "DefaultPoolInfoFacet");

        standardSwapFeePercentageBoundsFacet = IFacet(address(new StandardSwapFeePercentageBoundsFacet()));
        vm.label(address(standardSwapFeePercentageBoundsFacet), "StandardSwapFeePercentageBoundsFacet");

        unbalancedLiquidityInvariantRatioBoundsFacet =
            IFacet(address(new StandardUnbalancedLiquidityInvariantRatioBoundsFacet()));
        vm.label(
            address(unbalancedLiquidityInvariantRatioBoundsFacet), "StandardUnbalancedLiquidityInvariantRatioBoundsFacet"
        );

        bufferPoolFacet = create3Factory.deployBufferPoolFacet();
        poolLiquidityFacet = create3Factory.deployPoolLiquidityFacet();
        hookFacet = create3Factory.deployHookFacet();
    }

    /* ---------------------------------------------------------------------- */
    /*                      Buffer Pool Package Deployment                     */
    /* ---------------------------------------------------------------------- */

    function _deployBufferPoolPkg() internal virtual {
        // Construct PkgInit directly (avoids the stack-too-deep issue in buildBufferPoolPkgInit helper).
        IStandardExchangeBufferPoolPkg.PkgInit memory pkgInit;
        pkgInit.basicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.standardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.balancerV3VaultAwareFacet = balancerV3VaultAwareFacet;
        pkgInit.betterBalancerV3PoolTokenFacet = betterBalancerV3PoolTokenFacet;
        pkgInit.defaultPoolInfoFacet = defaultPoolInfoFacet;
        pkgInit.standardSwapFeePercentageBoundsFacet = standardSwapFeePercentageBoundsFacet;
        pkgInit.unbalancedLiquidityInvariantRatioBoundsFacet = unbalancedLiquidityInvariantRatioBoundsFacet;
        pkgInit.balancerV3AuthenticationFacet = balancerV3AuthenticationFacet;
        pkgInit.bufferPoolFacet = bufferPoolFacet;
        pkgInit.poolLiquidityFacet = poolLiquidityFacet;
        pkgInit.hookFacet = hookFacet;
        pkgInit.vaultRegistry = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.balancerV3Vault = bv3Vault;
        pkgInit.diamondFactory = diamondPackageFactory;
        pkgInit.rateProviderPkg = seRateProviderPkg;

        vm.startPrank(owner);
        bufferPoolPkg = StandardExchangeBufferPool_FactoryService.deployBufferPoolPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            pkgInit
        );
        vm.stopPrank();
        vm.label(address(bufferPoolPkg), "StandardExchangeBufferPoolPkg");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Swap Helpers                                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mint `amount` TTA (DAI) to `recipient`.
     * @dev Behaviors that need to top-up a user's TTA balance call this rather than
     *      casting through the IERC20 interface (which lacks a `mint` selector).
     */
    function mintTTA(address recipient, uint256 amount) public {
        dai.mint(recipient, amount);
    }

    /**
     * @notice Mint SE vault shares for `recipient` by going through the full Aerodrome → SE vault path.
     * @dev Mints `daiAmount` DAI and an equal amount of USDC to `recipient`, adds liquidity to the
     *      Aerodrome DAI/USDC pool, then deposits the resulting LP tokens into the SE vault.
     *      The shares received are owned by `recipient`.  Permit2 approvals for the shares token
     *      are already set for all users during setUp via _deploySeVault.
     * @param recipient  Address that will receive SE vault shares.
     * @param daiAmount  Amount of DAI (and USDC) to use for Aerodrome liquidity.
     * @return sharesOut Number of SE vault shares minted to `recipient`.
     */
    function mintShares(address recipient, uint256 daiAmount) public returns (uint256 sharesOut) {
        dai.mint(recipient, daiAmount);
        usdc.mint(recipient, daiAmount);

        vm.startPrank(recipient);
        dai.approve(address(aeroRouter), daiAmount);
        usdc.approve(address(aeroRouter), daiAmount);
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            address(dai),
            address(usdc),
            false,
            daiAmount,
            daiAmount,
            1,
            1,
            recipient,
            block.timestamp + 1 hours
        );
        IERC20(address(aeroDaiUsdcPool)).approve(address(seVault), lpOut);
        sharesOut = seVault.deposit(lpOut, recipient);
        vm.stopPrank();
    }

    /**
     * @notice Execute an EXACT_IN TTA→shares swap through the Balancer V3 RouterMock.
     * @dev Uses permit2 (already approved for all users during setUp via _approveForAllUsers).
     *      Caller must hold at least `amountIn` TTA (DAI). The router pulls via permit2.
     * @param user   Address performing the swap (pranked inside this call).
     * @param amountIn  Exact TTA amount to swap in (18-decimal raw units).
     * @return amountOut Shares received by `user`.
     */
    function swapTTAforShares(address user, uint256 amountIn) public returns (uint256 amountOut) {
        amountOut = _doSwapExactIn(user, tta, shares, amountIn);
    }

    /**
     * @notice Execute an EXACT_IN shares→TTA swap through the Balancer V3 RouterMock.
     * @dev Uses permit2 (already approved for all users during setUp via _approveForAllUsers).
     *      Caller must hold at least `amountIn` SE vault shares. The router pulls via permit2.
     *      The permit2 approval for the SE vault share token (seVault address) was set during
     *      setUp() in _deploySeVault().
     * @param user     Address performing the swap (pranked inside this call).
     * @param amountIn Exact shares amount to swap in (raw units, same decimals as SE vault).
     * @return amountOut TTA received by `user`.
     */
    function swapSharesForTTA(address user, uint256 amountIn) public returns (uint256 amountOut) {
        amountOut = _doSwapExactIn(user, shares, tta, amountIn);
    }

    /**
     * @dev Internal helper that executes an EXACT_IN single-token swap through the BV3 RouterMock.
     *      Both token directions share this implementation to stay DRY.
     *
     * @param user      Address performing the swap (will be pranked).
     * @param tokenIn   Token the user sells.
     * @param tokenOut  Token the user receives.
     * @param amountIn  Exact amount of tokenIn to swap.
     * @return amountOut Amount of tokenOut received.
     */
    function _doSwapExactIn(
        address user,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        vm.startPrank(user);
        amountOut = router.swapSingleTokenExactIn(
            bufferPool,
            tokenIn,
            tokenOut,
            amountIn,
            0,               // minAmountOut — no slippage guard in tests
            block.timestamp, // deadline
            false,           // wethIsEth
            bytes("")        // userData
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                       LP Add / Remove Helpers                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Execute an addLiquidityUnbalanced through the Balancer V3 RouterMock.
     * @dev The router pulls exact token amounts from `user` via permit2. All users have
     *      permit2 approvals for TTA and shares set during setUp. `user` must hold at least
     *      `ttaIn` TTA and `sharesIn` shares before calling.
     *
     * @param user      Address performing the operation (pranked inside this call).
     * @param ttaIn     Exact TTA amount to contribute. Pass 0 to skip TTA contribution.
     * @param sharesIn  Exact shares amount to contribute. Pass 0 to skip shares contribution.
     * @return bptOut   BPT minted to `user`.
     */
    function addLiquidityUnbalanced(
        address user,
        uint256 ttaIn,
        uint256 sharesIn
    ) public returns (uint256 bptOut) {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        uint256 ttaIdx    = p.ttaIndex();
        uint256 sharesIdx = p.sharesIndex();

        uint256[] memory exactAmountsIn = new uint256[](2);
        exactAmountsIn[ttaIdx]    = ttaIn;
        exactAmountsIn[sharesIdx] = sharesIn;

        vm.startPrank(user);
        bptOut = router.addLiquidityUnbalanced(bufferPool, exactAmountsIn, 0, false, bytes(""));
        vm.stopPrank();
    }

    /**
     * @notice Execute a DONATION add-liquidity through the Balancer V3 RouterMock.
     * @dev DONATION mints 0 BPT; it grows the pool's actual reserves (benefiting LPs) without
     *      changing virtualTTA / hookSharesDelta / BPT supply. The caller must hold `amountsIn[i]`
     *      for each token and have permit2 approved for the router (set in setUp for all users).
     *
     * @param user      Address performing the donation (pranked inside this call).
     * @param ttaAmount TTA (DAI) amount to donate. Pass 0 to donate shares only.
     * @param sharesAmount Shares amount to donate. Pass 0 to donate TTA only.
     */
    function donateLiquidity(
        address user,
        uint256 ttaAmount,
        uint256 sharesAmount
    ) public {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        uint256 ttaIdx    = p.ttaIndex();
        uint256 sharesIdx = p.sharesIndex();

        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[ttaIdx]    = ttaAmount;
        amountsIn[sharesIdx] = sharesAmount;

        vm.startPrank(user);
        router.donate(bufferPool, amountsIn, false, bytes(""));
        vm.stopPrank();
    }

    /**
     * @notice Execute an addLiquidityProportional through the Balancer V3 RouterMock.
     * @dev The BV3 Router pulls tokens via permit2 (approved for all users during setUp).
     *      Passing maxTta == 0 triggers the shares-only path in onBeforeAddLiquidity,
     *      which is a no-op that lets onAfterAddLiquidity do the proportional scaling.
     *      Passing nonzero maxTta triggers TTA→shares conversion in onBeforeAddLiquidity.
     *
     * @param user     Address performing the operation (pranked inside this call).
     * @param bptOut   Exact BPT amount to mint.
     * @param maxTta   Maximum TTA the user is willing to contribute. Pass 0 for shares-only.
     * @param maxSharesAmt Maximum shares the user is willing to contribute.
     * @return amountsIn Token amounts actually consumed (indexed by pool token order).
     */
    function addLiquidityProportional(
        address user,
        uint256 bptOut,
        uint256 maxTta,
        uint256 maxSharesAmt
    ) public returns (uint256[] memory amountsIn) {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        uint256 ttaIdx    = p.ttaIndex();
        uint256 sharesIdx = p.sharesIndex();

        uint256[] memory maxAmts = new uint256[](2);
        maxAmts[ttaIdx]    = maxTta;
        maxAmts[sharesIdx] = maxSharesAmt;

        vm.startPrank(user);
        amountsIn = router.addLiquidityProportional(bufferPool, maxAmts, bptOut, false, bytes(""));
        vm.stopPrank();
    }

    /**
     * @notice Execute a removeLiquidityProportional through the Balancer V3 RouterMock.
     * @dev The BV3 Router burns BPT from `user` (permit2 approved for all users during setUp).
     *
     * @param user       Address performing the operation (pranked inside this call).
     * @param bptIn      Exact BPT amount to burn.
     * @param minTta     Minimum TTA the user is willing to accept (use 0 for tests).
     * @param minSharesAmt Minimum shares the user is willing to accept (use 0 for tests).
     * @return amountsOut Token amounts received (indexed by pool token order).
     */
    function removeLiquidityProportional(
        address user,
        uint256 bptIn,
        uint256 minTta,
        uint256 minSharesAmt
    ) public returns (uint256[] memory amountsOut) {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        uint256 ttaIdx    = p.ttaIndex();
        uint256 sharesIdx = p.sharesIndex();

        uint256[] memory minAmts = new uint256[](2);
        minAmts[ttaIdx]    = minTta;
        minAmts[sharesIdx] = minSharesAmt;

        vm.startPrank(user);
        amountsOut = router.removeLiquidityProportional(bufferPool, bptIn, minAmts, false, bytes(""));
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                           Pool Initialization                           */
    /* ---------------------------------------------------------------------- */

    function _initPool() internal virtual {
        // Alice acquires SE vault shares by depositing Aerodrome LP tokens into the SE vault.
        // Step 1: Mint DAI + USDC to alice and add liquidity to the Aerodrome pool.
        dai.mint(alice, INITIAL_SHARES_RAW * 2);
        usdc.mint(alice, INITIAL_SHARES_RAW * 2);

        vm.startPrank(alice);
        dai.approve(address(aeroRouter), INITIAL_SHARES_RAW * 2);
        usdc.approve(address(aeroRouter), INITIAL_SHARES_RAW * 2);
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            address(dai),
            address(usdc),
            false,
            INITIAL_SHARES_RAW * 2,
            INITIAL_SHARES_RAW * 2,
            1,
            1,
            alice,
            block.timestamp + 1 hours
        );

        // Step 2: Deposit LP tokens into SE vault to receive SE vault shares.
        IERC20(address(aeroDaiUsdcPool)).approve(address(seVault), lpOut);
        uint256 seSharesOut = seVault.deposit(lpOut, alice);

        // Step 3: Mint TTA (dai) to alice for the TTA side of the buffer pool initialization.
        // The buffer pool is initialized proportionally (tta_amount and shares_amount).
        // We use the SE shares received as the shares side; TTA side is set equal to simulate 1:1.
        dai.mint(alice, seSharesOut);

        // Step 4: Approve the BV3 Vault (via router) for both tokens.
        IERC20(address(dai)).approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);

        // Step 5: Initialize the buffer pool via the BV3 RouterMock.
        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(bufferPool);
        uint256[] memory amounts = new uint256[](2);
        // Provide equal amounts proportionally.
        amounts[0] = seSharesOut;
        amounts[1] = seSharesOut;

        router.initialize(bufferPool, poolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }
}
