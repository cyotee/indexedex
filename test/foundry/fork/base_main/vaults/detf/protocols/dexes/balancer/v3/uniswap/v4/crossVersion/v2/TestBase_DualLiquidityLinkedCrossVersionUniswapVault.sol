// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {WeightedPoolFactory} from
    "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {SenderGuardFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_SharedConstants} from "@crane/contracts/test/bases/TestBase_SharedConstants.sol";

// Uniswap V4 (live PoolManager; local seeder for new markets)
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

// Uniswap V2 (live factory/router on Base)
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IBalancerV3StandardExchangeRouterProxy} from
    "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IBalancerV3StandardExchangeRouterPrepay} from
    "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IBalancerV3StandardExchangeRouterDFPkg
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";
import {
    BalancerV3StandardExchangeRouter_FactoryService
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {TestBase_BaseFork} from "test/foundry/fork/base_main/TestBase_BaseFork.sol";

import {IUniswapV4StandardExchangeDFPkg} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {UniswapV4_Component_FactoryService} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {IUniswapV2StandardExchangeDFPkg} from
    "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {UniswapV2_Component_FactoryService} from
    "contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {StandardExchangeRateProviderFacet} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";

import {
    IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.sol";

/// @dev Uniswap V4 liquidity seeder (unlock-callback) for seeding new markets on the live PoolManager.
contract DualLiquidityV4LiquiditySeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey_, int24 tickLower_, int24 tickUpper_, uint128 liquidity_) external {
        poolManager.unlock(abi.encode(poolKey_, tickLower_, tickUpper_, liquidity_));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pool manager");
        (PoolKey memory poolKey_, int24 tickLower_, int24 tickUpper_, uint128 liquidity_) =
            abi.decode(data_, (PoolKey, int24, int24, uint128));
        (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(
            poolKey_,
            ModifyLiquidityParams({
                tickLower: tickLower_,
                tickUpper: tickUpper_,
                liquidityDelta: int256(uint256(liquidity_)),
                salt: bytes32(0)
            }),
            bytes("")
        );
        _settle(poolKey_.currency0, callerDelta.amount0());
        _settle(poolKey_.currency1, callerDelta.amount1());
        return abi.encode(callerDelta);
    }

    function _settle(Currency currency_, int128 delta_) internal {
        if (delta_ < 0) {
            uint256 amount = uint128(-delta_);
            poolManager.sync(currency_);
            IERC20(Currency.unwrap(currency_)).transfer(address(poolManager), amount);
            poolManager.settle();
        } else if (delta_ > 0) {
            poolManager.take(currency_, address(this), uint128(delta_));
        }
    }
}

/**
 * @title TestBase_DualLiquidityLinkedCrossVersionUniswapVault
 * @notice Production-path test base: live Base Balancer V3 Vault + WeightedPoolFactory, IndexedEx
 *         Standard Exchange Router (seRouter) as the only router the vault talks to, live Uniswap
 *         V4 PoolManager + Uniswap V2 factory/router, real ERC20Permit role tokens, and registry
 *         deploy of the vault package.
 * @dev No Balancer VaultMock / RouterMock. Bootstrap and reserve joins use seRouter prepay APIs
 *      (the path production vault code takes via aware repos). Aerodrome fixtures are not pulled in.
 *
 *      Requires a Base mainnet fork (FOUNDRY_PROFILE=fork or FOUNDRY_TEST under fork/base_main with RPC).
 */
abstract contract TestBase_DualLiquidityLinkedCrossVersionUniswapVault is
    TestBase_BaseFork,
    TestBase_Permit2,
    IndexedexTest,
    TestBase_SharedConstants
{
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IUniswapV4StandardExchangeDFPkg;
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;
    using UniswapV2_Component_FactoryService for IFacet;
    using UniswapV2_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV2_Component_FactoryService for IIndexedexManagerProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using BalancerV3StandardExchangeRouter_FactoryService for ICreate3FactoryProxy;
    using BalancerV3StandardExchangeRouter_FactoryService for IDiamondPackageCallBackFactory;

    /* ---------------------------------------------------------------------- */
    /*                              Constants                                 */
    /* ---------------------------------------------------------------------- */

    uint24 internal constant WIDTH_MULTIPLIER = 60;
    uint256 internal constant V4_SEED = 100_000e18;
    uint256 internal constant V2_SEED = 100_000e18;
    uint256 internal constant LEG_SEED = 1_000e18;
    uint256 internal constant TEST_TOKEN_TOTAL_SUPPLY = 100_000_000e18;

    /* ---------------------------------------------------------------------- */
    /*                         Live protocol surface                          */
    /* ---------------------------------------------------------------------- */

    /// @notice Live Balancer V3 Vault (Base mainnet) - production, not VaultMock.
    IVault internal vault;
    /// @notice Live Balancer V3 Weighted Pool Factory (Base mainnet).
    WeightedPoolFactory internal weightedPoolFactory;
    /// @notice Live Uniswap V4 PoolManager (Base mainnet).
    IPoolManager internal poolManager;
    /// @notice Live Uniswap V2 factory / router (Base mainnet).
    IUniswapV2Factory internal v2Factory;
    IUniswapV2Router internal v2Router;

    /* ---------------------------------------------------------------------- */
    /*                    IndexedEx Standard Exchange Router                  */
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
    /// @notice Production IndexedEx SE router - the only router the vault package is wired to.
    IBalancerV3StandardExchangeRouterProxy internal seRouter;
    IBalancerV3StandardExchangeRouterPrepay internal prepayRouter;

    /* ---------------------------------------------------------------------- */
    /*                         Role tokens + markets                          */
    /* ---------------------------------------------------------------------- */

    ERC20PermitDFPkg internal erc20PermitPkg;
    IERC20 internal commonToken;
    IERC20 internal tokenA;
    IERC20 internal tokenB;

    DualLiquidityV4LiquiditySeeder internal seeder;
    IUniswapV2Pair internal pair;

    IFacet internal erc20Facet;
    IFacet internal erc2612Facet;
    IFacet internal erc5267Facet;
    IFacet internal erc4626Facet;
    IFacet internal multiAssetBasicVaultFacet;
    IFacet internal multiAssetStandardVaultFacet;

    IUniswapV4StandardExchangeDFPkg internal v4VaultPkg;
    IUniswapV2StandardExchangeDFPkg internal v2VaultPkg;
    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;

    IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg internal linkedVaultPkg;
    address internal linkedVault;

    /* ---------------------------------------------------------------------- */
    /*                                Setup                                   */
    /* ---------------------------------------------------------------------- */

    function setUp() public virtual override(TestBase_BaseFork, TestBase_Permit2, IndexedexTest) {
        TestBase_BaseFork.setUp();

        // Canonical Permit2 (same address on all EVM chains, including Base).
        permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        TestBase_Permit2.setUp();

        IndexedexTest.setUp();

        _bindLiveProtocols();
        setUpSharedConstants(); // no-op if weth already set from BASE_MAIN

        _deploySeRouterFacets();
        _deploySeRouterPackage();
        _deploySeRouter();

        _deployTokenAndVaultFacets();
        _deployTestTokenPkg();
        commonToken = _deployTestToken("Common", "CMN", keccak256("dlCVUVault_Common"));
        tokenA = _deployTestToken("Token A", "TKA", keccak256("dlCVUVault_TokenA"));
        // Virtual seam so adversarial suites can inject a hostile tokenB (e.g. ReentrantMockERC20).
        tokenB = _deployTokenB();

        _setUpV4Markets();
        _setUpV2Market();
        _deployLegPackages();
        linkedVaultPkg = _deployLinkedVaultPkg();

        IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgArgs memory pkgArgs =
            IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgArgs({
                name: "Dual Liquidity Cross-Version Uniswap Vault",
                symbol: "dlCVUVault",
                commonToken: IERC20(address(commonToken)),
                tokenA: IERC20(address(tokenA)),
                tokenB: IERC20(address(tokenB)),
                poolKeyA: _poolKey(commonToken, tokenA),
                widthMultiplierA: WIDTH_MULTIPLIER,
                poolKeyB: _poolKey(commonToken, tokenB),
                widthMultiplierB: WIDTH_MULTIPLIER,
                pairPool: pair,
                weightA: 0.2e18,
                weightB: 0.2e18,
                weightPair: 0.6e18,
                // Product default false; rates-on regression overrides via `_useRateProviders()`.
                useRateProviders: _useRateProviders(),
                optionalSalt: keccak256(abi.encodePacked("dlCVUVault-instance", block.timestamp, address(this)))
            });

        vm.prank(owner);
        linkedVault = indexedexManager.deployVault(IStandardVaultPkg(address(linkedVaultPkg)), abi.encode(pkgArgs));
    }

    /// @dev Product default: rates off (STANDARD). Override to `true` only in rates-on regression suites.
    ///      `view` (not pure) so research fixtures can return an immutable constructor flag.
    function _useRateProviders() internal view virtual returns (bool) {
        return false;
    }

    /// @dev Override in reentrancy suites to return a hostile tokenB. Default: real ERC20Permit diamond.
    function _deployTokenB() internal virtual returns (IERC20) {
        return _deployTestToken("Token B", "TKB", keccak256("dlCVUVault_TokenB"));
    }

    /* ---------------------------------------------------------------------- */
    /*                         Live protocol binding                          */
    /* ---------------------------------------------------------------------- */

    function _bindLiveProtocols() internal virtual {
        vault = IVault(BASE_MAIN.BALANCER_V3_VAULT);
        weightedPoolFactory = WeightedPoolFactory(BASE_MAIN.BALANCER_V3_WEIGHTED_POOL_FACTORY);
        weth = IWETH(BASE_MAIN.WETH9);
        poolManager = IPoolManager(BASE_MAIN.UNISWAP_V4_POOL_MANAGER);
        v2Factory = IUniswapV2Factory(BASE_MAIN.UNISWAP_V2_FACTORY);
        v2Router = IUniswapV2Router(BASE_MAIN.UNISWAP_V2_ROUTER);

        _assertHasCode(address(vault), "Balancer V3 Vault");
        _assertHasCode(address(weightedPoolFactory), "Balancer V3 Weighted Pool Factory");
        _assertHasCode(address(weth), "WETH");
        _assertHasCode(address(poolManager), "Uniswap V4 PoolManager");
        _assertHasCode(address(v2Factory), "Uniswap V2 Factory");
        _assertHasCode(address(v2Router), "Uniswap V2 Router");

        vm.label(address(vault), "BalancerV3Vault_Live");
        vm.label(address(weightedPoolFactory), "WeightedPoolFactory_Live");
        vm.label(address(poolManager), "UniswapV4PoolManager_Live");
        vm.label(address(v2Factory), "UniswapV2Factory_Live");
        vm.label(address(v2Router), "UniswapV2Router_Live");
    }

    /* ---------------------------------------------------------------------- */
    /*                    SE Router (production IndexedEx)                    */
    /* ---------------------------------------------------------------------- */

    function _deploySeRouterFacets() internal virtual {
        senderGuardFacet = IFacet(address(new SenderGuardFacet()));
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

    function _deploySeRouterPackage() internal virtual {
        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit;
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
        pkgInit.balancerV3Vault = vault;
        pkgInit.permit2 = permit2;
        pkgInit.weth = weth;

        seRouterDFPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(pkgInit);
        vm.label(address(seRouterDFPkg), "SERouterDFPkg");
    }

    function _deploySeRouter() internal virtual {
        seRouter = diamondPackageFactory.deployBalancerV3StandardExchangeRouter(seRouterDFPkg);
        prepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(seRouter));
        vm.label(address(seRouter), "SERouter");
    }

    /* ---------------------------------------------------------------------- */
    /*                     Token + vault facet deploy                         */
    /* ---------------------------------------------------------------------- */

    function _deployTokenAndVaultFacets() internal virtual {
        erc20Facet = create3Factory.deployERC20Facet();
        erc2612Facet = create3Factory.deployERC2612Facet();
        erc5267Facet = create3Factory.deployERC5267Facet();
        erc4626Facet = create3Factory.deployERC4626Facet();
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
    }

    function _deployTestTokenPkg() internal {
        erc20PermitPkg = ERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(
                        IERC20PermitDFPkg.PkgInit({
                            erc20Facet: erc20Facet,
                            erc5267Facet: erc5267Facet,
                            erc2612Facet: erc2612Facet
                        })
                    ),
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, "DualLiquidityLinkedCrossVersionUniswapVault"))
                )
            )
        );
    }

    function _deployTestToken(string memory name_, string memory symbol_, bytes32 salt_)
        internal
        returns (IERC20 token_)
    {
        token_ = IERC20(
            diamondPackageFactory.deploy(
                IDiamondFactoryPackage(address(erc20PermitPkg)),
                abi.encode(
                    IERC20PermitDFPkg.PkgArgs({
                        name: name_,
                        symbol: symbol_,
                        decimals: 18,
                        totalSupply: TEST_TOKEN_TOTAL_SUPPLY,
                        recipient: address(this),
                        optionalSalt: salt_
                    })
                )
            )
        );
    }

    function _fund(IERC20 token_, address to_, uint256 amount_) internal {
        if (to_ != address(this)) token_.transfer(to_, amount_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Uniswap markets                                */
    /* ---------------------------------------------------------------------- */

    function _setUpV4Markets() internal {
        seeder = new DualLiquidityV4LiquiditySeeder(poolManager);
        _seedV4Pool(commonToken, tokenA);
        _seedV4Pool(commonToken, tokenB);
    }

    function _seedV4Pool(IERC20 t0_, IERC20 t1_) internal {
        PoolKey memory key = _poolKey(t0_, t1_);
        poolManager.initialize(key, TickMath.getSqrtPriceAtTick(0));
        t0_.transfer(address(seeder), V4_SEED);
        t1_.transfer(address(seeder), V4_SEED);
        seeder.addLiquidity(
            key,
            -60,
            60,
            LiquidityAmounts.getLiquidityForAmounts(
                TickMath.getSqrtPriceAtTick(0),
                TickMath.getSqrtPriceAtTick(-60),
                TickMath.getSqrtPriceAtTick(60),
                V4_SEED,
                V4_SEED
            )
        );
    }

    function _poolKey(IERC20 ta_, IERC20 tb_) internal pure returns (PoolKey memory key_) {
        (address c0, address c1) =
            address(ta_) < address(tb_) ? (address(ta_), address(tb_)) : (address(tb_), address(ta_));
        key_ = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _setUpV2Market() internal {
        // Fresh pair on the live factory for our role tokens.
        pair = IUniswapV2Pair(v2Factory.createPair(address(tokenA), address(tokenB)));
        tokenA.approve(address(v2Router), V2_SEED);
        tokenB.approve(address(v2Router), V2_SEED);
        v2Router.addLiquidity(
            address(tokenA), address(tokenB), V2_SEED, V2_SEED, 0, 0, address(this), block.timestamp + 1
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                         Leg + vault packages                           */
    /* ---------------------------------------------------------------------- */

    function _deployLegPackages() internal {
        IFacet v4In = create3Factory.deployUniswapV4StandardExchangeInFacet();
        IFacet v4InQ = create3Factory.deployUniswapV4StandardExchangeInQueryFacet();
        IFacet v4Import = create3Factory.deployUniswapV4StandardExchangePositionImportFacet();
        IFacet v4Out = create3Factory.deployUniswapV4StandardExchangeOutFacet();
        IFacet v2In = create3Factory.deployUniswapV2StandardExchangeInFacet();
        IFacet v2Out = create3Factory.deployUniswapV2StandardExchangeOutFacet();

        vm.startPrank(owner);
        v4VaultPkg = indexedexManager.deployUniswapV4StandardExchangeDFPkg(
            erc20Facet.buildArgsUniswapV4StandardExchangePkgInit(
                erc5267Facet,
                erc2612Facet,
                multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet,
                v4In,
                v4InQ,
                v4Import,
                v4Out,
                indexedexManager,
                indexedexManager,
                permit2,
                poolManager
            )
        );
        v2VaultPkg = indexedexManager.deployUniswapV2StandardExchangeDFPkg(
            erc20Facet.buildArgsUniswapV2StandardExchangePkgInit(
                erc2612Facet,
                erc5267Facet,
                erc4626Facet,
                multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet,
                v2In,
                v2Out,
                indexedexManager,
                indexedexManager,
                permit2,
                v2Factory,
                v2Router
            )
        );
        vm.stopPrank();

        rateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(
                        IStandardExchangeRateProviderDFPkg.PkgInit({
                            rateProviderFacet: IFacet(
                                create3Factory.deployFacet(
                                    type(StandardExchangeRateProviderFacet).creationCode,
                                    keccak256("dlCVUVault_RateProviderFacet")
                                )
                            ),
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    keccak256("dlCVUVault_StandardExchangeRateProviderDFPkg")
                )
            )
        );
    }

    function _deployLinkedVaultPkg() internal returns (IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg pkg_) {
        // Facets deploy as this test (create3Factory admin). Registry package deploy requires operator.
        DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.ExchangeFacets memory facets_ =
            DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.deployExchangeFacets(create3Factory);

        IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgInit memory pkgInit =
            IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                exchangeInFacet: facets_.exchangeInFacet,
                exchangeInQueryFacet: facets_.exchangeInQueryFacet,
                exchangeOutFacet: facets_.exchangeOutFacet,
                exchangeOutQueryFacet: facets_.exchangeOutQueryFacet,
                feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                // Production SE router - vault callbacks go here, not Balancer's native router.
                balancerV3Router: seRouter,
                balancerV3Vault: vault,
                weightedPoolFactory: weightedPoolFactory,
                v4VaultPkg: v4VaultPkg,
                v2VaultPkg: v2VaultPkg,
                rateProviderPkg: rateProviderPkg,
                permit2: permit2,
                diamondFactory: diamondPackageFactory
            });

        vm.prank(owner);
        pkg_ = DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                      Bootstrap / deposit helpers                       */
    /* ---------------------------------------------------------------------- */

    /// @dev Reserve weighted pool from the standard vault surface (3-token Balancer pool entry).
    function _reservePool() internal view returns (address pool_) {
        address[] memory vt = IBasicVault(linkedVault).vaultTokens();
        for (uint256 i = 0; i < vt.length; i++) {
            if (vt[i] == linkedVault) continue;
            try vault.getPoolTokens(vt[i]) returns (IERC20[] memory pt) {
                if (pt.length == 3) return vt[i];
            } catch {}
        }
        revert("reserve pool not found");
    }

    /// @dev Manual bootstrap: leg shares -> prepayInitialize via seRouter -> first share deposit (1:1).
    function _bootstrapReserve() internal returns (uint256 bptOut) {
        address pool = _reservePool();
        IERC20[] memory legs = vault.getPoolTokens(pool);

        uint256[] memory amounts = new uint256[](legs.length);
        for (uint256 i = 0; i < legs.length; i++) {
            amounts[i] = _acquireLegShare(address(legs[i]), address(this));
            // Prepay pattern: tokens must already sit on the Balancer vault for settle().
            legs[i].transfer(address(vault), amounts[i]);
        }

        // Production path: IndexedEx SE prepayInitialize (contract caller is allowed when vault is locked).
        bptOut = prepayRouter.prepayInitialize(pool, legs, amounts, 0, "");

        uint256 bptBal = IERC20(pool).balanceOf(address(this));
        IERC20(pool).approve(linkedVault, bptBal);
        IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(pool), bptBal, IERC20(linkedVault), 0, address(this), false, block.timestamp
        );
    }

    /// @dev Zap into a leg vault with whichever of commonToken/tokenA/tokenB it accepts.
    function _acquireLegShare(address legVault, address to_) internal returns (uint256 out) {
        IERC20 shareTok = IERC20(legVault);
        IERC20[3] memory ins = [commonToken, tokenA, tokenB];
        for (uint256 i = 0; i < ins.length; i++) {
            _fund(ins[i], to_, LEG_SEED);
            vm.startPrank(to_);
            ins[i].approve(legVault, LEG_SEED);
            try IStandardExchangeIn(legVault).exchangeIn(ins[i], LEG_SEED, shareTok, 0, to_, false, block.timestamp)
            returns (uint256 o) {
                vm.stopPrank();
                if (o > 0) return o;
            } catch {
                vm.stopPrank();
            }
        }
        revert("no working leg zap");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Fee / share helpers                            */
    /* ---------------------------------------------------------------------- */

    function _feeOracle() internal view returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(address(indexedexManager));
    }

    function _feeManager() internal view returns (IVaultFeeOracleManager) {
        return IVaultFeeOracleManager(address(indexedexManager));
    }

    function _feeTo() internal view returns (address) {
        return address(_feeOracle().feeTo());
    }

    /// @dev Sets the per-vault usage fee (WAD). Owner-gated on the manager.
    function _setUsageFee(uint256 feeWad_) internal {
        vm.prank(owner);
        _feeManager().setUsageFeeOfVault(linkedVault, feeWad_);
    }

    /// @dev Deposit `commonAmount_` of commonToken into the vault; returns user shares minted.
    function _depositCommon(address to_, uint256 commonAmount_) internal returns (uint256 minted_) {
        _fund(commonToken, to_, commonAmount_);
        vm.startPrank(to_);
        commonToken.approve(linkedVault, commonAmount_);
        minted_ = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, commonAmount_, IERC20(linkedVault), 0, to_, false, block.timestamp
        );
        vm.stopPrank();
    }

    function _totalReserveBpt() internal view returns (uint256) {
        return IERC20(_reservePool()).balanceOf(linkedVault);
    }

    /// @dev Cross-multiplied BPT-per-share comparison: returns true if a/b >= c/d without precision loss.
    function _bptPerShareGte(uint256 bptA, uint256 sharesA, uint256 bptB, uint256 sharesB)
        internal
        pure
        returns (bool)
    {
        if (sharesA == 0 || sharesB == 0) return sharesB == 0;
        return bptA * sharesB >= bptB * sharesA;
    }

    /* ---------------------------------------------------------------------- */
    /*                    Permit2 funding (pretransferred path)               */
    /* ---------------------------------------------------------------------- */

    /// @dev User infinite-approves `token_` to Permit2 (ERC20 allowance).
    function _permit2ApproveToken(address user_, IERC20 token_) internal {
        vm.startPrank(user_);
        token_.approve(address(permit2), type(uint256).max);
        vm.stopPrank();
    }

    /// @dev User grants this test contract an AllowanceTransfer spend allowance on Permit2.
    function _permit2ApproveSpender(address user_, IERC20 token_, address spender_) internal {
        vm.startPrank(user_);
        permit2.approve(address(token_), spender_, type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }

    /// @notice Moves `amount_` of `token_` from `user_` to `to_` via Permit2 AllowanceTransfer.
    /// @dev Requires prior ERC20 approve(Permit2) and Permit2.approve(spender=this).
    function _permit2TransferFrom(address user_, address to_, IERC20 token_, uint256 amount_) internal {
        require(amount_ <= type(uint160).max, "amount > uint160");
        permit2.transferFrom(user_, to_, uint160(amount_), address(token_));
    }

    /// @notice Full Permit2 prefund into the linked vault: ERC20->Permit2, Permit2 spend allowance,
    ///         then AllowanceTransfer into the vault. Caller then uses `pretransferred=true`.
    function _permit2PrefundVault(address user_, IERC20 token_, uint256 amount_) internal {
        _fund(token_, user_, amount_);
        _permit2ApproveToken(user_, token_);
        _permit2ApproveSpender(user_, token_, address(this));
        _permit2TransferFrom(user_, linkedVault, token_, amount_);
    }

    /// @notice Deposit via Permit2 prefund + `pretransferred=true` exchangeIn into vault shares.
    function _depositCommonViaPermit2(address to_, uint256 commonAmount_) internal returns (uint256 minted_) {
        _permit2PrefundVault(to_, commonToken, commonAmount_);
        vm.prank(to_);
        minted_ = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, commonAmount_, IERC20(linkedVault), 0, to_, true, block.timestamp
        );
    }

    /// @dev The three leg share tokens are the reserve pool's registered tokens (any order).
    function _legShares() internal view returns (IERC20 leg0, IERC20 leg1, IERC20 leg2) {
        IERC20[] memory poolToks = vault.getPoolTokens(_reservePool());
        require(poolToks.length == 3, "expected 3-token reserve");
        leg0 = poolToks[0];
        leg1 = poolToks[1];
        leg2 = poolToks[2];
    }

    /* ---------------------------------------------------------------------- */
    /*                         Residual / route helpers                       */
    /* ---------------------------------------------------------------------- */

    /// @dev Intermediate inventory on the linked vault (excludes reserve BPT and share supply).
    function _intermediateBalances(address who_)
        internal
        view
        returns (uint256[6] memory b)
    {
        (IERC20 leg0, IERC20 leg1, IERC20 leg2) = _legShares();
        b[0] = commonToken.balanceOf(who_);
        b[1] = tokenA.balanceOf(who_);
        b[2] = tokenB.balanceOf(who_);
        b[3] = leg0.balanceOf(who_);
        b[4] = leg1.balanceOf(who_);
        b[5] = leg2.balanceOf(who_);
    }

    /// @dev Asserts the linked vault holds no intermediate inventory (only BPT/shares expected).
    function _assertNoIntermediateInventory() internal view {
        uint256[6] memory b = _intermediateBalances(linkedVault);
        for (uint256 i = 0; i < 6; i++) {
            assertEq(b[i], 0, "intermediate inventory stranded on vault");
        }
    }

    /// @dev Skew the common/tokenA V4 market by swapping a large amount of common through vault A.
    function _skewMarketTowardTokenA(uint256 commonIn_) internal {
        _fund(commonToken, address(this), commonIn_);
        commonToken.approve(linkedVault, commonIn_);
        try IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, commonIn_, tokenA, 0, address(this), false, block.timestamp
        ) {} catch {}
    }

    /// @dev Skew the common/tokenB V4 market by swapping common -> tokenB through the vault aggregator.
    function _skewMarketTowardTokenB(uint256 commonIn_) internal {
        _fund(commonToken, address(this), commonIn_);
        commonToken.approve(linkedVault, commonIn_);
        try IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, commonIn_, tokenB, 0, address(this), false, block.timestamp
        ) {} catch {}
    }

    /// @dev Deploy a second vault instance with a distinct salt (same package / markets; rates off).
    function _deploySecondVault(bytes32 salt_) internal returns (address vault2_) {
        return _deployVaultWithArgs(
            "Dual Liquidity CVU Vault 2", "dlCVU2", 0.2e18, 0.2e18, 0.6e18, false, salt_
        );
    }

    /// @dev Deploy a vault instance with explicit weights, rate policy, and salt (registry path).
    function _deployVaultWithArgs(
        string memory name_,
        string memory symbol_,
        uint256 weightA_,
        uint256 weightB_,
        uint256 weightPair_,
        bool useRateProviders_,
        bytes32 salt_
    ) internal returns (address vault_) {
        IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgArgs memory pkgArgs =
            IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgArgs({
                name: name_,
                symbol: symbol_,
                commonToken: IERC20(address(commonToken)),
                tokenA: IERC20(address(tokenA)),
                tokenB: IERC20(address(tokenB)),
                poolKeyA: _poolKey(commonToken, tokenA),
                widthMultiplierA: WIDTH_MULTIPLIER,
                poolKeyB: _poolKey(commonToken, tokenB),
                widthMultiplierB: WIDTH_MULTIPLIER,
                pairPool: pair,
                weightA: weightA_,
                weightB: weightB_,
                weightPair: weightPair_,
                useRateProviders: useRateProviders_,
                optionalSalt: salt_
            });
        vm.prank(owner);
        vault_ = indexedexManager.deployVault(IStandardVaultPkg(address(linkedVaultPkg)), abi.encode(pkgArgs));
    }
}
