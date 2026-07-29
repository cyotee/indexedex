// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IFacetRegistry} from "@crane/contracts/registries/facet/IFacetRegistry.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {
    WeightedPool8020Factory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
import {
    SuperChainBridgeTokenRegistryFactoryService
} from "@crane/contracts/protocols/l2s/superchain/registries/token/bridge/SuperChainBridgeTokenRegistryFactoryService.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {UniswapV4_Component_FactoryService} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {
    SingleVaultDetf_Component_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Component_FactoryService.sol";
import {
    ISingleVaultDetfDFPkg
} from "contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol";
import {
    SingleVaultDetf_Facet_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Facet_FactoryService.sol";
import {
    SingleVaultDetf_Pkg_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Pkg_FactoryService.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/claimToken/RebasingClaimTokenDFPkg.sol";
import {DetfSuperchainBridgeRepo} from "contracts/vaults/detf/DetfSuperchainBridgeRepo.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/reusable/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/reusable/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/reusable/DetfPkgFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/bondNft/DETFNFTVaultDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";

contract SingleVaultDetfUniswapV4LiquiditySeeder is IUnlockCallback {
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

abstract contract SingleVaultDetfProductionBase is TestBase_BalancerV3StandardExchangeRouter {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using SingleVaultDetf_Facet_FactoryService for ICreate3FactoryProxy;
    using SingleVaultDetf_Pkg_FactoryService for IVaultRegistryDeployment;
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    uint256 internal constant MIN_LOCK_DURATION = 30 days;

    uint256 internal constant TEST_TOKEN_TOTAL_SUPPLY = 10_000_000e18;

    IERC20 internal rateAsset;
    IERC20 internal pairToken;

    IFacet internal multiAssetBasicVaultFacet;
    IFacet internal multiAssetStandardVaultFacet;
    IFacet internal singleVaultDetfExchangeInFacet;
    IFacet internal singleVaultDetfExchangeInQueryFacet;
    IFacet internal singleVaultDetfInfoFacet;
    IFacet internal singleVaultDetfExchangeOutFacet;
    IFacet internal singleVaultDetfBondingFacet;
    IFacet internal operableFacet;
    IFacet internal rebasingClaimTokenFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal uniswapV4StandardExchangeInFacet;
    IFacet internal uniswapV4StandardExchangeInQueryFacet;
    IFacet internal uniswapV4StandardExchangePositionImportFacet;
    IFacet internal uniswapV4StandardExchangeOutFacet;

    ISingleVaultDetfDFPkg internal singleVaultDetfDFPkg;
    IRebasingClaimTokenDFPkg internal richirDFPkg;
    IUniswapV4StandardExchangeDFPkg internal underlyingVaultPkg;
    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IDetfSelfNftInventoryDFPkg internal detfNFTVaultPkg;
    IWeightedPool8020Factory internal weightedPool8020Factory;
    PoolManager internal poolManager;
    SingleVaultDetfUniswapV4LiquiditySeeder internal liquiditySeeder;
    ERC20PermitDFPkg internal erc20PermitPkg;

    function setUp() public virtual override {
        super.setUp();

        _deployTestTokenPkg();
        rateAsset = _deployTestToken("Wrapped Ether", "WETH", keccak256("SingleVaultDetf_WETH"));
        pairToken = _deployTestToken("Rich Token", "RICH", keccak256("SingleVaultDetf_RICH"));
        poolManager = new PoolManager(address(this));
        liquiditySeeder = new SingleVaultDetfUniswapV4LiquiditySeeder(poolManager);
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();

        _seedWethRichPool();

        _deployWeightedPool8020Factory();
        _deployStandardExchangeRateProviderPkg();
        _deployDETFNFTVaultPkg();
        _deployUniswapV4StandardExchangePkg();

        singleVaultDetfExchangeInFacet = create3Factory.deploySingleVaultDetfExchangeInFacet();
        singleVaultDetfExchangeInQueryFacet = create3Factory.deploySingleVaultDetfExchangeInQueryFacet();
        singleVaultDetfInfoFacet = create3Factory.deploySingleVaultDetfInfoFacet();
        singleVaultDetfExchangeOutFacet = create3Factory.deploySingleVaultDetfExchangeOutFacet();
        singleVaultDetfBondingFacet = create3Factory.deploySingleVaultDetfBondingFacet();
        operableFacet = create3Factory.deployOperableFacet();
        rebasingClaimTokenFacet = create3Factory.deployRebasingClaimTokenFacet();

        richirDFPkg = create3Factory.deployRebasingClaimTokenDFPkg(
            IRebasingClaimTokenDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                rebasingClaimTokenFacet: rebasingClaimTokenFacet,
                diamondFactory: diamondPackageFactory
            })
        );
    }

    /// @notice Default Policy + 0,0 → product ±5% after resolve.
    function _deploySingleVaultDetf() internal returns (ISingleVaultDetf detf_) {
        return _deploySingleVaultDetf(_emptyBridgeConfig(), 0, 0, ThresholdMode.Policy);
    }

    /// @notice Product Open mode (always-allow gates when live; thresholds still resolved/stored).
    function _deployOpenModeDetf() internal returns (ISingleVaultDetf detf_) {
        return _deploySingleVaultDetf(_emptyBridgeConfig(), 0, 0, ThresholdMode.Open);
    }

    function _deploySingleVaultDetf(DetfSuperchainBridgeRepo.BridgeConfig memory bridgeConfig_)
        internal
        returns (ISingleVaultDetf detf_)
    {
        return _deploySingleVaultDetf(bridgeConfig_, 0, 0, ThresholdMode.Policy);
    }

    function _deploySingleVaultDetf(
        uint256 mintThreshold_,
        uint256 burnThreshold_,
        ThresholdMode thresholdMode_
    ) internal returns (ISingleVaultDetf detf_) {
        return _deploySingleVaultDetf(_emptyBridgeConfig(), mintThreshold_, burnThreshold_, thresholdMode_);
    }

    function _deploySingleVaultDetf(
        DetfSuperchainBridgeRepo.BridgeConfig memory bridgeConfig_,
        uint256 mintThreshold_,
        uint256 burnThreshold_,
        ThresholdMode thresholdMode_
    ) internal returns (ISingleVaultDetf detf_) {
        SingleVaultDetf_Component_FactoryService.SingleVaultDetfFacets memory facets =
            SingleVaultDetf_Component_FactoryService.SingleVaultDetfFacets({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                exchangeInFacet: singleVaultDetfExchangeInFacet,
                exchangeInQueryFacet: singleVaultDetfExchangeInQueryFacet,
                infoFacet: singleVaultDetfInfoFacet,
                exchangeOutFacet: singleVaultDetfExchangeOutFacet,
                bondingFacet: singleVaultDetfBondingFacet,
                operableFacet: operableFacet
            });

        SingleVaultDetf_Component_FactoryService.SingleVaultDetfInfra memory infra =
            SingleVaultDetf_Component_FactoryService.SingleVaultDetfInfra({
                feeOracle: indexedexManager,
                vaultRegistryDeployment: indexedexManager,
                permit2: permit2,
                rateAsset: rateAsset,
                balancerV3Vault: IBalancerVault(address(vault)),
                balancerV3PrepayRouter: seRouter,
                weightedPool8020Factory: weightedPool8020Factory,
                bridgeTokenRegistry: bridgeConfig_.bridgeTokenRegistry,
                standardBridge: bridgeConfig_.standardBridge,
                messenger: bridgeConfig_.messenger,
                localRelayer: bridgeConfig_.localRelayer,
                peerRelayer: bridgeConfig_.peerRelayer,
                underlyingVaultPkg: underlyingVaultPkg,
                detfNFTVaultPkg: detfNFTVaultPkg,
                rebasingClaimTokenPkg: richirDFPkg,
                rateProviderPkg: rateProviderPkg,
                diamondFactory: diamondPackageFactory
            });

        vm.startPrank(owner);
        // Deploy DFPkg once; reuse for additional vault instances (Open/Policy variants).
        // Second CREATE3 package deploy with identical init reverts NOT_AUTHORIZED / salt collision.
        if (address(singleVaultDetfDFPkg) == address(0)) {
            singleVaultDetfDFPkg = IVaultRegistryDeployment(address(indexedexManager)).deploySingleVaultDetfDFPkg(
                SingleVaultDetf_Component_FactoryService.buildPkgInit(facets, infra)
            );
        }

        ISingleVaultDetfDFPkg.PkgArgs memory pkgArgs = SingleVaultDetf_Component_FactoryService.buildPkgArgs(
            "Single Vault DETF",
            "SVDETF",
            pairToken,
            10_000e18,
            1_000e18,
            _buildPoolKey(),
            60,
            mintThreshold_,
            burnThreshold_,
            thresholdMode_
        );

        detf_ = ISingleVaultDetf(
            indexedexManager.deployVault(IStandardVaultPkg(address(singleVaultDetfDFPkg)), abi.encode(pkgArgs))
        );
        vm.stopPrank();
    }

    function _deployBridgeRegistry(address owner_) internal returns (ISuperChainBridgeTokenRegistry registry_) {
        IFacet ownableFacet = IFacetRegistry(address(create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId);
        IFacet operableRegistryFacet = IFacetRegistry(address(create3Factory)).canonicalFacet(type(IOperable).interfaceId);

        registry_ = SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistry(
            diamondPackageFactory,
            SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryDFPkg(
                create3Factory,
                ownableFacet,
                operableRegistryFacet,
                SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryFacet(create3Factory)
            ),
            owner_
        );
    }

    function _emptyBridgeConfig() internal pure returns (DetfSuperchainBridgeRepo.BridgeConfig memory config_) {
        config_ = DetfSuperchainBridgeRepo.BridgeConfig({
            bridgeTokenRegistry: ISuperChainBridgeTokenRegistry(address(0)),
            standardBridge: IStandardBridge(payable(address(0))),
            messenger: ICrossDomainMessenger(address(0)),
            localRelayer: address(0),
            peerRelayer: address(0)
        });
    }

    function _deployWeightedPool8020Factory() internal {
        bytes memory initArgs =
            abi.encode(IBalancerVault(address(vault)), uint32(365 days), "Factory v1", "8020Pool v1");

        address factoryAddr = create3Factory.create3WithArgs(
            type(WeightedPool8020Factory).creationCode,
            initArgs,
            keccak256("SingleVaultDetfWeightedPool8020Factory")
        );
        weightedPool8020Factory = IWeightedPool8020Factory(factoryAddr);
        vm.label(factoryAddr, "SingleVaultDetfWeightedPool8020Factory");
    }

    function _deployStandardExchangeRateProviderPkg() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("SingleVaultDetf_StandardExchangeRateProviderFacet")
            )
        );

        IStandardExchangeRateProviderDFPkg.PkgInit memory pkgInit = IStandardExchangeRateProviderDFPkg.PkgInit({
            rateProviderFacet: rateProviderFacet,
            diamondFactory: diamondPackageFactory
        });

        rateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256("SingleVaultDetf_StandardExchangeRateProviderDFPkg")
                )
            )
        );
        vm.label(address(rateProviderPkg), "SingleVaultDetf_StandardExchangeRateProviderDFPkg");
    }

    function _deployDETFNFTVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        IFacet erc721Facet = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SingleVaultDetf_ERC721Facet"))
        );

        IDETFNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService
            .buildDETFNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        detfNFTVaultPkg = IVaultRegistryDeployment(address(indexedexManager)).deployDETFNFTVaultDFPkg(nftPkgInit);
        vm.stopPrank();
    }

    function _deployUniswapV4StandardExchangePkg() internal {
        uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4StandardExchangeInFacet();
        uniswapV4StandardExchangeInQueryFacet = create3Factory.deployUniswapV4StandardExchangeInQueryFacet();
        uniswapV4StandardExchangePositionImportFacet = create3Factory.deployUniswapV4StandardExchangePositionImportFacet();
        uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4StandardExchangeOutFacet();

        vm.startPrank(owner);
        underlyingVaultPkg = indexedexManager.deployUniswapV4StandardExchangeDFPkg(
            erc20Facet.buildArgsUniswapV4StandardExchangePkgInit(
                erc5267Facet,
                erc2612Facet,
                multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet,
                uniswapV4StandardExchangeInFacet,
                uniswapV4StandardExchangeInQueryFacet,
                uniswapV4StandardExchangePositionImportFacet,
                uniswapV4StandardExchangeOutFacet,
                indexedexManager,
                indexedexManager,
                permit2,
                poolManager
            )
        );
        vm.stopPrank();
    }

    function _buildPoolKey() internal view returns (PoolKey memory poolKey_) {
        (address token0, address token1) = address(rateAsset) < address(pairToken)
            ? (address(rateAsset), address(pairToken))
            : (address(pairToken), address(rateAsset));

        poolKey_ = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _seedWethRichPool() internal {
        PoolKey memory poolKey = _buildPoolKey();

        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));
        _fundWeth(address(liquiditySeeder), 100_000 ether);
        _fundRich(address(liquiditySeeder), 100_000 ether);
        liquiditySeeder.addLiquidity(
            poolKey,
            -60,
            60,
            LiquidityAmounts.getLiquidityForAmounts(
                TickMath.getSqrtPriceAtTick(0),
                TickMath.getSqrtPriceAtTick(-60),
                TickMath.getSqrtPriceAtTick(60),
                100_000 ether,
                100_000 ether
            )
        );
    }

    function _deployTestTokenPkg() internal {
        IERC20PermitDFPkg.PkgInit memory pkgInit = IERC20PermitDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet
        });

        erc20PermitPkg = ERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "SingleVaultDetf"))
                )
            )
        );
    }

    function _deployTestToken(string memory name_, string memory symbol_, bytes32 salt_) internal returns (IERC20 token_) {
        IERC20PermitDFPkg.PkgArgs memory pkgArgs = IERC20PermitDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            decimals: 18,
            totalSupply: TEST_TOKEN_TOTAL_SUPPLY,
            recipient: address(this),
            optionalSalt: salt_
        });

        token_ = IERC20(diamondPackageFactory.deploy(IDiamondFactoryPackage(address(erc20PermitPkg)), abi.encode(pkgArgs)));
    }

    function _fundWeth(address recipient_, uint256 amount_) internal {
        rateAsset.transfer(recipient_, amount_);
    }

    function _fundRich(address recipient_, uint256 amount_) internal {
        pairToken.transfer(recipient_, amount_);
    }
}