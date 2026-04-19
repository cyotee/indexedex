// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {
    WeightedPool8020Factory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IERC20PermitDFPkg, ERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderFacet.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    IBaseProtocolDETFDFPkg
} from "contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol";
import {
    BaseProtocolDETF_Component_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {
    BaseProtocolDETF_Facet_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {
    BaseProtocolDETF_Pkg_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg, RICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";
import {
    MockProtocolDETFBridgeTokenRegistry,
    MockProtocolDETFStandardBridge,
    MockProtocolDETFMessenger
} from "test/foundry/spec/vaults/protocol/ProtocolDETFRichBridge_UnitTestBase.t.sol";

abstract contract ProtocolDETFIntegrationBase is TestBase_BalancerV3StandardExchangeRouter {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Facet_FactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Pkg_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_SWAP_FEE = 1e16;
    uint256 internal constant INITIAL_WETH_DEPOSIT = 1_000_000e18;
    uint256 internal constant INITIAL_RICH_DEPOSIT = 10_000_000e18;
    uint256 internal constant BRIDGE_TEST_TARGET_CHAIN_ID = 84_532;

    IProtocolDETF internal detf;
    IERC20 internal rich;
    IRICHIR internal richir;
    IProtocolNFTVault internal protocolNFTVault;

    IStandardExchange internal chirWethVault;
    IStandardExchange internal richChirVault;
    IStandardExchangeProxy internal daiWethVault;

    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IWeightedPool internal reservePool;
    IWeightedPool8020Factory internal weighted8020Factory;

    MockProtocolDETFBridgeTokenRegistry internal bridgeTokenRegistryMock;
    MockProtocolDETFStandardBridge internal standardBridgeMock;
    MockProtocolDETFMessenger internal messengerMock;
    address internal bridgeLocalRelayer;
    address internal bridgePeerRelayer;
    address internal bridgePeerDetf;
    IERC20 internal bridgeRemoteRichToken;

    IWETH internal weth9;
    IERC20PermitDFPkg internal richTokenPkg;
    IProtocolNFTVaultDFPkg internal protocolNFTVaultPkg;
    IRICHIRDFPkg internal richirPkg;
    IBaseProtocolDETFDFPkg internal protocolDETFDFPkg;

    address internal detfAlice;
    address internal detfBob;

    function setUp() public virtual override {
        super.setUp();

        detfAlice = makeAddr("detfAlice");
        detfBob = makeAddr("detfBob");
        weth9 = IWETH(address(weth));

        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultDexSwapFeeOfTypeId(type(IBaseProtocolDETFBonding).interfaceId, DEFAULT_SWAP_FEE);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultBondTermsOfTypeId(
            type(IBaseProtocolDETFBonding).interfaceId,
            BondTerms({
                minLockDuration: 7 days,
                maxLockDuration: 365 days,
                minBonusPercentage: 0,
                maxBonusPercentage: 1e18
            })
        );
        vm.stopPrank();

        _deploySecondStandardExchangeVault();
        _deployWeightedPool8020Factory();
        _deployStandardExchangeRateProviderPkg();
        _deployRichTokenPkg();
        _deployRichToken();
        _deployBridgeMocks();
        _deployProtocolPkgs();
        _registerProtocolPkgs();
        _deployProtocolDetf();
        _fundUsers();
    }

    function _deployBridgeMocks() internal {
        bridgeTokenRegistryMock = new MockProtocolDETFBridgeTokenRegistry();
        standardBridgeMock = new MockProtocolDETFStandardBridge();
        messengerMock = new MockProtocolDETFMessenger();
        bridgeLocalRelayer = makeAddr("bridgeLocalRelayer");
        bridgePeerRelayer = makeAddr("bridgePeerRelayer");
        bridgePeerDetf = makeAddr("bridgePeerDetf");
        bridgeRemoteRichToken = IERC20(makeAddr("bridgeRemoteRichToken"));
    }

    function _bridgePkgConfig()
        internal
        view
        returns (ProtocolDETFSuperchainBridgeRepo.BridgeConfig memory bridgeConfig)
    {
        bridgeConfig = ProtocolDETFSuperchainBridgeRepo.BridgeConfig({
            bridgeTokenRegistry: ISuperChainBridgeTokenRegistry(address(bridgeTokenRegistryMock)),
            standardBridge: IStandardBridge(payable(address(standardBridgeMock))),
            messenger: ICrossDomainMessenger(address(messengerMock)),
            localRelayer: bridgeLocalRelayer,
            peerRelayer: bridgePeerRelayer
        });
    }

    function _deploySecondStandardExchangeVault() internal {
        address poolAddr = aerodromePoolFactory.createPool(address(dai), address(weth9), false);
        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(poolAddr));
        daiWethVault = IStandardExchangeProxy(vaultAddr);
        vm.label(vaultAddr, "DaiWethVault");
    }

    function _deployWeightedPool8020Factory() internal {
        bytes memory initArgs =
            abi.encode(IBalancerVault(address(vault)), uint32(365 days), "Factory v1", "8020Pool v1");

        address factoryAddr = create3Factory.create3WithArgs(
            type(WeightedPool8020Factory).creationCode,
            initArgs,
            keccak256("ProtocolDETFWeightedPool8020Factory")
        );
        weighted8020Factory = IWeightedPool8020Factory(factoryAddr);
        vm.label(factoryAddr, "ProtocolDETFWeightedPool8020Factory");
    }

    function _deployStandardExchangeRateProviderPkg() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("ProtocolDETF_StandardExchangeRateProviderFacet")
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
                    keccak256("ProtocolDETF_StandardExchangeRateProviderDFPkg")
                )
            )
        );
        vm.label(address(rateProviderPkg), "ProtocolDETF_StandardExchangeRateProviderDFPkg");
    }

    function _deployRichTokenPkg() internal {
        IERC20PermitDFPkg.PkgInit memory pkgInit = IERC20PermitDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet
        });

        richTokenPkg = IERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256("ProtocolDETF_RichTokenPkg")
                )
            )
        );
        vm.label(address(richTokenPkg), "ProtocolDETF_RichTokenPkg");
    }

    function _deployRichToken() internal {
        IERC20PermitDFPkg.PkgArgs memory args = IERC20PermitDFPkg.PkgArgs({
            name: "RICH",
            symbol: "RICH",
            decimals: 18,
            totalSupply: 1_000_000_000e18,
            recipient: owner,
            optionalSalt: bytes32(0)
        });

        rich = IERC20(diamondPackageFactory.deploy(IDiamondFactoryPackage(address(richTokenPkg)), abi.encode(args)));
        vm.label(address(rich), "ProtocolDETF_RICH");
    }

    function _deployProtocolPkgs() internal {
        IFacet protocolDETFExchangeInFacet = create3Factory.deployBaseProtocolDETFExchangeInFacet();
        IFacet protocolDETFExchangeInQueryFacet = create3Factory.deployBaseProtocolDETFExchangeInQueryFacet();
        IFacet protocolDETFExchangeOutFacet = create3Factory.deployBaseProtocolDETFExchangeOutFacet();
        IFacet protocolDETFBondingFacet = create3Factory.deployBaseProtocolDETFBondingFacet();
        IFacet protocolDETFBridgeFacet = create3Factory.deployBaseProtocolDETFBridgeFacet();
        IFacet protocolDETFBondingQueryFacet = create3Factory.deployBaseProtocolDETFBondingQueryFacet();
        IFacet protocolNFTVaultFacet = create3Factory.deployProtocolNFTVaultFacet();
        IFacet richirFacet = create3Factory.deployRICHIRFacet();
        IFacet erc721Facet =
            IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("ProtocolDETF_ERC721Facet")));
        IFacet multiStepOwnableFacet = create3Factory.deployMultiStepOwnableFacet();
        IFacet operableFacet = create3Factory.deployOperableFacet();
        IFacet protocolDETFRichirRedeemFacet = create3Factory.deployBaseProtocolDETFRichirRedeemFacet();

        IProtocolNFTVaultDFPkg.PkgInit memory nftPkgInit = BaseProtocolDETF_Component_FactoryService
            .buildProtocolNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            protocolNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        IRICHIRDFPkg.PkgInit memory richirPkgInit = BaseProtocolDETF_Component_FactoryService.buildRICHIRPkgInit(
            erc20Facet,
            erc5267Facet,
            erc2612Facet,
            richirFacet,
            diamondPackageFactory
        );

        vm.startPrank(owner);
        protocolNFTVaultPkg = IVaultRegistryDeployment(address(indexedexManager)).deployProtocolNFTVaultDFPkg(nftPkgInit);
        vm.stopPrank();

        richirPkg = IRICHIRDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RICHIRDFPkg).creationCode,
                    abi.encode(richirPkgInit),
                    keccak256("ProtocolDETF_RICHIRDFPkg")
                )
            )
        );

        BaseProtocolDETF_Component_FactoryService.ProtocolDETFFacets memory facets;
        facets.erc20Facet = erc20Facet;
        facets.erc5267Facet = erc5267Facet;
        facets.erc2612Facet = erc2612Facet;
        facets.erc4626BasicVaultFacet = erc4626BasicVaultFacet;
        facets.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
        facets.protocolDETFExchangeInFacet = protocolDETFExchangeInFacet;
        facets.protocolDETFExchangeInQueryFacet = protocolDETFExchangeInQueryFacet;
        facets.protocolDETFExchangeOutFacet = protocolDETFExchangeOutFacet;
        facets.protocolDETFBondingFacet = protocolDETFBondingFacet;
        facets.protocolDETFBridgeFacet = protocolDETFBridgeFacet;
        facets.protocolDETFBondingQueryFacet = protocolDETFBondingQueryFacet;
        facets.multiStepOwnableFacet = multiStepOwnableFacet;
        facets.operableFacet = operableFacet;
        facets.protocolDETFRichirRedeemFacet = protocolDETFRichirRedeemFacet;

        BaseProtocolDETF_Component_FactoryService.ProtocolDETFInfra memory infra =
            BaseProtocolDETF_Component_FactoryService.ProtocolDETFInfra({
                feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                permit2: permit2,
                balancerV3Vault: IBalancerVault(address(vault)),
                balancerV3Router: IRouter(address(router)),
                balancerV3PrepayRouter: seRouter,
                weightedPool8020Factory: weighted8020Factory,
                diamondFactory: diamondPackageFactory
            });

        BaseProtocolDETF_Component_FactoryService.ProtocolDETFPkgs memory pkgs =
            BaseProtocolDETF_Component_FactoryService.ProtocolDETFPkgs({
                aerodromeStandardExchangeDFPkg: aerodromeStandardExchangeDFPkg,
                protocolNFTVaultPkg: protocolNFTVaultPkg,
                richirPkg: richirPkg,
                rateProviderPkg: rateProviderPkg
            });

        IBaseProtocolDETFDFPkg.PkgInit memory detfPkgInit =
            BaseProtocolDETF_Component_FactoryService.buildProtocolDETFPkgInit(facets, infra, pkgs, _bridgePkgConfig());

        vm.startPrank(owner);
        protocolDETFDFPkg = IVaultRegistryDeployment(address(indexedexManager)).deployBaseProtocolDETFDFPkg(detfPkgInit);
        vm.stopPrank();
    }

    function _registerProtocolPkgs() internal {
        vm.startPrank(owner);
        IVaultRegistryVaultPackageManager(address(indexedexManager)).registerPackage(
            address(protocolNFTVaultPkg),
            IStandardVaultPkg(address(protocolNFTVaultPkg)).vaultDeclaration()
        );
        IVaultRegistryVaultPackageManager(address(indexedexManager)).registerPackage(
            address(protocolDETFDFPkg),
            IStandardVaultPkg(address(protocolDETFDFPkg)).vaultDeclaration()
        );
        vm.stopPrank();

        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(protocolNFTVaultPkg)),
            "ProtocolNFTVaultDFPkg not registered"
        );
        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(protocolDETFDFPkg)),
            "BaseProtocolDETFDFPkg not registered"
        );
    }

    function _deployProtocolDetf() internal {
        deal(address(weth9), owner, INITIAL_WETH_DEPOSIT);

        vm.startPrank(owner);
        IERC20(address(weth9)).approve(address(permit2), type(uint256).max);
        rich.approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth9), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        permit2.approve(address(rich), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);

        IBaseProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Protocol DETF";
        pkgArgs.symbol = "CHIR";
        pkgArgs.funder = owner;
        pkgArgs.owner = owner;
        pkgArgs.protocolConfig = BaseProtocolDETFRepo.ProtocolConfig({
            richToken: address(rich),
            richInitialDepositAmount: INITIAL_RICH_DEPOSIT,
            richMintChirPercent: 1e18,
            wethToken: address(weth9),
            wethInitialDepositAmount: INITIAL_WETH_DEPOSIT,
            wethMintChirPercent: 1e18
        });

        detf = IProtocolDETF(
            IVaultRegistryDeployment(address(indexedexManager)).deployVault(
                IStandardVaultPkg(address(protocolDETFDFPkg)),
                abi.encode(pkgArgs)
            )
        );
        vm.stopPrank();

        rich = detf.richToken();
        richir = IRICHIR(address(detf.richirToken()));
        protocolNFTVault = detf.protocolNFTVault();
        chirWethVault = detf.chirWethVault();
        richChirVault = detf.richChirVault();
        reservePool = IWeightedPool(detf.reservePool());

        bridgeTokenRegistryMock.setRemoteToken(
            BRIDGE_TEST_TARGET_CHAIN_ID, IERC20(address(detf)), IERC20(bridgePeerDetf), 0
        );
        bridgeTokenRegistryMock.setRemoteToken(BRIDGE_TEST_TARGET_CHAIN_ID, rich, bridgeRemoteRichToken, 120_000);

        vm.prank(address(detf));
        IERC20(address(reservePool)).approve(address(vault), type(uint256).max);
        vm.prank(address(detf));
        IERC20(address(reservePool)).approve(address(seRouter), type(uint256).max);
    }

    function _fundUsers() internal {
        _mintWeth(detfAlice, 1_000_000e18);
        _mintWeth(detfBob, 1_000_000e18);

        vm.startPrank(owner);
        rich.transfer(detfAlice, 1_000_000e18);
        rich.transfer(detfBob, 1_000_000e18);
        vm.stopPrank();
    }

    function _mintWeth(address recipient, uint256 amount) internal {
        vm.deal(recipient, amount);
        vm.prank(recipient);
        weth9.deposit{value: amount}();
    }

    function _mintChirFor(address user, uint256 wethAmount) internal returns (uint256 chirOut) {
        vm.startPrank(user);
        IERC20(address(weth9)).approve(address(detf), wethAmount);
        chirOut = IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(weth9)),
            wethAmount,
            IERC20(address(detf)),
            0,
            user,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _bondForReserveLiquidity(address user, uint256 amountIn) internal {
        vm.startPrank(user);
        uint256 remaining = amountIn;
        while (remaining > 0) {
            uint256 chunk = remaining > 10_000e18 ? 10_000e18 : remaining;
            IERC20(address(weth9)).approve(address(detf), chunk);
            IBaseProtocolDETFBonding(address(detf)).bond(
                IERC20(address(weth9)), chunk, 30 days, user, false, block.timestamp + 1 hours
            );
            remaining -= chunk;
        }
        vm.stopPrank();
    }
}
