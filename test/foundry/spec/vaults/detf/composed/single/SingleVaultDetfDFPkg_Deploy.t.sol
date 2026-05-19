// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    PoolRoleAccounts,
    TokenConfig
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {
    WeightedPool8020Factory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {
    SingleVaultDetf_Component_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Component_FactoryService.sol";
import {ISingleVaultDetfDFPkg} from "contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol";
import {
    SingleVaultDetf_Facet_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Facet_FactoryService.sol";
import {
    SingleVaultDetf_Pkg_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Pkg_FactoryService.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {
    BaseProtocolDETF_Component_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/protocols/l2s/superchain/registries/token/bridge/ISuperChainBridgeTokenRegistry.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
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
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";

contract SingleVaultDetfDFPkg_Deploy_Test is TestBase_BalancerV3StandardExchangeRouter {
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

    uint256 internal constant TEST_TOKEN_TOTAL_SUPPLY = 10_000_000e18;

    IERC20 internal wethToken;
    IERC20 internal richToken;

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
    IProtocolNFTVaultDFPkg internal protocolNFTVaultPkg;
    IWeightedPool8020Factory internal weightedPool8020Factory;
    PoolManager internal poolManager;
    ERC20PermitDFPkg internal erc20PermitPkg;

    function setUp() public override {
        super.setUp();

        _deployTestTokenPkg();
        wethToken = _deployTestToken("Wrapped Ether", "WETH", keccak256("SingleVaultDetfDeploy_WETH"));
        richToken = _deployTestToken("Rich Token", "RICH", keccak256("SingleVaultDetfDeploy_RICH"));
        poolManager = new PoolManager(address(this));
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();

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
                bridgeTokenRegistry: ISuperChainBridgeTokenRegistry(address(0)),
                standardBridge: IStandardBridge(payable(address(0))),
                messenger: ICrossDomainMessenger(address(0)),
                localRelayer: address(0),
                peerRelayer: address(0),
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
        vm.stopPrank();
    }

    function test_packageMetadata_matchesExpectedFacets() public view {
        (string memory name_, bytes4[] memory interfaces_, address[] memory facets_) = singleVaultDetfDFPkg.packageMetadata();

        assertEq(name_, "SingleVaultDetfDFPkg", "package name");
        assertEq(interfaces_.length, 10, "interface count");
        assertEq(facets_.length, 9, "facet count");

        assertEq(facets_[0], address(erc20Facet), "erc20 facet");
        assertEq(facets_[1], address(erc5267Facet), "erc5267 facet");
        assertEq(facets_[2], address(erc2612Facet), "erc2612 facet");
        assertEq(facets_[3], address(multiAssetBasicVaultFacet), "multi asset basic facet");
        assertEq(facets_[4], address(multiAssetStandardVaultFacet), "multi asset standard facet");
        assertEq(facets_[5], address(singleVaultDetfExchangeInFacet), "exchange in facet");
        assertEq(facets_[6], address(singleVaultDetfExchangeInQueryFacet), "exchange in query facet");
        assertEq(facets_[7], address(singleVaultDetfExchangeOutFacet), "exchange out facet");
        assertEq(facets_[8], address(singleVaultDetfBondingFacet), "bonding facet");
    }

    function test_deployVault_registersVaultAndInitializesConfig() public {
        ISingleVaultDetfDFPkg.PkgArgs memory pkgArgs = SingleVaultDetf_Component_FactoryService.buildPkgArgs(
            "Single Vault DETF",
            "SVDETF",
            richToken,
            10_000e18,
            1_000e18,
            _buildPoolKey(),
            60
        );

        vm.startPrank(owner);
        address detfAddr = indexedexManager.deployVault(IStandardVaultPkg(address(singleVaultDetfDFPkg)), abi.encode(pkgArgs));
        vm.stopPrank();

        assertTrue(detfAddr != address(0), "vault deployed");
        assertTrue(indexedexManager.isVault(detfAddr), "vault registered");

        address[] memory vaultsOfPkg = indexedexManager.vaultsOfPackage(address(singleVaultDetfDFPkg));
        assertEq(vaultsOfPkg.length, 1, "package vault count");
        assertEq(vaultsOfPkg[0], detfAddr, "package vault address");

        ISingleVaultDetf detf = ISingleVaultDetf(detfAddr);
        address derivedReservePool = detf.reservePool();
        address[] memory expectedTokens = new address[](3);
        expectedTokens[0] = detfAddr;
        expectedTokens[1] = address(detf.wethRichVault());
        expectedTokens[2] = derivedReservePool;

        IStandardVault.VaultConfig memory config = IStandardVault(detfAddr).vaultConfig();
        assertEq(config.tokens.length, 3, "config token count");
        assertEq(config.tokens[0], expectedTokens[0], "config token0");
        assertEq(config.tokens[1], expectedTokens[1], "config token1");
        assertEq(config.tokens[2], expectedTokens[2], "config token2");
        assertEq(config.vaultTypes.length, 10, "vault types count");
        assertEq(config.contentsId, indexedexManager.calcContentsId(expectedTokens), "contents id");

        assertEq(IERC20Metadata(detfAddr).name(), "Single Vault DETF", "name");
        assertEq(IERC20Metadata(detfAddr).symbol(), "SVDETF", "symbol");
        assertEq(address(detf.richToken()), address(richToken), "rich token");
        assertEq(address(detf.wethToken()), address(wethToken), "weth token");
        assertTrue(indexedexManager.isVault(address(detf.wethRichVault())), "weth/rich vault registered");
        assertTrue(indexedexManager.isVault(address(detf.protocolNFTVault())), "protocol nft vault registered");
        assertEq(indexedexManager.vaultsOfPackage(address(wethRichVaultPkg)).length, 1, "weth/rich vault pkg count");
        assertEq(indexedexManager.vaultsOfPackage(address(protocolNFTVaultPkg)).length, 1, "protocol nft vault pkg count");
        assertTrue(address(detf.vaultRateProvider()) != address(0), "rate provider deployed");
        assertTrue(detf.reservePool() != address(0), "reserve pool deployed");
        assertEq(detf.protocolNFTId(), detf.protocolNFTVault().protocolNFTId(), "protocol nft id");
        assertTrue(address(detf.richirToken()) != address(0), "richir token");

        IRICHIR richirToken_ = IRICHIR(address(detf.richirToken()));
        assertEq(richirToken_.protocolDETF(), detfAddr, "richir protocol detf");
        assertEq(address(richirToken_.wethToken()), address(wethToken), "richir weth token");
        assertEq(richirToken_.protocolNFTId(), detf.protocolNFTId(), "richir protocol nft id");

        (uint256 chirIndex_, uint256 vaultTokenIndex_) = detf.reservePoolIndexes();
        uint256 expectedChirIndex = detfAddr < address(detf.wethRichVault()) ? 0 : 1;
        uint256 expectedVaultTokenIndex = expectedChirIndex == 0 ? 1 : 0;
        assertEq(chirIndex_, expectedChirIndex, "chir index");
        assertEq(vaultTokenIndex_, expectedVaultTokenIndex, "vault token index");

        assertEq(detf.mintThreshold(), 1005e15, "mint threshold");
        assertEq(detf.burnThreshold(), 995e15, "burn threshold");
        assertTrue(detf.isAcceptedBondToken(wethToken), "weth accepted");
        assertTrue(detf.isAcceptedBondToken(richToken), "rich accepted");
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

    function _deployProtocolNFTVaultPkg() internal {
        protocolNFTVaultFacet = create3Factory.deployProtocolNFTVaultFacet();
        IFacet erc721Facet =
            IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SingleVaultDetf_ERC721Facet")));

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

    function test_processArgs_reverts_whenNotRegistry() public {
        ISingleVaultDetfDFPkg.PkgArgs memory pkgArgs = SingleVaultDetf_Component_FactoryService.buildPkgArgs(
            "Single Vault DETF",
            "SVDETF",
            richToken,
            1,
            1,
            _buildPoolKey(),
            60
        );

        vm.expectRevert(abi.encodeWithSelector(ISingleVaultDetfDFPkg.NotCalledByRegistry.selector, address(this)));
        singleVaultDetfDFPkg.processArgs(abi.encode(pkgArgs));
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
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "SingleVaultDetfDeploy"))
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
}