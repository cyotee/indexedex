// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TokenConfig,
    TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {
    TestBase_BalancerV3Vault
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3Vault.sol";

/* -------------------------------------------------------------------------- */
/*                                   Crane                                    */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {UniV2Factory} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Factory.sol";
import {UniV2Router02} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Router02.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IUniswapV2StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {
    UniswapV2_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol";
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
import {
    IBalancerV3ConstantProductPoolStandardVaultPkg
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";
import {
    BalancerV3ConstantProductPool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";
import {DefaultPoolInfoFacet} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/DefaultPoolInfoFacet.sol";
import {StandardSwapFeePercentageBoundsFacet} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardSwapFeePercentageBoundsFacet.sol";
import {StandardUnbalancedLiquidityInvariantRatioBoundsFacet} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardUnbalancedLiquidityInvariantRatioBoundsFacet.sol";
import {
    ResearchTelemetry
} from "scripts/foundry/research/harness/ResearchTelemetry.sol";

/**
 * @title ResearchFixture_UniswapV2SeRateMatrix
 * @notice Shared research environment (not a Foundry test):
 *         Uni V2 WETH/USDC SE vault + four Balancer CP pools (rate × pair matrix).
 *
 * @dev Initial Uni V2 spot: 1 WETH : 1000 USDC ($1000 / WETH).
 *      Mode A: trade Uni V2 only; sample all five markets.
 *      Mode C: see ResearchFixture_ModeC + ResearchModeCCloser (separate stack).
 *      USDC is the hermetic 18-decimal test token (amounts use 1e18 = 1 USDC).
 */
contract ResearchFixture_UniswapV2SeRateMatrix is TestBase_BalancerV3Vault, IndexedexTest {
    using BetterEfficientHashLib for bytes;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using UniswapV2_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV2_Component_FactoryService for IIndexedexManagerProxy;
    using BalancerV3ConstantProductPool_FactoryService for ICreate3FactoryProxy;
    using BalancerV3ConstantProductPool_FactoryService for IVaultRegistryDeployment;

    /// @dev Seed WETH reserves (18-dec). USDC seed = WETH_SEED * PRICE_USDC_PER_WETH.
    uint256 internal constant WETH_SEED = 10_000e18;
    /// @dev $1000 per WETH → 1000 USDC per 1 WETH (18-dec USDC test token).
    uint256 internal constant PRICE_USDC_PER_WETH = 1000;
    uint256 internal constant USDC_SEED = WETH_SEED * PRICE_USDC_PER_WETH;

    uint256 internal constant MATRIX_N = 4;

    /// @dev Baseline trade sizes (Mode A single-token runs). Sized for visible maker-fee P&L
    ///      on half of a 10k WETH / 10M USDC pool. rateProviderCompare may scale via virtual getters.
    uint256 public constant TRADE_WETH = 1e18; // 1 WETH
    uint256 public constant TRADE_USDC = 1000e18; // 1000 USDC (18-dec)
    uint256 public constant TRADE_STEPS = 24;

    /// @dev Effective per-step sizes (override in high-vol compare fixtures).
    function tradeWethWei() public view virtual returns (uint256) {
        return TRADE_WETH;
    }

    function tradeUsdcWei() public view virtual returns (uint256) {
        return TRADE_USDC;
    }

    function tradeSteps() public view virtual returns (uint256) {
        return TRADE_STEPS;
    }

    IVault public bv3Vault;

    IUniswapV2Factory internal uniV2Factory;
    IUniswapV2Router internal uniV2Router;
    IUniswapV2Pair public uniV2Pair;
    IUniswapV2StandardExchangeDFPkg internal uniV2StdExDFPkg;

    IStandardExchangeProxy public seVault;
    IERC20 public tokenWeth;
    IERC20 public tokenUsdc;
    IERC20 public shares;

    IFacet internal erc20Facet;
    IFacet internal erc5267Facet;
    IFacet internal erc2612Facet;
    IFacet internal erc4626Facet;
    IFacet internal multiAssetBasicVaultFacet;
    IFacet internal multiAssetStandardVaultFacet;

    IStandardExchangeRateProviderDFPkg internal seRateProviderPkg;
    IRateProvider public rateProviderWeth;
    IRateProvider public rateProviderUsdc;

    IFacet internal balancerV3VaultAwareFacet;
    IFacet internal betterBalancerV3PoolTokenFacet;
    IFacet internal defaultPoolInfoFacet;
    IFacet internal standardSwapFeePercentageBoundsFacet;
    IFacet internal unbalancedLiquidityInvariantRatioBoundsFacet;
    IFacet internal balancerV3AuthenticationFacet;
    IFacet internal balancerV3ConstProdPoolFacet;
    IBalancerV3ConstantProductPoolStandardVaultPkg public constProdPkg;

    address[MATRIX_N] public matrixPools;
    string[MATRIX_N] public matrixLabels;
    IERC20[MATRIX_N] public matrixPairToken;
    IRateProvider[MATRIX_N] public matrixRateProvider;
    IERC20[MATRIX_N] public matrixRateTarget;

    uint256 public sharesPerPool;
    /// @dev Uni LP held outside the vault after bootstrap (at least half of supply).
    uint256 public freeLpOutsideVault;
    /// @dev Uni LP deposited into the SE vault at bootstrap (half of supply).
    uint256 public vaultLpDeposited;

    /// @dev Uni USDC-per-WETH at t0 (also seed check ~1000e18).
    uint256 public initUniSpotUsdcPerWeth;
    /// @dev Balancer raw mid (pair/liveShares) at t0 per matrix pool.
    uint256[MATRIX_N] public initBalancerMid;
    uint256 public initRateWeth;
    uint256 public initRateUsdc;

    /// @dev True if the external trader's tokenIn is WETH (they sell WETH into Uni).
    ///      LP framing: market is then buying USDC from our liquidity.
    ///      False ⇒ trader sells USDC ⇒ market is buying WETH from our liquidity.
    bool public tradedIsWeth;
    bool public telemetryReady;

    /// @dev Portfolio mark at t0 via full exit, valued in USDC.
    uint256 public portfolio0Usdc;
    /// @dev Token claim from t0 full exit (before converting to USDC) — held fixed for price P&L.
    uint256 public claim0Weth;
    uint256 public claim0Usdc;

    ResearchTelemetry.RunPaths internal runPaths;
    uint256 public step;

    /// @dev Last Mode C arb step stats (0 when Mode A).
    uint256 public stepArbProfit;
    uint256 public stepArbFills;
    uint256 public cumulativeArbProfit;
    /// @dev Mode C probe diagnostics (max edge seen, even if not filled).
    uint256 public stepMaxBuyProbe;
    uint256 public stepMaxSellProbe;
    uint256 public stepPositiveProbes;
    /// @dev 0 = A_uni_only, 1 = C_uni_plus_bal_arb
    uint8 public researchModeId;

    /**
     * @notice Build the hermetic research environment.
     * @dev Not named `setUp` so forge-script does not auto-invoke it on ephemeral script
     *      contracts (which reject `address(this)`). Call from a *deployed* fixture instance.
     */
    function bootstrapResearch() public virtual {
        TestBase_BalancerV3Vault.setUp();
        IndexedexTest.setUp();
        bv3Vault = IVault(address(vault));

        tokenWeth = IERC20(address(weth));
        tokenUsdc = IERC20(address(usdc));
        researchModeId = 0;

        _deployUniV2AndSeVault();
        _deployRateProviders();
        _deployConstProdPkg();
        _deployMatrixPools();
        _bootstrapSharesAndInitPools();
        _recordInitialSpots();
    }

    function setResearchModeId(uint8 modeId_) external {
        researchModeId = modeId_;
    }

    /// @dev Silence Foundry auto-setUp on Test inheritance when this fixture is also a Script child.
    function setUp() public virtual override(TestBase_BalancerV3Vault, IndexedexTest) {
        // intentionally empty — use bootstrapResearch() on a deployed instance
    }

    /* ---------------------------------------------------------------------- */
    /*                         Deploy: Uni V2 WETH/USDC + SE                   */
    /* ---------------------------------------------------------------------- */

    function _deployUniV2AndSeVault() internal {
        address feeToSetter = makeAddr("uniV2FeeToSetter");
        uniV2Factory = IUniswapV2Factory(new UniV2Factory(feeToSetter));
        uniV2Router = IUniswapV2Router(new UniV2Router02(address(uniV2Factory), address(weth)));
        address pairAddr = uniV2Factory.createPair(address(tokenWeth), address(tokenUsdc));
        uniV2Pair = IUniswapV2Pair(pairAddr);
        vm.label(pairAddr, "UniV2_WETH_USDC");

        // Seed 1 WETH : 1000 USDC without skew.
        _fundWeth(lp, WETH_SEED);
        usdc.mint(lp, USDC_SEED);
        vm.startPrank(lp);
        tokenWeth.approve(address(uniV2Router), WETH_SEED);
        tokenUsdc.approve(address(uniV2Router), USDC_SEED);
        uniV2Router.addLiquidity(
            address(tokenWeth),
            address(tokenUsdc),
            WETH_SEED,
            USDC_SEED,
            1,
            1,
            lp,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        erc20Facet = create3Factory.deployERC20Facet();
        erc5267Facet = create3Factory.deployERC5267Facet();
        erc2612Facet = create3Factory.deployERC2612Facet();
        erc4626Facet = create3Factory.deployERC4626Facet();
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();

        IFacet v2In = create3Factory.deployUniswapV2StandardExchangeInFacet();
        IFacet v2Out = create3Factory.deployUniswapV2StandardExchangeOutFacet();

        IUniswapV2StandardExchangeDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc4626Facet = erc4626Facet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.uniswapV2StandardExchangeInFacet = v2In;
        pkgInit.uniswapV2StandardExchangeOutFacet = v2Out;
        pkgInit.vaultFeeOracleQuery = indexedexManager;
        pkgInit.vaultRegistryDeployment = indexedexManager;
        pkgInit.permit2 = permit2;
        pkgInit.uniswapV2Factory = uniV2Factory;
        pkgInit.uniswapV2Router = uniV2Router;

        vm.startPrank(owner);
        uniV2StdExDFPkg =
            UniswapV2_Component_FactoryService.deployUniswapV2StandardExchangeDFPkg(indexedexManager, pkgInit);
        vm.stopPrank();

        address vaultAddr = uniV2StdExDFPkg.deployVault(uniV2Pair);
        seVault = IStandardExchangeProxy(vaultAddr);
        shares = IERC20(vaultAddr);
        vm.label(vaultAddr, "UniV2SeVault_WethUsdc");

        for (uint256 i = 0; i < users.length; ++i) {
            vm.startPrank(users[i]);
            IERC20(pairAddr).approve(vaultAddr, type(uint256).max);
            IERC20(vaultAddr).approve(address(permit2), type(uint256).max);
            permit2.approve(vaultAddr, address(router), type(uint160).max, type(uint48).max);
            tokenWeth.approve(address(permit2), type(uint256).max);
            tokenUsdc.approve(address(permit2), type(uint256).max);
            permit2.approve(address(tokenWeth), address(router), type(uint160).max, type(uint48).max);
            permit2.approve(address(tokenUsdc), address(router), type(uint160).max, type(uint48).max);
            tokenWeth.approve(address(uniV2Router), type(uint256).max);
            tokenUsdc.approve(address(uniV2Router), type(uint256).max);
            vm.stopPrank();
        }
    }

    function _fundWeth(address to, uint256 amount) internal {
        vm.deal(to, amount);
        vm.prank(to);
        IWETH(address(weth)).deposit{value: amount}();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Rate providers                             */
    /* ---------------------------------------------------------------------- */

    function _deployRateProviders() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("Research_StandardExchangeRateProviderFacet_WethUsdc")
            )
        );
        IStandardExchangeRateProviderDFPkg.PkgInit memory rpInit = IStandardExchangeRateProviderDFPkg.PkgInit({
            rateProviderFacet: rateProviderFacet,
            diamondFactory: diamondPackageFactory
        });
        seRateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(rpInit),
                    keccak256("Research_StandardExchangeRateProviderDFPkg_WethUsdc")
                )
            )
        );

        rateProviderWeth = seRateProviderPkg.deployRateProvider(IStandardExchange(address(seVault)), tokenWeth);
        rateProviderUsdc = seRateProviderPkg.deployRateProvider(IStandardExchange(address(seVault)), tokenUsdc);
        vm.label(address(rateProviderWeth), "RateProvider_WETH");
        vm.label(address(rateProviderUsdc), "RateProvider_USDC");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Const-prod pkg + pools                        */
    /* ---------------------------------------------------------------------- */

    function _deployConstProdPkg() internal {
        balancerV3VaultAwareFacet = create3Factory.deployBalancerV3VaultAwareFacet();
        betterBalancerV3PoolTokenFacet = create3Factory.deployBalancerV3PoolTokenFacet();
        balancerV3AuthenticationFacet = create3Factory.deployBalancerV3AuthenticationFacet();
        balancerV3ConstProdPoolFacet =
            BalancerV3ConstantProductPool_FactoryService.deployBalancerV3ConstantProductPoolFacet(create3Factory);

        defaultPoolInfoFacet = IFacet(address(new DefaultPoolInfoFacet()));
        standardSwapFeePercentageBoundsFacet = IFacet(address(new StandardSwapFeePercentageBoundsFacet()));
        unbalancedLiquidityInvariantRatioBoundsFacet =
            IFacet(address(new StandardUnbalancedLiquidityInvariantRatioBoundsFacet()));

        IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit memory pkgInit;
        pkgInit.basicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.standardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.balancerV3VaultAwareFacet = balancerV3VaultAwareFacet;
        pkgInit.betterBalancerV3PoolTokenFacet = betterBalancerV3PoolTokenFacet;
        pkgInit.defaultPoolInfoFacet = defaultPoolInfoFacet;
        pkgInit.standardSwapFeePercentageBoundsFacet = standardSwapFeePercentageBoundsFacet;
        pkgInit.unbalancedLiquidityInvariantRatioBoundsFacet = unbalancedLiquidityInvariantRatioBoundsFacet;
        pkgInit.balancerV3AuthenticationFacet = balancerV3AuthenticationFacet;
        pkgInit.balancerV3ConstProdPoolFacet = balancerV3ConstProdPoolFacet;
        pkgInit.vaultRegistry = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.balancerV3Vault = bv3Vault;
        pkgInit.diamondFactory = diamondPackageFactory;

        vm.startPrank(owner);
        constProdPkg = BalancerV3ConstantProductPool_FactoryService
            .deployBalancerV3ConstantProductPoolStandardVaultPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(constProdPkg), "Research_ConstProdPkg");
    }

    /// @dev Virtual so rateProviderCompare R− can dedupe CREATE3 salts (STANDARD share legs
    ///      collapse rateWeth/rateUsdc variants that share the same pair token).
    function _deployMatrixPools() internal virtual {
        // 0: rate WETH, pair USDC (cross)
        matrixLabels[0] = "rateWeth_pairUsdc_cross";
        matrixPairToken[0] = tokenUsdc;
        matrixRateTarget[0] = tokenWeth;
        matrixRateProvider[0] = rateProviderWeth;

        // 1: rate WETH, pair WETH (same)
        matrixLabels[1] = "rateWeth_pairWeth_same";
        matrixPairToken[1] = tokenWeth;
        matrixRateTarget[1] = tokenWeth;
        matrixRateProvider[1] = rateProviderWeth;

        // 2: rate USDC, pair WETH (cross)
        matrixLabels[2] = "rateUsdc_pairWeth_cross";
        matrixPairToken[2] = tokenWeth;
        matrixRateTarget[2] = tokenUsdc;
        matrixRateProvider[2] = rateProviderUsdc;

        // 3: rate USDC, pair USDC (same)
        matrixLabels[3] = "rateUsdc_pairUsdc_same";
        matrixPairToken[3] = tokenUsdc;
        matrixRateTarget[3] = tokenUsdc;
        matrixRateProvider[3] = rateProviderUsdc;

        for (uint256 i = 0; i < MATRIX_N; ++i) {
            TokenConfig[] memory tc = _tokenConfigs(matrixPairToken[i], matrixRateProvider[i]);
            matrixPools[i] = constProdPkg.deployVault(tc, address(0));
            vm.label(matrixPools[i], matrixLabels[i]);
            approveForPool(IERC20(matrixPools[i]));
        }
    }

    /// @dev Virtual so rateProviderCompare can force STANDARD share legs (R− pure world).
    function _tokenConfigs(IERC20 pairToken_, IRateProvider rateProvider_)
        internal
        view
        virtual
        returns (TokenConfig[] memory tc)
    {
        tc = new TokenConfig[](2);
        (uint256 pairIdx, uint256 sharesIdx) =
            address(pairToken_) < address(shares) ? (uint256(0), uint256(1)) : (uint256(1), uint256(0));
        tc[pairIdx] = TokenConfig({
            token: pairToken_,
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        tc[sharesIdx] = TokenConfig({
            token: shares,
            tokenType: TokenType.WITH_RATE,
            rateProvider: rateProvider_,
            paysYieldFees: false
        });
    }

    /* ---------------------------------------------------------------------- */
    /*                    Bootstrap: half LP → shares → equal inits            */
    /* ---------------------------------------------------------------------- */

    /// @dev Virtual so rateProviderCompare R− can init each unique physical pool once
    ///      (CREATE3 salt collapses when share legs are STANDARD without rate providers).
    function _bootstrapSharesAndInitPools() internal virtual {
        // Deposit only half of Uni LP into the SE vault so the other half remains free
        // for settlement liquidity when vault shares are redeemed later.
        uint256 totalLp = uniV2Pair.totalSupply();
        // Pair mints MINIMUM_LIQUIDITY (1000) to address(0); lp holds the rest.
        uint256 lpHeldByLp = uniV2Pair.balanceOf(lp);
        require(lpHeldByLp >= 2, "research: insufficient LP");
        vaultLpDeposited = lpHeldByLp / 2;
        freeLpOutsideVault = lpHeldByLp - vaultLpDeposited;

        vm.prank(lp);
        uniV2Pair.transfer(alice, vaultLpDeposited);

        vm.startPrank(alice);
        uniV2Pair.approve(address(seVault), vaultLpDeposited);
        uint256 sharesOut = seVault.deposit(vaultLpDeposited, alice);
        vm.stopPrank();

        require(sharesOut >= MATRIX_N, "research: too few shares");
        sharesPerPool = sharesOut / MATRIX_N;
        require(sharesPerPool > 0, "research: sharesPerPool=0");
        require(uniV2Pair.balanceOf(lp) == freeLpOutsideVault, "research: free LP mismatch");
        require(totalLp == uniV2Pair.totalSupply(), "research: LP supply changed");

        for (uint256 i = 0; i < MATRIX_N; ++i) {
            uint256 pairAmt = _pairAmountForInit(i, sharesPerPool);
            _initMatrixPool(i, sharesPerPool, pairAmt);
        }
    }

    /// @dev Virtual so R− fair-init can size without wiring rate on the pool.
    function _pairAmountForInit(uint256 idx, uint256 rawShares_)
        internal
        view
        virtual
        returns (uint256 pairAmt)
    {
        uint256 rate = matrixRateProvider[idx].getRate();
        require(rate > 0, "research: rate=0 before init");
        uint256 liveShares = rawShares_ * rate / 1e18;
        require(liveShares > 0, "research: liveShares=0");

        IERC20 pair = matrixPairToken[idx];
        IERC20 rateTarget = matrixRateTarget[idx];

        if (address(pair) == address(rateTarget)) {
            return liveShares;
        }

        (uint256 reservePair, uint256 reserveRateTarget) = _uniReservesOf(pair, rateTarget);
        require(reserveRateTarget > 0, "research: zero uni reserve");
        pairAmt = liveShares * reservePair / reserveRateTarget;
        require(pairAmt > 0, "research: pairAmt=0");
    }

    function _initMatrixPool(uint256 idx, uint256 rawShares_, uint256 pairAmt_) internal {
        address pool = matrixPools[idx];
        IERC20 pair = matrixPairToken[idx];

        if (address(pair) == address(tokenWeth)) {
            _fundWeth(alice, pairAmt_);
        } else {
            usdc.mint(alice, pairAmt_);
        }

        (uint256 pairIdx, uint256 sharesIdx) = _poolIndices(pool, pair);
        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(pool);
        uint256[] memory amounts = new uint256[](2);
        amounts[pairIdx] = pairAmt_;
        amounts[sharesIdx] = rawShares_;

        vm.startPrank(alice);
        pair.approve(address(router), type(uint256).max);
        shares.approve(address(router), type(uint256).max);
        router.initialize(pool, poolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    function _recordInitialSpots() internal {
        initUniSpotUsdcPerWeth = uniSpotUsdcPerWeth();
        require(initUniSpotUsdcPerWeth > 0, "research: zero uni spot");
        require(
            initUniSpotUsdcPerWeth > 999e18 && initUniSpotUsdcPerWeth < 1001e18,
            "research: uni spot not ~1000 USDC/WETH"
        );
        // Per-run price-of-traded baselines are captured in initTelemetry once tradedIsWeth is set.
    }

    /* ---------------------------------------------------------------------- */
    /*                              Price readers                              */
    /* ---------------------------------------------------------------------- */

    /// @notice Uni V2 spot: USDC per WETH (1e18). Fixed convention for both trade runs.
    function uniSpotUsdcPerWeth() public view returns (uint256) {
        (uint256 rW, uint256 rU) = _uniReservesOf(tokenWeth, tokenUsdc);
        require(rW > 0, "research: uni rW=0");
        return rU * 1e18 / rW;
    }

    /// @notice Balancer mid: live_pair / live_shares (1e18). Mode A: raw balances fixed;
    ///         live shares track getRate(), so mid_t/mid_0 = rate_0/rate_t for that pool's rating.
    function balancerMidRaw(uint256 idx) public view returns (uint256) {
        address pool = matrixPools[idx];
        IERC20 pair = matrixPairToken[idx];
        (uint256 pairIdx, uint256 sharesIdx) = _poolIndices(pool, pair);
        uint256[] memory live = bv3Vault.getCurrentLiveBalances(pool);
        uint256 livePair = live[pairIdx];
        uint256 liveShares = live[sharesIdx];
        if (liveShares == 0) return 0;
        return livePair * 1e18 / liveShares;
    }

    /// @notice Uni index: spot_t / spot_0 (USDC/WETH).
    function uniPriceIndex() public view returns (uint256) {
        require(telemetryReady, "research: telemetry not ready");
        return uniSpotUsdcPerWeth() * 1e18 / initUniSpotUsdcPerWeth;
    }

    /// @notice Balancer mid index: mid_t / mid_0 (raw pair/liveShares).
    /// @dev WETH-rated pools share one path; USDC-rated share another (opposite when Uni tilts).
    function balancerPriceIndex(uint256 idx) public view returns (uint256) {
        require(telemetryReady, "research: telemetry not ready");
        uint256 mid = balancerMidRaw(idx);
        require(mid > 0 && initBalancerMid[idx] > 0, "research: zero bal mid");
        return mid * 1e18 / initBalancerMid[idx];
    }

    function rateWethIndex() public view returns (uint256) {
        require(telemetryReady, "research: telemetry not ready");
        return rateProviderWeth.getRate() * 1e18 / initRateWeth;
    }

    function rateUsdcIndex() public view returns (uint256) {
        require(telemetryReady, "research: telemetry not ready");
        return rateProviderUsdc.getRate() * 1e18 / initRateUsdc;
    }

    /* ---------------------------------------------------------------------- */
    /*           Full exit mark: Balancer → vault shares → LP → tokens         */
    /* ---------------------------------------------------------------------- */

    /// @dev Destructive: exits all alice Balancer BPT, redeems vault shares to LP, burns LP.
    ///      Returns raw WETH/USDC balances held by `who` after exit (no conversion).
    function _executeFullExitToTokens(address who) internal returns (uint256 wethOut, uint256 usdcOut) {
        // 1) Exit each Balancer matrix pool (BPT → pair token + vault shares).
        for (uint256 i = 0; i < MATRIX_N; ++i) {
            address pool = matrixPools[i];
            uint256 bpt = IERC20(pool).balanceOf(who);
            if (bpt == 0) continue;
            uint256[] memory mins = new uint256[](2);
            vm.startPrank(who);
            IERC20(pool).approve(address(router), bpt);
            router.removeLiquidityProportional(pool, bpt, mins, false, bytes(""));
            vm.stopPrank();
        }

        // 2) Redeem all vault shares → Uni V2 LP.
        uint256 sh = shares.balanceOf(who);
        if (sh > 0) {
            vm.prank(who);
            seVault.redeem(sh, who, who);
        }

        // 3) Remove Uni V2 LP → WETH + USDC.
        uint256 lpBal = uniV2Pair.balanceOf(who);
        if (lpBal > 0) {
            vm.startPrank(who);
            uniV2Pair.approve(address(uniV2Router), lpBal);
            uniV2Router.removeLiquidity(
                address(tokenWeth),
                address(tokenUsdc),
                lpBal,
                0,
                0,
                who,
                block.timestamp + 1 hours
            );
            vm.stopPrank();
        }

        wethOut = tokenWeth.balanceOf(who);
        usdcOut = tokenUsdc.balanceOf(who);
    }

    /// @notice Mark portfolio in USDC via full exit, without permanently changing state.
    function markFullExitUsdc() public returns (uint256 usdcValue, uint256 wethClaim, uint256 usdcClaim) {
        uint256 snap = vm.snapshotState();
        (wethClaim, usdcClaim) = _executeFullExitToTokens(alice);
        // Mark at live Uni spot (no forced swap impact).
        uint256 spot = uniSpotUsdcPerWeth(); // USDC per WETH
        usdcValue = usdcClaim + wethClaim * spot / 1e18;
        vm.revertToState(snap);
    }

    /// @notice Hold t0 token claim at current Uni prices (USDC).
    function markHoldClaim0Usdc() public view returns (uint256) {
        require(telemetryReady, "research: telemetry not ready");
        uint256 spot = uniSpotUsdcPerWeth();
        return claim0Usdc + claim0Weth * spot / 1e18;
    }

    function _uniReservesOf(IERC20 tokenX, IERC20 tokenY) internal view returns (uint256 rX, uint256 rY) {
        (uint112 r0, uint112 r1,) = uniV2Pair.getReserves();
        address t0 = uniV2Pair.token0();
        address t1 = uniV2Pair.token1();
        if (address(tokenX) == t0 && address(tokenY) == t1) {
            rX = uint256(r0);
            rY = uint256(r1);
        } else if (address(tokenX) == t1 && address(tokenY) == t0) {
            rX = uint256(r1);
            rY = uint256(r0);
        } else {
            revert("research: token not in pair");
        }
    }

    function _poolIndices(address pool, IERC20 pair)
        internal
        view
        returns (uint256 pairIdx, uint256 sharesIdx)
    {
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(pool);
        if (address(tokens[0]) == address(pair)) {
            (pairIdx, sharesIdx) = (0, 1);
        } else {
            (pairIdx, sharesIdx) = (1, 0);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         Mode A: trade Uni V2 only                       */
    /* ---------------------------------------------------------------------- */

    function swapUniExactIn(address tokenIn, address tokenOut, uint256 amountIn) public {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        if (tokenIn == address(tokenWeth)) {
            _fundWeth(bob, amountIn);
        } else {
            usdc.mint(bob, amountIn);
        }

        vm.startPrank(bob);
        IERC20(tokenIn).approve(address(uniV2Router), amountIn);
        uniV2Router.swapExactTokensForTokens(amountIn, 0, path, bob, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*     Mode C hook (overridden in ResearchFixture_ModeC)                   */
    /* ---------------------------------------------------------------------- */

    /// @dev Mode A: no-op. Mode C fixture overrides with standalone ResearchModeCCloser.
    function closeBalancerArbs() public virtual returns (uint256 profit_, uint256 fills_) {
        stepArbProfit = 0;
        stepArbFills = 0;
        profit_ = 0;
        fills_ = 0;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Telemetry                                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @param runId_        Artifact subdirectory under research/out/uniswapV2Se/
     * @param tradedIsWeth_ True if external flow is WETH→USDC (market buys USDC from us).
     *                      False if USDC→WETH (market buys WETH from us).
     * @dev LP framing for charts: market demand against our liquidity (not "we sell").
     *      Price: Uni USDC/WETH + Balancer mid_t/mid_0.
     *      P&L: full exit Balancer→vault→LP→tokens, marked in USDC; split into
     *      asset revaluation vs maker fees / claim qty change.
     */
    function initTelemetry(string memory runId_, bool tradedIsWeth_) external virtual {
        tradedIsWeth = tradedIsWeth_;
        telemetryReady = true;

        initUniSpotUsdcPerWeth = uniSpotUsdcPerWeth();
        for (uint256 i = 0; i < MATRIX_N; ++i) {
            initBalancerMid[i] = balancerMidRaw(i);
            require(initBalancerMid[i] > 0, "research: zero bal mid");
        }
        initRateWeth = rateProviderWeth.getRate();
        initRateUsdc = rateProviderUsdc.getRate();
        require(initUniSpotUsdcPerWeth > 0 && initRateWeth > 0 && initRateUsdc > 0, "research: zero t0");

        (portfolio0Usdc, claim0Weth, claim0Usdc) = markFullExitUsdc();
        require(portfolio0Usdc > 0, "research: zero portfolio0");

        step = 0;
        runPaths = ResearchTelemetry.initRun("uniswapV2Se", runId_);

        // Keep meta concat small (stack). Extra reconstruction fields added by stamp_meta.py.
        ResearchTelemetry.writeMeta(runPaths, _buildMetaJson(runId_));
        sample("init");
    }

    function _buildMetaJson(string memory runId_) internal view virtual returns (string memory) {
        string memory modeLabel = researchModeId == 1 ? "C_uni_plus_bal_arb" : "A_uni_only";
        string memory tradedLabel = tradedIsWeth ? "WETH" : "USDC";
        string memory marketBought = tradedIsWeth ? "USDC" : "WETH";
        string memory part1 = string.concat(
            "{\"product\":\"uniswapV2Se\",\"mode\":\"",
            modeLabel,
            "\",\"runId\":\"",
            runId_,
            "\",\"framing\":\"lp_market_demand\",\"tradedAsset\":\"",
            tradedLabel,
            "\",\"marketBoughtAsset\":\"",
            marketBought,
            "\",\"pnlDenom\":\"USDC\","
        );
        string memory part2 = string.concat(
            "\"tradeSteps\":",
            ResearchTelemetry.u(TRADE_STEPS),
            ",\"tradeWethWei\":\"",
            ResearchTelemetry.u(TRADE_WETH),
            "\",\"tradeUsdcWei\":\"",
            ResearchTelemetry.u(TRADE_USDC),
            "\",\"vaultLpDeposited\":\"",
            ResearchTelemetry.u(vaultLpDeposited),
            "\",\"portfolio0Usdc\":\"",
            ResearchTelemetry.u(portfolio0Usdc),
            "\",\"initPrice_USDC_per_WETH\":\"",
            ResearchTelemetry.u(initUniSpotUsdcPerWeth),
            "\",\"scenariosDoc\":\"research/scenarios/uniswapV2Se/\",",
            "\"note\":\"Raw bar ratios (no invert). stamp_meta.py adds gitCommit.\"}"
        );
        return string.concat(part1, part2);
    }

    function sample(string memory action_) public {
        require(telemetryReady, "research: telemetry not ready");

        (uint256 exitUsdc, uint256 exitWeth, uint256 exitUsdcTok) = markFullExitUsdc();
        uint256 holdUsdc = markHoldClaim0Usdc();

        string memory line = _sampleHead(action_);
        line = string.concat(line, _sampleMatrix());
        line = string.concat(line, _samplePnlAndArb(exitUsdc, holdUsdc, exitWeth, exitUsdcTok));
        ResearchTelemetry.appendLine(runPaths, line);

        stepArbProfit = 0;
        stepArbFills = 0;
        stepMaxBuyProbe = 0;
        stepMaxSellProbe = 0;
        stepPositiveProbes = 0;
        step += 1;
    }

    function _sampleHead(string memory action_) private view returns (string memory) {
        return string.concat(
            "{\"step\":",
            ResearchTelemetry.u(step),
            ",\"action\":\"",
            action_,
            "\",\"tradedIsWeth\":",
            tradedIsWeth ? "true" : "false",
            ",\"uniSpot_USDCperWETH\":\"",
            ResearchTelemetry.u(uniSpotUsdcPerWeth()),
            "\",\"uniPriceIndex\":\"",
            ResearchTelemetry.u(uniPriceIndex()),
            "\",\"rateWeth\":\"",
            ResearchTelemetry.u(rateProviderWeth.getRate()),
            "\",\"rateUsdc\":\"",
            ResearchTelemetry.u(rateProviderUsdc.getRate()),
            "\",\"rateWethIndex\":\"",
            ResearchTelemetry.u(rateWethIndex()),
            "\",\"rateUsdcIndex\":\"",
            ResearchTelemetry.u(rateUsdcIndex()),
            "\","
        );
    }

    function _sampleMatrix() private view returns (string memory line) {
        line = "";
        for (uint256 i = 0; i < MATRIX_N; ++i) {
            line = string.concat(
                line,
                "\"",
                matrixLabels[i],
                "_midRaw\":\"",
                ResearchTelemetry.u(balancerMidRaw(i)),
                "\",\"",
                matrixLabels[i],
                "_index\":\"",
                ResearchTelemetry.u(balancerPriceIndex(i)),
                "\","
            );
        }
    }

    function _samplePnlAndArb(
        uint256 exitUsdc,
        uint256 holdUsdc,
        uint256 exitWeth,
        uint256 exitUsdcTok
    ) private view returns (string memory) {
        string memory pnl = _samplePnlOnly(exitUsdc, holdUsdc, exitWeth, exitUsdcTok);
        return string.concat(pnl, _sampleArbTail());
    }

    function _samplePnlOnly(
        uint256 exitUsdc,
        uint256 holdUsdc,
        uint256 exitWeth,
        uint256 exitUsdcTok
    ) private view returns (string memory) {
        int256 pricePnl = int256(holdUsdc) - int256(portfolio0Usdc);
        int256 feePnl = int256(exitUsdc) - int256(holdUsdc);
        int256 totalPnl = int256(exitUsdc) - int256(portfolio0Usdc);
        return string.concat(
            "\"portfolioExitUsdc\":\"",
            ResearchTelemetry.u(exitUsdc),
            "\",\"portfolioHoldClaim0Usdc\":\"",
            ResearchTelemetry.u(holdUsdc),
            "\",\"portfolio0Usdc\":\"",
            ResearchTelemetry.u(portfolio0Usdc),
            "\",\"exitClaimWeth\":\"",
            ResearchTelemetry.u(exitWeth),
            "\",\"exitClaimUsdc\":\"",
            ResearchTelemetry.u(exitUsdcTok),
            "\",\"pricePnlUsdc\":\"",
            _i(pricePnl),
            "\",\"feePnlUsdc\":\"",
            _i(feePnl),
            "\",\"totalPnlUsdc\":\"",
            _i(totalPnl),
            "\","
        );
    }

    function _sampleArbTail() private view returns (string memory) {
        return string.concat(
            "\"arbProfit\":\"",
            ResearchTelemetry.u(stepArbProfit),
            "\",\"arbFills\":\"",
            ResearchTelemetry.u(stepArbFills),
            "\",\"cumulativeArbProfit\":\"",
            ResearchTelemetry.u(cumulativeArbProfit),
            "\",\"maxBuyProbe\":\"",
            ResearchTelemetry.u(stepMaxBuyProbe),
            "\",\"maxSellProbe\":\"",
            ResearchTelemetry.u(stepMaxSellProbe),
            "\",\"positiveProbes\":\"",
            ResearchTelemetry.u(stepPositiveProbes),
            "\"}"
        );
    }

    function _i(int256 v) internal pure returns (string memory) {
        if (v >= 0) return ResearchTelemetry.u(uint256(v));
        return string.concat("-", ResearchTelemetry.u(uint256(-v)));
    }
}
