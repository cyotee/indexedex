// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

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
import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
import {
    SuperChainBridgeTokenRegistryFactoryService
} from "@crane/contracts/protocols/l2s/superchain/registries/token/bridge/SuperChainBridgeTokenRegistryFactoryService.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {BASE_SEPOLIA} from "@crane/contracts/constants/networks/BASE_SEPOLIA.sol";
import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
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
import {
    ISingleVaultDetfBonding
} from "contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {
    BaseProtocolDETF_Component_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {ITokenTransferRelayer} from "@crane/contracts/protocols/l2s/superchain/relayers/token/ITokenTransferRelayer.sol";

interface IOptimismMintableERC20Factory {
    function createOptimismMintableERC20(address remoteToken, string memory name, string memory symbol)
        external
        returns (address);
}

contract SingleVaultDetfForkLiquiditySeeder is IUnlockCallback {
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

abstract contract SingleVaultDetfBridgeForkBase is TestBase_BalancerV3StandardExchangeRouter {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Facet_FactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Pkg_FactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Pkg_FactoryService for IVaultRegistryDeployment;
    using SingleVaultDetf_Facet_FactoryService for ICreate3FactoryProxy;
    using SingleVaultDetf_Pkg_FactoryService for IVaultRegistryDeployment;
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    uint256 internal constant MIN_LOCK_DURATION = 30 days;

    uint256 internal constant TEST_TOKEN_TOTAL_SUPPLY = 10_000_000e18;

    IERC20 internal wethToken;
    IERC20 internal richToken;
    address internal richRemoteToken;

    IFacet internal multiAssetBasicVaultFacet;
    IFacet internal multiAssetStandardVaultFacet;
    IFacet internal singleVaultDetfExchangeInFacet;
    IFacet internal singleVaultDetfExchangeInQueryFacet;
    IFacet internal singleVaultDetfExchangeOutFacet;
    IFacet internal singleVaultDetfBondingFacet;
    IFacet internal operableFacet;
    IFacet internal richirFacet;
    IFacet internal protocolNFTVaultFacet;
    IFacet internal uniswapV4StandardExchangeInFacet;
    IFacet internal uniswapV4StandardExchangeOutFacet;

    ISingleVaultDetfDFPkg internal singleVaultDetfDFPkg;
    IRICHIRDFPkg internal richirDFPkg;
    IUniswapV4StandardExchangeDFPkg internal wethRichVaultPkg;
    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IDetfSelfNftInventoryDFPkg internal protocolNFTVaultPkg;
    IWeightedPool8020Factory internal weightedPool8020Factory;
    PoolManager internal poolManager;
    SingleVaultDetfForkLiquiditySeeder internal liquiditySeeder;
    uint256 internal forkId;
    ERC20PermitDFPkg internal erc20PermitPkg;

    function setUp() public virtual override {
        forkId = vm.createFork("base_sepolia_alchemy", BASE_SEPOLIA.DEFAULT_FORK_BLOCK);
        vm.selectFork(forkId);

        TestBase_BalancerV3StandardExchangeRouter.setUp();

        _deployTestTokenPkg();
        wethToken = _deployTestToken("Wrapped Ether", "WETH", keccak256("SingleVaultDetfBridge_WETH"));
        richRemoteToken = makeAddr("ethereumSepoliaRich");
        richToken = IERC20(
            IOptimismMintableERC20Factory(BASE_SEPOLIA.OPTIMISM_MINTABLE_ERC20_FACTORY).createOptimismMintableERC20(
                richRemoteToken,
                "RICH Base Sepolia",
                "RICH.base"
            )
        );
        poolManager = new PoolManager(address(this));
        liquiditySeeder = new SingleVaultDetfForkLiquiditySeeder(poolManager);
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();

        _seedWethRichPool();

        _deployWeightedPool8020Factory();
        _deployStandardExchangeRateProviderPkg();
        _deployProtocolNFTVaultPkg();
        _deployUniswapV4StandardExchangePkg();

        singleVaultDetfExchangeInFacet = create3Factory.deploySingleVaultDetfExchangeInFacet();
        singleVaultDetfExchangeInQueryFacet = create3Factory.deploySingleVaultDetfExchangeInQueryFacet();
        singleVaultDetfExchangeOutFacet = create3Factory.deploySingleVaultDetfExchangeOutFacet();
        singleVaultDetfBondingFacet = create3Factory.deploySingleVaultDetfBondingFacet();
        operableFacet = create3Factory.deployOperableFacet();
        richirFacet = create3Factory.deployRICHIRFacet();

        richirDFPkg = create3Factory.deployRICHIRDFPkg(
            IRICHIRDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                richirFacet: richirFacet,
                diamondFactory: diamondPackageFactory
            })
        );
    }

    function _deploySingleVaultDetf(ProtocolDETFSuperchainBridgeRepo.BridgeConfig memory bridgeConfig_)
        internal
        returns (ISingleVaultDetf detf_)
    {
        SingleVaultDetf_Component_FactoryService.SingleVaultDetfFacets memory facets =
            SingleVaultDetf_Component_FactoryService.SingleVaultDetfFacets({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                exchangeInFacet: singleVaultDetfExchangeInFacet,
                exchangeInQueryFacet: singleVaultDetfExchangeInQueryFacet,
                exchangeOutFacet: singleVaultDetfExchangeOutFacet,
                bondingFacet: singleVaultDetfBondingFacet,
                operableFacet: operableFacet
            });

        SingleVaultDetf_Component_FactoryService.SingleVaultDetfInfra memory infra =
            SingleVaultDetf_Component_FactoryService.SingleVaultDetfInfra({
                feeOracle: indexedexManager,
                vaultRegistryDeployment: indexedexManager,
                permit2: permit2,
                wethToken: wethToken,
                balancerV3Vault: IBalancerVault(address(vault)),
                balancerV3PrepayRouter: seRouter,
                weightedPool8020Factory: weightedPool8020Factory,
                bridgeTokenRegistry: bridgeConfig_.bridgeTokenRegistry,
                standardBridge: bridgeConfig_.standardBridge,
                messenger: bridgeConfig_.messenger,
                localRelayer: bridgeConfig_.localRelayer,
                peerRelayer: bridgeConfig_.peerRelayer,
                wethRichVaultPkg: wethRichVaultPkg,
                protocolNFTVaultPkg: protocolNFTVaultPkg,
                richirPkg: richirDFPkg,
                rateProviderPkg: rateProviderPkg,
                diamondFactory: diamondPackageFactory
            });

        vm.startPrank(owner);
        singleVaultDetfDFPkg = IVaultRegistryDeployment(address(indexedexManager)).deploySingleVaultDetfDFPkg(
            SingleVaultDetf_Component_FactoryService.buildPkgInit(facets, infra)
        );

        ISingleVaultDetfDFPkg.PkgArgs memory pkgArgs = SingleVaultDetf_Component_FactoryService.buildPkgArgs(
            "Single Vault DETF",
            "SVDETF",
            richToken,
            10_000e18,
            1_000e18,
            _buildPoolKey(),
            60
        );

        detf_ = ISingleVaultDetf(
            indexedexManager.deployVault(IStandardVaultPkg(address(singleVaultDetfDFPkg)), abi.encode(pkgArgs))
        );
        vm.stopPrank();
    }

    function _deployBridgeRegistry(address owner_) internal returns (ISuperChainBridgeTokenRegistry registry_) {
        IFacet ownableFacet = IFacetRegistry(address(create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId);
        IFacet bridgeOperableFacet = IFacetRegistry(address(create3Factory)).canonicalFacet(type(IOperable).interfaceId);

        registry_ = SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistry(
            diamondPackageFactory,
            SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryDFPkg(
                create3Factory,
                ownableFacet,
                bridgeOperableFacet,
                SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryFacet(create3Factory)
            ),
            owner_
        );
    }

    function _deployWeightedPool8020Factory() internal {
        bytes memory initArgs =
            abi.encode(IBalancerVault(address(vault)), uint32(365 days), "Factory v1", "8020Pool v1");

        address factoryAddr = create3Factory.create3WithArgs(
            type(WeightedPool8020Factory).creationCode,
            initArgs,
            keccak256("SingleVaultDetfBridgeWeightedPool8020Factory")
        );
        weightedPool8020Factory = IWeightedPool8020Factory(factoryAddr);
        vm.label(factoryAddr, "SingleVaultDetfBridgeWeightedPool8020Factory");
    }

    function _deployStandardExchangeRateProviderPkg() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("SingleVaultDetfBridge_StandardExchangeRateProviderFacet")
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
                    keccak256("SingleVaultDetfBridge_StandardExchangeRateProviderDFPkg")
                )
            )
        );
    }

    function _deployProtocolNFTVaultPkg() internal {
        protocolNFTVaultFacet = create3Factory.deployProtocolNFTVaultFacet();
        IFacet erc721Facet = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SingleVaultDetfBridge_ERC721Facet"))
        );

        IProtocolNFTVaultDFPkg.PkgInit memory nftPkgInit = BaseProtocolDETF_Component_FactoryService
            .buildProtocolNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            protocolNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        protocolNFTVaultPkg = IVaultRegistryDeployment(address(indexedexManager)).deployProtocolNFTVaultDFPkg(nftPkgInit);
        vm.stopPrank();
    }

    function _deployUniswapV4StandardExchangePkg() internal {
        uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4StandardExchangeInFacet();
        uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4StandardExchangeOutFacet();

        vm.startPrank(owner);
        wethRichVaultPkg = indexedexManager.deployUniswapV4StandardExchangeDFPkg(
            erc20Facet.buildArgsUniswapV4StandardExchangePkgInit(
                erc5267Facet,
                erc2612Facet,
                multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet,
                uniswapV4StandardExchangeInFacet,
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
        (address token0, address token1) = address(wethToken) < address(richToken)
            ? (address(wethToken), address(richToken))
            : (address(richToken), address(wethToken));

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
        deal(address(richToken), address(liquiditySeeder), 100_000 ether, true);
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
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "SingleVaultDetfBridge"))
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
        wethToken.transfer(recipient_, amount_);
    }
}

contract SingleVaultDetf_BridgeTransport_Test is SingleVaultDetfBridgeForkBase {
    uint256 internal constant TARGET_CHAIN_ID = ETHEREUM_SEPOLIA.CHAIN_ID;
    uint256 internal constant BRIDGE_MIN_GAS_LIMIT = 120_000;
    uint32 internal constant MESSAGE_GAS_LIMIT = 250_000;

    bytes32 internal constant TOPIC_ERC20_BRIDGE_INITIATED =
        keccak256("ERC20BridgeInitiated(address,address,address,address,uint256,bytes)");
    bytes32 internal constant TOPIC_SENT_MESSAGE =
        keccak256("SentMessage(address,address,bytes,uint256,uint256)");

    struct ERC20BridgeInitiatedLog {
        address localToken;
        address remoteToken;
        address from;
        address to;
        uint256 amount;
        bytes extraData;
    }

    struct SentMessageLog {
        address target;
        address sender;
        bytes message;
        uint256 messageNonce;
        uint256 gasLimit;
    }

    struct MessengerRelayEnvelope {
        uint256 nonce;
        address sender;
        address target;
        uint256 value;
        uint256 minGasLimit;
        bytes message;
    }

    ISingleVaultDetf internal detf;
    ISuperChainBridgeTokenRegistry internal bridgeRegistry;

    address internal detfAlice = makeAddr("detfAlice");
    address internal localRelayer = makeAddr("localRelayer");
    address internal peerRelayer = makeAddr("peerRelayer");
    address internal recipient = makeAddr("recipient");
    IERC20 internal remoteDetf = IERC20(makeAddr("remoteDetf"));

    function setUp() public override {
        super.setUp();

        bridgeRegistry = _deployBridgeRegistry(address(this));
        detf = _deploySingleVaultDetf(
            ProtocolDETFSuperchainBridgeRepo.BridgeConfig({
                bridgeTokenRegistry: bridgeRegistry,
                standardBridge: IStandardBridge(payable(BASE_SEPOLIA.L2_STANDARD_BRIDGE)),
                messenger: ICrossDomainMessenger(BASE_SEPOLIA.L2_CROSSDOMAIN_MESSENGER),
                localRelayer: localRelayer,
                peerRelayer: peerRelayer
            })
        );

        bridgeRegistry.setRemoteToken(TARGET_CHAIN_ID, IERC20(address(detf)), remoteDetf, 0);
        bridgeRegistry.setRemoteToken(TARGET_CHAIN_ID, richToken, IERC20(richRemoteToken), BRIDGE_MIN_GAS_LIMIT);

        _fundWeth(detfAlice, 10_000e18);
    }

    function test_previewBridgeRichir_matchesExecution_withRealBaseSepoliaBridge() public {
        uint256 richirMinted = _mintRichirFromBondSale(5_000e18);
        uint256 bridgeAmount = richirMinted / 2;
        if (bridgeAmount == 0) {
            bridgeAmount = richirMinted;
        }

        IProtocolDETF.BridgeQuote memory quote = detf.previewBridgeRichir(TARGET_CHAIN_ID, bridgeAmount);
        vm.recordLogs();
        vm.startPrank(detfAlice);
        IERC20(address(detf.richirToken())).approve(address(detf), bridgeAmount);
        (uint256 localRichirOut, uint256 richOut) = detf.bridgeRichir(
            IProtocolDETF.BridgeArgs({
                targetChainId: TARGET_CHAIN_ID,
                richirAmount: bridgeAmount,
                recipient: recipient,
                minLocalRichirOut: 0,
                minRichOut: 0,
                messageGasLimit: MESSAGE_GAS_LIMIT,
                deadline: block.timestamp + 1 hours
            })
        );
        vm.stopPrank();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(quote.richirAmountIn, bridgeAmount, "quote amount in");
        assertGt(quote.sharesBurned, 0, "quote shares burned");
        assertGt(quote.reserveSharesBurned, 0, "quote reserve burned");
        assertGt(localRichirOut, 0, "local richir out");
        assertGt(quote.localRichirOut, 0, "quoted local richir out");
        assertApproxEqAbs(richOut, quote.richOut, 1e14, "rich out matches quote");

        (ERC20BridgeInitiatedLog memory bridgeCall, bool foundBridgeCall) =
            _findERC20BridgeInitiatedLog(logs, BASE_SEPOLIA.L2_STANDARD_BRIDGE, address(detf), peerRelayer);
        assertTrue(foundBridgeCall, "bridge event missing");
        assertEq(bridgeCall.localToken, address(richToken), "bridge local token");
        assertEq(bridgeCall.remoteToken, richRemoteToken, "bridge remote token");
        assertEq(bridgeCall.to, peerRelayer, "bridge recipient");
        assertEq(bridgeCall.amount, richOut, "bridge amount");

        (SentMessageLog memory bridgeMessage, bool foundBridgeMessage) = _findSentMessageLog(
            logs,
            BASE_SEPOLIA.L2_CROSSDOMAIN_MESSENGER,
            BASE_SEPOLIA.L2_STANDARD_BRIDGE,
            address(IStandardBridge(payable(BASE_SEPOLIA.L2_STANDARD_BRIDGE)).OTHER_BRIDGE())
        );
        assertTrue(foundBridgeMessage, "bridge messenger event missing");
        assertEq(bridgeMessage.gasLimit, BRIDGE_MIN_GAS_LIMIT, "bridge min gas");
        assertEq(bytes4(bridgeMessage.message), IStandardBridge.finalizeBridgeERC20.selector, "bridge selector");

        (SentMessageLog memory relayMessage, bool foundRelayMessage) = _findSentMessageLog(
            logs,
            BASE_SEPOLIA.L2_CROSSDOMAIN_MESSENGER,
            address(detf),
            peerRelayer
        );
        assertTrue(foundRelayMessage, "relay messenger event missing");
        assertEq(relayMessage.target, peerRelayer, "relay target");
        assertEq(relayMessage.gasLimit, MESSAGE_GAS_LIMIT, "relay gas limit");
        assertEq(relayMessage.sender, address(detf), "relay sender");
        assertEq(bytes4(relayMessage.message), ITokenTransferRelayer.relayTokenTransfer.selector, "relay selector");
    }

    function test_receiveBridgedRich_reverts_forNonRelayer() public {
        vm.expectRevert(
            abi.encodeWithSelector(IProtocolDETFErrors.NotBridgeRelayer.selector, detfAlice, localRelayer)
        );
        vm.prank(detfAlice);
        detf.receiveBridgedRich(recipient, 1e18, block.timestamp + 1 hours);
    }

    function test_receiveBridgedRich_pullsRichFromRelayer_andMintsRichir() public {
        _mintRichirFromBondSale(5_000e18);

        uint256 richAmount = 100e18;
        uint256 previewOut = IStandardExchangeIn(address(detf)).previewExchangeIn(
            richToken,
            richAmount,
            IERC20(address(detf.richirToken()))
        );

        deal(address(richToken), localRelayer, richAmount, true);
        vm.startPrank(localRelayer);
        richToken.approve(address(detf), richAmount);
        uint256 richirOut = detf.receiveBridgedRich(recipient, richAmount, block.timestamp + 1 hours);
        vm.stopPrank();

        assertGt(richirOut, 0, "richir out");
        assertGe(richirOut, previewOut, "preview lower bound");
        assertEq(richToken.balanceOf(localRelayer), 0, "relayer rich spent");
        assertEq(detf.richirToken().balanceOf(recipient), richirOut, "recipient richir balance");
    }

    function _mintRichirFromBondSale(uint256 wethAmount_) internal returns (uint256 richirMinted_) {
        vm.startPrank(detfAlice);
        wethToken.approve(address(detf), wethAmount_);
        (uint256 tokenId,) = ISingleVaultDetfBonding(address(detf)).bond(
            wethToken,
            wethAmount_,
            MIN_LOCK_DURATION,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        richirMinted_ = ISingleVaultDetfBonding(address(detf)).sellNFT(tokenId, detfAlice);
        vm.stopPrank();
    }

    function _findERC20BridgeInitiatedLog(
        Vm.Log[] memory logs_,
        address emitter_,
        address from_,
        address to_
    ) internal pure returns (ERC20BridgeInitiatedLog memory log_, bool found_) {
        for (uint256 i = 0; i < logs_.length; ++i) {
            Vm.Log memory entry = logs_[i];
            if (entry.emitter != emitter_ || entry.topics.length != 4 || entry.topics[0] != TOPIC_ERC20_BRIDGE_INITIATED) {
                continue;
            }

            (address to, uint256 amount, bytes memory extraData) = abi.decode(entry.data, (address, uint256, bytes));
            address from = _topicAddress(entry.topics[3]);
            if (from != from_ || to != to_) {
                continue;
            }

            log_ = ERC20BridgeInitiatedLog({
                localToken: _topicAddress(entry.topics[1]),
                remoteToken: _topicAddress(entry.topics[2]),
                from: from,
                to: to,
                amount: amount,
                extraData: extraData
            });
            found_ = true;
            return (log_, found_);
        }
    }

    function _findSentMessageLog(Vm.Log[] memory logs_, address emitter_, address sender_, address target_)
        internal
        pure
        returns (SentMessageLog memory log_, bool found_)
    {
        for (uint256 i = 0; i < logs_.length; ++i) {
            Vm.Log memory entry = logs_[i];
            if (entry.emitter != emitter_ || entry.topics.length != 2 || entry.topics[0] != TOPIC_SENT_MESSAGE) {
                continue;
            }

            address target = _topicAddress(entry.topics[1]);
            (address sender, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
                abi.decode(entry.data, (address, bytes, uint256, uint256));
            if (sender != sender_ || target != target_) {
                continue;
            }

            log_ = SentMessageLog({
                target: target,
                sender: sender,
                message: message,
                messageNonce: messageNonce,
                gasLimit: gasLimit
            });
            found_ = true;
            return (log_, found_);
        }
    }

    function _decodeMessengerRelayEnvelope(bytes memory message_)
        internal
        pure
        returns (MessengerRelayEnvelope memory envelope_)
    {
        bytes memory tail = _dropSelector(message_);
        (
            envelope_.nonce,
            envelope_.sender,
            envelope_.target,
            envelope_.value,
            envelope_.minGasLimit,
            envelope_.message
        ) = abi.decode(tail, (uint256, address, address, uint256, uint256, bytes));
    }

    function _dropSelector(bytes memory data_) internal pure returns (bytes memory tail_) {
        tail_ = new bytes(data_.length - 4);
        for (uint256 i = 4; i < data_.length; ++i) {
            tail_[i - 4] = data_[i];
        }
    }

    function _topicAddress(bytes32 topic_) internal pure returns (address) {
        return address(uint160(uint256(topic_)));
    }
}