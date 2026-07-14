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
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
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
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/protocol/RebasingClaimTokenDFPkg.sol";
import {DetfSuperchainBridgeRepo} from "contracts/vaults/detf/DetfSuperchainBridgeRepo.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/reusable/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/reusable/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/reusable/DetfPkgFactoryService.sol";
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
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/protocol/DETFNFTVaultDFPkg.sol";

contract SingleVaultDetfDFPkg_Deploy_Test is TestBase_BalancerV3StandardExchangeRouter {
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
    ERC20PermitDFPkg internal erc20PermitPkg;

    function setUp() public override {
        super.setUp();

        _deployTestTokenPkg();
        rateAsset = _deployTestToken("Wrapped Ether", "WETH", keccak256("SingleVaultDetfDeploy_WETH"));
        pairToken = _deployTestToken("Rich Token", "RICH", keccak256("SingleVaultDetfDeploy_RICH"));
        poolManager = new PoolManager(address(this));
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();

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
                bridgeTokenRegistry: ISuperChainBridgeTokenRegistry(address(0)),
                standardBridge: IStandardBridge(payable(address(0))),
                messenger: ICrossDomainMessenger(address(0)),
                localRelayer: address(0),
                peerRelayer: address(0),
                underlyingVaultPkg: underlyingVaultPkg,
                detfNFTVaultPkg: detfNFTVaultPkg,
                rebasingClaimTokenPkg: richirDFPkg,
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
        assertEq(facets_.length, 10, "facet count");

        assertEq(facets_[0], address(erc20Facet), "erc20 facet");
        assertEq(facets_[1], address(erc5267Facet), "erc5267 facet");
        assertEq(facets_[2], address(erc2612Facet), "erc2612 facet");
        assertEq(facets_[3], address(multiAssetBasicVaultFacet), "multi asset basic facet");
        assertEq(facets_[4], address(multiAssetStandardVaultFacet), "multi asset standard facet");
        assertEq(facets_[5], address(singleVaultDetfExchangeInFacet), "exchange in facet");
        assertEq(facets_[6], address(singleVaultDetfExchangeInQueryFacet), "exchange in query facet");
        assertEq(facets_[7], address(singleVaultDetfInfoFacet), "info facet");
        assertEq(facets_[8], address(singleVaultDetfExchangeOutFacet), "exchange out facet");
        assertEq(facets_[9], address(singleVaultDetfBondingFacet), "bonding facet");
    }

    function test_deployVault_registersVaultAndInitializesConfig() public {
        ISingleVaultDetfDFPkg.PkgArgs memory pkgArgs = SingleVaultDetf_Component_FactoryService.buildPkgArgs(
            "Single Vault DETF",
            "SVDETF",
            pairToken,
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
        expectedTokens[1] = address(detf.underlyingVault());
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
        assertEq(address(detf.pairToken()), address(pairToken), "rich token");
        assertEq(address(detf.rateAsset()), address(rateAsset), "weth token");
        assertTrue(indexedexManager.isVault(address(detf.underlyingVault())), "weth/rich vault registered");
        assertTrue(indexedexManager.isVault(address(detf.detfNFTVault())), "protocol nft vault registered");
        assertEq(indexedexManager.vaultsOfPackage(address(underlyingVaultPkg)).length, 1, "weth/rich vault pkg count");
        assertEq(indexedexManager.vaultsOfPackage(address(detfNFTVaultPkg)).length, 1, "protocol nft vault pkg count");
        assertTrue(address(detf.vaultRateProvider()) != address(0), "rate provider deployed");
        assertTrue(detf.reservePool() != address(0), "reserve pool deployed");
        assertEq(detf.detfNFTId(), detf.detfNFTVault().detfNFTId(), "protocol nft id");
        assertTrue(address(detf.rebasingClaimToken()) != address(0), "richir token");

        IRebasingClaimToken rebasingClaimToken_ = IRebasingClaimToken(address(detf.rebasingClaimToken()));
        assertEq(rebasingClaimToken_.protocolDETF(), detfAddr, "richir protocol detf");
        assertEq(address(rebasingClaimToken_.rateAsset()), address(rateAsset), "richir weth token");
        assertEq(rebasingClaimToken_.detfNFTId(), detf.detfNFTId(), "richir protocol nft id");

        (uint256 detfIndex_, uint256 vaultTokenIndex_) = detf.reservePoolIndexes();
        uint256 expectedDetfIndex = detfAddr < address(detf.underlyingVault()) ? 0 : 1;
        uint256 expectedVaultTokenIndex = expectedDetfIndex == 0 ? 1 : 0;
        assertEq(detfIndex_, expectedDetfIndex, "detf index");
        assertEq(vaultTokenIndex_, expectedVaultTokenIndex, "vault token index");

        assertEq(detf.mintThreshold(), 1005e15, "mint threshold");
        assertEq(detf.burnThreshold(), 995e15, "burn threshold");
        assertTrue(detf.isAcceptedBondToken(rateAsset), "weth accepted");
        assertTrue(detf.isAcceptedBondToken(pairToken), "rich accepted");
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
        IFacet erc721Facet =
            IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SingleVaultDetf_ERC721Facet")));

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

    function test_processArgs_reverts_whenNotRegistry() public {
        ISingleVaultDetfDFPkg.PkgArgs memory pkgArgs = SingleVaultDetf_Component_FactoryService.buildPkgArgs(
            "Single Vault DETF",
            "SVDETF",
            pairToken,
            1,
            1,
            _buildPoolKey(),
            60
        );

        vm.expectRevert(abi.encodeWithSelector(ISingleVaultDetfDFPkg.NotCalledByRegistry.selector, address(this)));
        singleVaultDetfDFPkg.processArgs(abi.encode(pkgArgs));
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