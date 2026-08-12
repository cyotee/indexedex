// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
// IVault used in _fundReserveBpt for live balances length
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {IRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {
    IMixedBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol";
import {
    MixedBufferMultiVaultStablePool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePool_FactoryService.sol";
import {
    BalancerV3ConstantProductPool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";
import {
    DefaultPoolInfoFacet
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/DefaultPoolInfoFacet.sol";
import {
    StandardSwapFeePercentageBoundsFacet
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardSwapFeePercentageBoundsFacet.sol";
import {
    StandardUnbalancedLiquidityInvariantRatioBoundsFacet
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardUnbalancedLiquidityInvariantRatioBoundsFacet.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    IMixedBufferMultiVaultStableDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";
import {
    MixedBufferMultiVaultStableDetf_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf_Component_FactoryService.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";
import {
    SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol";
import {
    SingleStandardExchangeDETF_Pkg_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Pkg_FactoryService.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {WeightedPoolFactory} from
    "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";

/// @title TestBase_MixedBufferMultiVaultStableDetf
/// @notice Production MixedBuffer multi-vault stable DETF against production Aerodrome SE legs (shared DAI buffer).
abstract contract TestBase_MixedBufferMultiVaultStableDetf is TestBase_BalancerV3StandardExchangeRouter {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using MixedBufferMultiVaultStableDetf_Component_FactoryService for ICreate3FactoryProxy;
    using MixedBufferMultiVaultStableDetf_Component_FactoryService for IVaultRegistryDeployment;
    using MixedBufferMultiVaultStablePool_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;
    uint256 internal constant BOOTSTRAP_BUFFER = 1_000e18;
    uint256 internal constant BOOTSTRAP_SHARE_FUND = 1_000e18;
    uint256 internal constant MBMVS_AMP = 200;

    function _warpPastUnlock(address instance_, uint256 tokenId_) internal {
        address nft_ = IMixedBufferMultiVaultStableDetfInfo(instance_).bondNftVault();
        uint256 unlock_ = IDETFNFTVault(nft_).unlockTimeOf(tokenId_);
        if (block.timestamp <= unlock_) {
            vm.warp(unlock_ + 1);
        }
    }

    IFacet internal multiAssetBasicVaultFacetDetf;
    IFacet internal multiAssetStandardVaultFacetDetf;
    IFacet internal mixedBufferDetfExchangeInFacet;
    IFacet internal mixedBufferDetfBondingFacet;
    IFacet internal mixedBufferDetfInfoFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal erc721Facet;
    IFacet internal singleSeDetfExchangeInFacet;

    // MixedBuffer pool package facets
    IFacet internal mbmvsBufferPoolFacet;
    IFacet internal mbmvsPoolLiquidityFacet;
    IFacet internal mbmvsHookFacet;
    IFacet internal balancerV3VaultAwareFacet;
    IFacet internal betterBalancerV3PoolTokenFacet;
    IFacet internal defaultPoolInfoFacet;
    IFacet internal standardSwapFeePercentageBoundsFacet;
    IFacet internal unbalancedLiquidityInvariantRatioBoundsFacet;
    IFacet internal balancerV3AuthenticationFacet;
    IFacet internal multiAssetBasicVaultFacetPool;
    IFacet internal multiAssetStandardVaultFacetPool;

    IMixedBufferMultiVaultStablePoolPkg internal mbmvsPkg;
    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IDetfSelfNftInventoryDFPkg internal bondNftVaultPkg;
    IRebasingClaimTokenDFPkg internal rebasingClaimTokenPkg;
    IMixedBufferMultiVaultStableDetfDFPkg internal mixedBufferDetfPkg;
    ISingleStandardExchangeDETDFPkg internal singleSeDetfPkg;

    // SE vault legs sharing DAI buffer
    IStandardExchangeProxy[3] internal seVaults;
    IERC20[3] internal seShares;
    address[3] internal legTokenA;
    address[3] internal legTokenB;
    uint8 internal seVaultReady;

    address internal detf;
    IMixedBufferMultiVaultStableDetfInfo internal detfInfo;
    IMixedBufferMultiVaultStableDetfBonding internal detfBonding;
    IStandardExchangeIn internal detfExchangeIn;

    function setUp() public virtual override {
        super.setUp();

        multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();
        mixedBufferDetfExchangeInFacet =
            MixedBufferMultiVaultStableDetf_Component_FactoryService.deployExchangeInFacet(create3Factory);
        mixedBufferDetfBondingFacet =
            MixedBufferMultiVaultStableDetf_Component_FactoryService.deployBondingFacet(create3Factory);
        mixedBufferDetfInfoFacet =
            MixedBufferMultiVaultStableDetf_Component_FactoryService.deployInfoFacet(create3Factory);
        singleSeDetfExchangeInFacet =
            SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);

        _deployMixedBufferPoolPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployMixedBufferDetfPkg();
        _deploySingleSeDetfPkg();

        // Seed N=1 SE vault from router TestBase daiUsdcVault
        seVaults[0] = daiUsdcVault;
        seShares[0] = IERC20(address(daiUsdcVault));
        legTokenA[0] = address(dai);
        legTokenB[0] = address(usdc);
        seVaultReady = 1;

        detf = _deployDetfN(1, 0, 0);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
    }

    /* ---------------------------------------------------------------------- */
    /*                    MixedBuffer pool package                            */
    /* ---------------------------------------------------------------------- */

    function _deployMixedBufferPoolPkg() internal {
        multiAssetBasicVaultFacetPool = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetPool = create3Factory.deployMultiAssetStandardVaultFacet();
        balancerV3VaultAwareFacet =
            BalancerV3ConstantProductPool_FactoryService.deployBalancerV3VaultAwareFacet(create3Factory);
        betterBalancerV3PoolTokenFacet =
            BalancerV3ConstantProductPool_FactoryService.deployBalancerV3PoolTokenFacet(create3Factory);
        balancerV3AuthenticationFacet =
            BalancerV3ConstantProductPool_FactoryService.deployBalancerV3AuthenticationFacet(create3Factory);

        defaultPoolInfoFacet = IFacet(address(new DefaultPoolInfoFacet()));
        standardSwapFeePercentageBoundsFacet = IFacet(address(new StandardSwapFeePercentageBoundsFacet()));
        unbalancedLiquidityInvariantRatioBoundsFacet =
            IFacet(address(new StandardUnbalancedLiquidityInvariantRatioBoundsFacet()));

        mbmvsBufferPoolFacet =
            MixedBufferMultiVaultStablePool_FactoryService.deployMixedBufferMultiVaultStablePoolFacet(create3Factory);
        mbmvsPoolLiquidityFacet = MixedBufferMultiVaultStablePool_FactoryService
            .deployMixedBufferMultiVaultStableLiquidityFacet(create3Factory);
        mbmvsHookFacet =
            MixedBufferMultiVaultStablePool_FactoryService.deployMixedBufferMultiVaultStableHookFacet(create3Factory);

        // Optional rate provider pkg (never auto-deployed for share legs by DETF package).
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("MixedBufferDetf_RateProviderFacet")
            )
        );
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(
                        IStandardExchangeRateProviderDFPkg.PkgInit({
                            rateProviderFacet: rateProviderFacet,
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    keccak256("MixedBufferDetf_RateProviderDFPkg")
                )
            )
        );

        IMixedBufferMultiVaultStablePoolPkg.PkgInit memory pkgInit;
        pkgInit.basicVaultFacet = multiAssetBasicVaultFacetPool;
        pkgInit.standardVaultFacet = multiAssetStandardVaultFacetPool;
        pkgInit.balancerV3VaultAwareFacet = balancerV3VaultAwareFacet;
        pkgInit.betterBalancerV3PoolTokenFacet = betterBalancerV3PoolTokenFacet;
        pkgInit.defaultPoolInfoFacet = defaultPoolInfoFacet;
        pkgInit.standardSwapFeePercentageBoundsFacet = standardSwapFeePercentageBoundsFacet;
        pkgInit.unbalancedLiquidityInvariantRatioBoundsFacet = unbalancedLiquidityInvariantRatioBoundsFacet;
        pkgInit.balancerV3AuthenticationFacet = balancerV3AuthenticationFacet;
        pkgInit.bufferPoolFacet = mbmvsBufferPoolFacet;
        pkgInit.poolLiquidityFacet = mbmvsPoolLiquidityFacet;
        pkgInit.hookFacet = mbmvsHookFacet;
        pkgInit.vaultRegistry = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.balancerV3Vault = IVault(address(vault));
        pkgInit.diamondFactory = diamondPackageFactory;
        pkgInit.rateProviderPkg = rateProviderPkg;

        vm.startPrank(owner);
        mbmvsPkg = MixedBufferMultiVaultStablePool_FactoryService.deployMixedBufferMultiVaultStablePoolPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(mbmvsPkg), "MixedBufferMultiVaultStablePkg");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Bond / claim / DETF packages                   */
    /* ---------------------------------------------------------------------- */

    function _deployBondNftVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode, keccak256("MixedBufferDetf_ERC721Facet")
            )
        );

        IDETFNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        bondNftVaultPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployDETFNFTVaultDFPkg(nftPkgInit);
        vm.stopPrank();
    }

    function _deployRebasingClaimTokenPkg() internal {
        IFacet claimFacet_ = create3Factory.deployRebasingClaimTokenFacet();
        rebasingClaimTokenPkg = create3Factory.deployRebasingClaimTokenDFPkg(
            DetfComponentFactoryService.buildRICHIRPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
            )
        );
    }

    function _deployMixedBufferDetfPkg() internal {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgInit memory pkgInit = IMixedBufferMultiVaultStableDetfDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: mixedBufferDetfExchangeInFacet,
            bondingFacet: mixedBufferDetfBondingFacet,
            infoFacet: mixedBufferDetfInfoFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            mixedBufferPoolPkg: mbmvsPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            diamondFactory: diamondPackageFactory
        });

        vm.startPrank(owner);
        mixedBufferDetfPkg = MixedBufferMultiVaultStableDetf_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(mixedBufferDetfPkg), "MixedBufferMultiVaultStableDetfDFPkg");
    }

    function _deploySingleSeDetfPkg() internal {
        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit = ISingleStandardExchangeDETDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: singleSeDetfExchangeInFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            weightedPoolFactory: WeightedPoolFactory(testPoolFactory),
            rateProviderPkg: rateProviderPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            diamondFactory: diamondPackageFactory
        });
        vm.startPrank(owner);
        singleSeDetfPkg = SingleStandardExchangeDETF_Pkg_FactoryService.deploySingleStandardExchangeDETDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                    Production SE vault inventory                       */
    /* ---------------------------------------------------------------------- */

    function _ensureSeVaults(uint8 n) internal {
        require(n >= 1 && n <= 3, "n out of range");
        while (seVaultReady < n) {
            _deployExtraDaiSeVault(seVaultReady);
            unchecked {
                ++seVaultReady;
            }
        }
    }

    /// @dev Extra SE vaults that accept DAI as buffer with distinct second assets.
    function _deployExtraDaiSeVault(uint8 idx) internal {
        if (idx == 0) return; // already set from daiUsdcVault
        address tokenA = address(dai);
        address tokenB = idx == 1 ? address(weth) : address(usdc);
        // For idx 2 use a fresh MockERC20 pair with DAI to avoid PoolAlreadyExists if usdc already used.
        if (idx == 2) {
            MockERC20 extra = new MockERC20("ExtraB", "EXB", 18);
            tokenB = address(extra);
        }
        address poolAddr = aerodromePoolFactory.createPool(tokenA, tokenB, false);
        Pool(poolAddr);
        vm.label(poolAddr, string.concat("AeroDaiPair_", vm.toString(uint256(idx))));

        uint256 amt = AERODROME_POOL_INIT_AMOUNT;
        _mintToken(tokenA, address(this), amt);
        _mintToken(tokenB, address(this), amt);
        IERC20(tokenA).approve(address(aerodromeRouter), amt);
        IERC20(tokenB).approve(address(aerodromeRouter), amt);
        aerodromeRouter.addLiquidity(tokenA, tokenB, false, amt, amt, 1, 1, address(this), block.timestamp + 1 hours);

        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(poolAddr));
        seVaults[idx] = IStandardExchangeProxy(vaultAddr);
        seShares[idx] = IERC20(vaultAddr);
        legTokenA[idx] = tokenA;
        legTokenB[idx] = tokenB;
        vm.label(vaultAddr, string.concat("SeVault_dai_", vm.toString(uint256(idx))));
    }

    function _mintToken(address token_, address to_, uint256 amount_) internal {
        if (token_ == address(weth)) {
            vm.deal(to_, amount_ + 1 ether);
            vm.prank(to_);
            weth.deposit{value: amount_}();
            return;
        }
        (bool ok,) = token_.call(abi.encodeWithSignature("mint(address,uint256)", to_, amount_));
        if (!ok) {
            MockERC20(token_).mint(to_, amount_);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         DETF instance deploys                          */
    /* ---------------------------------------------------------------------- */

    function _deployDetfN(uint8 n, uint256 mintThreshold_, uint256 burnThreshold_)
        internal
        returns (address detf_)
    {
        return _deployDetfN(n, mintThreshold_, burnThreshold_, ThresholdMode.Policy);
    }

    function _deployDetfN(uint8 n, uint256 mintThreshold_, uint256 burnThreshold_, ThresholdMode mode_)
        internal
        returns (address detf_)
    {
        _ensureSeVaults(n);
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args =
            _buildPkgArgs(n, mintThreshold_, burnThreshold_, mode_);
        detf_ = _deployWithArgs(args);
        vm.label(detf_, string.concat("MixedBufferDetf_N", vm.toString(uint256(n))));
    }

    function _buildPkgArgs(uint8 n, uint256 mintTh_, uint256 burnTh_)
        internal
        view
        returns (IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args)
    {
        return _buildPkgArgs(n, mintTh_, burnTh_, ThresholdMode.Policy);
    }

    function _buildPkgArgs(uint8 n, uint256 mintTh_, uint256 burnTh_, ThresholdMode mode_)
        internal
        view
        returns (IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args)
    {
        args.name = string.concat("MBMV Detf N", vm.toString(uint256(n)));
        args.symbol = string.concat("mbmvd", vm.toString(uint256(n)));
        args.bufferToken = IERC20(address(dai));
        args.standardExchangeVaults = new IStandardExchange[](n);
        args.vaultShareRateProviders = new IRateProvider[](n);
        for (uint8 i; i < n; ++i) {
            args.standardExchangeVaults[i] = IStandardExchange(address(seVaults[i]));
            args.vaultShareRateProviders[i] = IRateProvider(address(0));
        }
        args.amplificationParameter = MBMVS_AMP;
        args.mintThreshold = mintTh_;
        args.burnThreshold = burnTh_;
        args.thresholdMode = mode_;
    }

    function _deployWithArgs(IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args)
        internal
        returns (address detf_)
    {
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    /// @dev Product Open (always-allow thresholds when live). Replaces illegal mint=1/burn=max dual-path.
    function _deployOpenThresholdDetfN(uint8 n) internal returns (address) {
        return _deployOpenModeDetfN(n);
    }

    /// @dev Product Open mode + resolved default thresholds (0,0).
    function _deployOpenModeDetfN(uint8 n) internal returns (address) {
        return _deployDetfN(n, 0, 0, ThresholdMode.Open);
    }

    /// @dev Legal extreme Policy pair (mint > burn). Not product Open.
    function _deployExtremePolicyPairDetfN(uint8 n) internal returns (address) {
        return _deployDetfN(n, 2, 1, ThresholdMode.Policy);
    }

    /// @dev Explicit Policy thresholds.
    function _deployPolicyThresholdsN(uint8 n, uint256 mintThreshold_, uint256 burnThreshold_)
        internal
        returns (address)
    {
        return _deployDetfN(n, mintThreshold_, burnThreshold_, ThresholdMode.Policy);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Fund / bootstrap helpers                       */
    /* ---------------------------------------------------------------------- */

    function _fundBuffer(address to, uint256 amount) internal {
        _mintToken(address(dai), to, amount);
    }

    function _fundVaultShares(uint8 leg, address to, uint256 tokenAmount)
        internal
        returns (uint256 shares_)
    {
        require(leg < seVaultReady, "leg");
        address tokenA = legTokenA[leg];
        address tokenB = legTokenB[leg];
        _mintToken(tokenA, to, tokenAmount);
        _mintToken(tokenB, to, tokenAmount);
        vm.startPrank(to);
        IERC20(tokenA).approve(address(aerodromeRouter), tokenAmount);
        IERC20(tokenB).approve(address(aerodromeRouter), tokenAmount);
        (,, uint256 liquidity) = aerodromeRouter.addLiquidity(
            tokenA, tokenB, false, tokenAmount, tokenAmount, 1, 1, to, block.timestamp + 1 hours
        );
        address asset_ = seVaults[leg].asset();
        IERC20(asset_).approve(address(seVaults[leg]), liquidity);
        shares_ = seVaults[leg].deposit(liquidity, to);
        vm.stopPrank();
    }

    function _bootstrapFirstBond(address instance_, address user, uint256 bufferAmt, uint256 shareFundAmt)
        internal
        returns (uint256 tokenId_, uint256 bptPrincipal_, uint256 freeDetf_)
    {
        uint256 n_ = IMixedBufferMultiVaultStableDetfInfo(instance_).vaultCount();
        uint256[] memory shareAmts_ = new uint256[](n_);
        for (uint8 i; i < n_; ++i) {
            shareAmts_[i] = _fundVaultShares(i, user, shareFundAmt);
        }
        _fundBuffer(user, bufferAmt);

        address[] memory shareTokens_ = IMixedBufferMultiVaultStableDetfInfo(instance_).vaultShares();
        IERC20 buffer_ = IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());

        vm.startPrank(user);
        buffer_.approve(instance_, bufferAmt);
        for (uint256 i; i < n_; ++i) {
            IERC20(shareTokens_[i]).approve(instance_, shareAmts_[i]);
        }
        (tokenId_, bptPrincipal_, freeDetf_) = IMixedBufferMultiVaultStableDetfBonding(instance_).bootstrapFirstBond(
            bufferAmt, shareAmts_, DEFAULT_MIN_LOCK, user, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _bootstrapDefault(address instance_, address user)
        internal
        returns (uint256 tokenId_, uint256 bpt_, uint256 freeDetf_)
    {
        return _bootstrapFirstBond(instance_, user, BOOTSTRAP_BUFFER, BOOTSTRAP_SHARE_FUND);
    }

    function _mintDetfFromBuffer(address instance_, address user, uint256 bufferAmt)
        internal
        returns (uint256 out_)
    {
        IERC20 buffer_ = IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());
        _fundBuffer(user, bufferAmt);
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(buffer_, bufferAmt, IERC20(instance_));
        vm.startPrank(user);
        buffer_.approve(instance_, bufferAmt);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            buffer_, bufferAmt, IERC20(instance_), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(preview_, out_, "mint buffer preview==exec");
    }

    function _mintDetfFromVaultShare(address instance_, uint8 leg, address user, uint256 fundAmt)
        internal
        returns (uint256 out_)
    {
        uint256 shares_ = _fundVaultShares(leg, user, fundAmt);
        address shareToken_ = IMixedBufferMultiVaultStableDetfInfo(instance_).vaultShares()[leg];
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(IERC20(shareToken_), shares_, IERC20(instance_));
        vm.startPrank(user);
        IERC20(shareToken_).approve(instance_, shares_);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(shareToken_), shares_, IERC20(instance_), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(preview_, out_, "mint share preview==exec");
    }

    function _burnDetfToBuffer(address instance_, address user, uint256 detfAmount_)
        internal
        returns (uint256 out_)
    {
        IERC20 buffer_ = IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(IERC20(instance_), detfAmount_, buffer_);
        vm.startPrank(user);
        IERC20(instance_).approve(instance_, detfAmount_);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), detfAmount_, buffer_, 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        // Proportional multi-leg exit + rejoin: same closed-form order as MultiVault (≤10 wei preferred).
        assertApproxEqAbs(preview_, out_, 10, "burn buffer preview==exec (le 10 wei)");
    }

    /// @dev Obtain reserve BPT for `user` via Balancer RouterMock unbalanced join (buffer + DETF self).
    ///      seRouter prepay is DETF-operator-only; external users use the vault RouterMock path.
    function _fundReserveBpt(address instance_, address user, uint256 bufferAmt)
        internal
        returns (uint256 bptOut_)
    {
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(instance_);
        address pool_ = info_.reservePool();
        IERC20 buffer_ = IERC20(info_.bufferToken());
        // Mint free DETF for the DETF leg of the join.
        uint256 detfAmt_ = _mintDetfFromBuffer(instance_, user, bufferAmt);
        // Additional buffer for the buffer leg.
        _fundBuffer(user, bufferAmt);

        uint256 n_ = IVault(address(vault)).getCurrentLiveBalances(pool_).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[info_.bufferIndex()] = bufferAmt;
        amountsIn_[info_.detfIndex()] = detfAmt_;

        vm.startPrank(user);
        buffer_.approve(address(permit2), type(uint256).max);
        IERC20(instance_).approve(address(permit2), type(uint256).max);
        permit2.approve(address(buffer_), address(router), type(uint160).max, type(uint48).max);
        permit2.approve(instance_, address(router), type(uint160).max, type(uint48).max);
        // RouterMock pulls via permit2 and mints BPT to user.
        bptOut_ = router.addLiquidityUnbalanced(pool_, amountsIn_, 0, false, bytes(""));
        vm.stopPrank();
        require(bptOut_ > 0, "bpt funded");
        require(IERC20(pool_).balanceOf(user) >= bptOut_, "user holds bpt");
    }

    /// @dev Real trade on underlying Aerodrome pool of SE leg (price-shift suites).
    function _shiftUnderlyingPrice(uint8 leg, bool buyTokenB, uint256 amountIn) internal {
        address tokenA = legTokenA[leg];
        address tokenB = legTokenB[leg];
        address trader = bob;
        address tokenIn_ = buyTokenB ? tokenA : tokenB;
        address tokenOut_ = buyTokenB ? tokenB : tokenA;
        _mintToken(tokenIn_, trader, amountIn);
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: tokenIn_,
            to: tokenOut_,
            stable: false,
            factory: address(aerodromePoolFactory)
        });
        vm.startPrank(trader);
        IERC20(tokenIn_).approve(address(aerodromeRouter), amountIn);
        aerodromeRouter.swapExactTokensForTokens(amountIn, 0, routes, trader, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _assertInert(address instance_) internal view {
        assertFalse(IMixedBufferMultiVaultStableDetfInfo(instance_).isReserveLive(), "expected inert");
    }

    function _assertLive(address instance_) internal view {
        assertTrue(IMixedBufferMultiVaultStableDetfInfo(instance_).isReserveLive(), "expected live");
        assertTrue(IMixedBufferMultiVaultStableDetfInfo(instance_).reservePool() != address(0), "pool");
    }

    function _assertNoFreeInventory(address instance_) internal view {
        assertLe(IERC20(instance_).balanceOf(instance_), 1, "residual free detf");
        IERC20 buffer_ = IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());
        assertLe(buffer_.balanceOf(instance_), 1, "residual free buffer");
        address[] memory shares_ = IMixedBufferMultiVaultStableDetfInfo(instance_).vaultShares();
        for (uint256 i; i < shares_.length; ++i) {
            assertLe(IERC20(shares_[i]).balanceOf(instance_), 1, "residual vault share");
        }
    }

    function _feeTo() internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    /* ---------------------------------------------------------------------- */
    /*                     Protocol compound test helpers                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Enable non-zero seigniorage so mint/bond produce inventory DETF on the bond vault.
    function _enableSeigniorageIncentive(address instance_, uint256 incentiveWad_) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(
            instance_, incentiveWad_
        );
        vm.stopPrank();
    }

    function _bondNftVault(address instance_) internal view returns (IDETFNFTVault) {
        return IDETFNFTVault(IMixedBufferMultiVaultStableDetfInfo(instance_).bondNftVault());
    }

    function _detfNftId(address instance_) internal view returns (uint256) {
        return _bondNftVault(instance_).detfNFTId();
    }

    /// @dev Protocol NFT principal (BPT share units) — claim rate path depends on this rising after compound.
    function _protocolNftPrincipal(address instance_) internal view returns (uint256) {
        IDETFNFTVault vault_ = _bondNftVault(instance_);
        return vault_.originalSharesOf(vault_.detfNFTId());
    }

    function _protocolPendingRewards(address instance_) internal view returns (uint256) {
        IDETFNFTVault vault_ = _bondNftVault(instance_);
        return vault_.pendingRewards(vault_.detfNFTId());
    }

    /// @dev Bootstrap open-mode MixedBuffer DETF, sell first bond into protocol NFT so it has principal
    ///      shares, then create a second locked user bond and seed inventory via mint (seigniorage on).
    /// @return instance_ Open-mode DETF diamond.
    /// @return userBondId_ Second user bond still locked (for C3 claim-while-locked).
    function _setupProtocolRewardsLive(address bonder_, address minter_)
        internal
        returns (address instance_, uint256 userBondId_)
    {
        instance_ = _deployOpenModeDetfN(1);
        // 20% seigniorage incentive → inventory = afterFee * 10% (half of incentive).
        _enableSeigniorageIncentive(instance_, 0.20e18);

        // First bootstrap bond → live; sell to protocol so detf NFT earns reward share.
        (uint256 firstId_,,) = _bootstrapFirstBond(instance_, bonder_, 500e18, 500e18);
        _warpPastUnlock(instance_, firstId_);
        vm.prank(bonder_);
        IMixedBufferMultiVaultStableDetfBonding(instance_).sellPositionToDetfNft(firstId_, 0, bonder_);
        assertGt(_protocolNftPrincipal(instance_), 0, "protocol nft has principal after sell");

        // Second buffer bond: user keeps NFT (for claim-while-locked). Keep modest vs pool.
        _fundBuffer(bonder_, 100e18);
        vm.startPrank(bonder_);
        IERC20(address(dai)).approve(instance_, 100e18);
        (userBondId_,) = IMixedBufferMultiVaultStableDetfBonding(instance_).bond(
            IERC20(address(dai)), 100e18, DEFAULT_MIN_LOCK, bonder_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        // Mint seigniorage with inventory DETF into bond vault reward pool.
        _mintDetfFromBuffer(instance_, minter_, 50e18);
    }

    /// @dev Seed extra free DETF inventory on the bond vault (forces reward balance without another mint).
    ///      **Adds** to existing vault balance (does not set absolute) so `lastRewardTokenBalance`
    ///      accounting stays consistent with inventory already deposited via production mint/bond.
    function _seedBondVaultRewardDetf(address instance_, uint256 amount_) internal {
        address vault_ = address(_bondNftVault(instance_));
        uint256 before_ = IERC20(instance_).balanceOf(vault_);
        // Non-SUT controllability: forge deal adjusts ERC20 balance + totalSupply.
        deal(instance_, vault_, before_ + amount_, true);
    }

    /* ---------------------------------------------------------------------- */
    /*                     Natural expansion test helpers                     */
    /* ---------------------------------------------------------------------- */

    function _warp(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    /// @dev Deploy Policy N=1 with WITH_RATE on leg0 so underlying Aerodrome trades move synthetic.
    function _deployPolicyWithRateNamed(string memory name_, string memory symbol_)
        internal
        returns (address detf_)
    {
        _ensureSeVaults(1);
        IRateProvider rp_ = rateProviderPkg.deployRateProvider(
            IStandardExchange(address(seVaults[0])), seShares[0], IERC20(address(dai))
        );
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args =
            _buildPkgArgs(1, 0, 0, ThresholdMode.Policy);
        args.name = name_;
        args.symbol = symbol_;
        args.vaultShareRateProviders[0] = rp_;
        // Explicit zeros → lib defaults (document deploy-time expansion fields).
        args.expansionClosureRatePerSecond = 0;
        args.expansionCatchUpMaxSeconds = 0;
        args.expansionCatchUpCapBps = 0;
        detf_ = _deployWithArgs(args);
        vm.label(detf_, name_);
    }

    /// @dev Drive synthetic above mint threshold under **default Policy** via real underlying trades.
    ///      Requires WITH_RATE share leg (see `_deployPolicyWithRateNamed`).
    function _pushSyntheticAboveMintThreshold(address instance_) internal {
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(instance_);
        require(info_.isReserveLive(), "must be live");
        if (info_.isMintingAllowed()) return;

        for (uint256 i; i < 20 && !info_.isMintingAllowed(); ++i) {
            _shiftUnderlyingPrice(0, true, 20_000e18 * (i + 1));
            if (info_.isMintingAllowed()) return;
            _shiftUnderlyingPrice(0, false, 20_000e18 * (i + 1));
        }
        require(info_.isMintingAllowed(), "could not open mint under default thresholds");
    }

    /// @dev Live Policy MixedBuffer with locked user bond + protocol NFT principal (for expansion/compound).
    /// @dev Does **not** push synthetic here (caller runs `_pushSyntheticAboveMintThreshold` when needed).
    function _setupPolicyExpansionLive(address bonder_, address helper_)
        internal
        returns (address instance_, uint256 userBondId_)
    {
        instance_ = _deployPolicyWithRateNamed("Natural Expansion MBMVS DETF", "neMBMVS");
        _enableSeigniorageIncentive(instance_, 0.20e18);

        // Bootstrap → live; sell first bond into protocol NFT so it has principal shares.
        (uint256 firstId_,,) = _bootstrapFirstBond(instance_, bonder_, 500e18, 500e18);
        _warpPastUnlock(instance_, firstId_);
        vm.prank(bonder_);
        IMixedBufferMultiVaultStableDetfBonding(instance_).sellPositionToDetfNft(firstId_, 0, bonder_);
        assertGt(_protocolNftPrincipal(instance_), 0, "protocol nft has principal after sell");

        // Second buffer bond: user keeps NFT (for claim-while-locked + reward share).
        _fundBuffer(bonder_, 100e18);
        vm.startPrank(bonder_);
        IERC20(address(dai)).approve(instance_, 100e18);
        (userBondId_,) = IMixedBufferMultiVaultStableDetfBonding(instance_).bond(
            IERC20(address(dai)), 100e18, DEFAULT_MIN_LOCK, bonder_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(
            _bondNftVault(instance_).effectiveSharesOf(userBondId_),
            0,
            "user bond has effective shares"
        );

        // Seed expansion clock touch is safe at dt≈0 after live seed.
        IMixedBufferMultiVaultStableDetfInfo(instance_).compoundProtocolRewards();

        helper_; // reserved for multi-actor suites
    }

    /// @dev Expected max expansion mint under resolved defaults for given supply (bps cap).
    function _maxExpansionMintDefault(uint256 totalSupply_) internal pure returns (uint256) {
        return (totalSupply_ * DETFNaturalExpansionLib.DEFAULT_CATCH_UP_CAP_BPS) / 10_000;
    }
}
