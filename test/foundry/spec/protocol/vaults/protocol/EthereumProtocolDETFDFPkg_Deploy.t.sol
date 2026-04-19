// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    WeightedPool8020Factory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";

/* -------------------------------------------------------------------------- */
/*                                 Uniswap V2                                 */
/* -------------------------------------------------------------------------- */

import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {UniV2Factory} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Factory.sol";
import {UniV2Router02} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Router02.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {IERC20PermitDFPkg, ERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
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
import {
    IUniswapV2StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {
    UniswapV2_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg, RICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {
    BaseProtocolDETF_Component_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {
    EthereumProtocolDETF_Component_FactoryService
} from "contracts/vaults/protocol/EthereumProtocolDETF_Component_FactoryService.sol";
import {
    EthereumProtocolDETF_Facet_FactoryService
} from "contracts/vaults/protocol/EthereumProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {
    IEthereumProtocolDETFDFPkg,
    EthereumProtocolDETFDFPkg
} from "contracts/vaults/protocol/EthereumProtocolDETFDFPkg.sol";
import {
    EthereumProtocolDETF_Pkg_FactoryService
} from "contracts/vaults/protocol/EthereumProtocolDETF_Pkg_FactoryService.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";

contract EthereumProtocolDETFDFPkg_Deploy_Test is TestBase_BalancerV3StandardExchangeRouter {
    using EthereumProtocolDETF_Facet_FactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Facet_FactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Pkg_FactoryService for IVaultRegistryDeployment;
    using UniswapV2_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV2_Component_FactoryService for IFacet;
    using UniswapV2_Component_FactoryService for IIndexedexManagerProxy;
    using EthereumProtocolDETF_Pkg_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_SWAP_FEE = 1e16;
    uint256 internal constant INITIAL_WETH_DEPOSIT = 1_000_000e18;
    uint256 internal constant INITIAL_RICH_DEPOSIT = 10_000_000e18;

    IWeightedPool8020Factory internal weighted8020Factory;
    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IERC20PermitDFPkg internal richTokenPkg;
    IERC20 internal richToken;

    address internal uniswapV2FeeToSetter;
    IUniswapV2Factory internal uniswapV2Factory;
    IUniswapV2Router internal uniswapV2Router;
    IFacet internal uniswapV2StandardExchangeInFacet;
    IFacet internal uniswapV2StandardExchangeOutFacet;
    IUniswapV2StandardExchangeDFPkg internal uniswapV2StandardExchangeDFPkg;

    IProtocolNFTVaultDFPkg internal protocolNFTVaultPkg;
    IRICHIRDFPkg internal richirPkg;
    IEthereumProtocolDETFDFPkg internal protocolDETFDFPkg;

    function setUp() public override {
        super.setUp();

        _deployWeightedPool8020Factory();
        _deployStandardExchangeRateProviderPkg();
        _deployRichTokenPkg();
        _deployRichToken();
        _deployUniswapV2StandardExchangePkg();

        _deployProtocolPkgs();
        _registerProtocolPkgs();

        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultDexSwapFeeOfTypeId(type(IBaseProtocolDETFBonding).interfaceId, DEFAULT_SWAP_FEE);
        vm.stopPrank();
    }

    function _deployWeightedPool8020Factory() internal {
        bytes32 salt = keccak256("EthereumProtocolDETFWeightedPool8020Factory");
        bytes memory initCode = type(WeightedPool8020Factory).creationCode;
        bytes memory initArgs =
            abi.encode(IBalancerVault(address(vault)), uint32(365 days), "Factory v1", "8020Pool v1");

        address factoryAddr = create3Factory.create3WithArgs(initCode, initArgs, salt);
        weighted8020Factory = IWeightedPool8020Factory(factoryAddr);
        vm.label(factoryAddr, "EthereumProtocolDETFWeightedPool8020Factory");
    }

    function _deployStandardExchangeRateProviderPkg() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("EthereumProtocolDETF_StandardExchangeRateProviderFacet")
            )
        );
        vm.label(address(rateProviderFacet), "EthereumProtocolDETF_StandardExchangeRateProviderFacet");

        IStandardExchangeRateProviderDFPkg.PkgInit memory pkgInit = IStandardExchangeRateProviderDFPkg.PkgInit({
            rateProviderFacet: rateProviderFacet,
            diamondFactory: diamondPackageFactory
        });

        rateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256("EthereumProtocolDETF_StandardExchangeRateProviderDFPkg")
                )
            )
        );
        vm.label(address(rateProviderPkg), "EthereumProtocolDETF_StandardExchangeRateProviderDFPkg");
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
                    keccak256("EthereumProtocolDETF_RichTokenPkg")
                )
            )
        );
        vm.label(address(richTokenPkg), "EthereumProtocolDETF_RichTokenPkg");
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

        address richAddr = diamondPackageFactory.deploy(IDiamondFactoryPackage(address(richTokenPkg)), abi.encode(args));
        richToken = IERC20(richAddr);
        vm.label(richAddr, "EthereumProtocolDETF_RICH");
    }

    function _deployUniswapV2StandardExchangePkg() internal {
        uniswapV2FeeToSetter = makeAddr("uniswapV2FeeToSetter");
        vm.label(uniswapV2FeeToSetter, "uniswapV2FeeToSetter");

        uniswapV2Factory = IUniswapV2Factory(address(new UniV2Factory(uniswapV2FeeToSetter)));
        uniswapV2Router = IUniswapV2Router(address(new UniV2Router02(address(uniswapV2Factory), address(weth))));
        vm.label(address(uniswapV2Factory), "uniswapV2Factory");
        vm.label(address(uniswapV2Router), "uniswapV2Router");

        uniswapV2StandardExchangeInFacet = create3Factory.deployUniswapV2StandardExchangeInFacet();
        uniswapV2StandardExchangeOutFacet = create3Factory.deployUniswapV2StandardExchangeOutFacet();

        vm.startPrank(owner);
        uniswapV2StandardExchangeDFPkg = indexedexManager.deployUniswapV2StandardExchangeDFPkg(
            erc20Facet.buildArgsUniswapV2StandardExchangePkgInit(
                erc2612Facet,
                erc5267Facet,
                erc4626Facet,
                erc4626BasicVaultFacet,
                erc4626StandardVaultFacet,
                uniswapV2StandardExchangeInFacet,
                uniswapV2StandardExchangeOutFacet,
                indexedexManager,
                indexedexManager,
                permit2,
                uniswapV2Factory,
                uniswapV2Router
            )
        );
        vm.stopPrank();
    }

    function _deployProtocolPkgs() internal {
        IFacet protocolDETFExchangeInFacet = create3Factory.deployEthereumProtocolDETFExchangeInFacet();
        IFacet protocolDETFExchangeInQueryFacet = create3Factory.deployEthereumProtocolDETFExchangeInQueryFacet();
        IFacet protocolDETFExchangeOutFacet = create3Factory.deployEthereumProtocolDETFExchangeOutFacet();
        IFacet protocolDETFBondingFacet = create3Factory.deployEthereumProtocolDETFBondingFacet();
        IFacet protocolDETFBridgeFacet = create3Factory.deployEthereumProtocolDETFBridgeFacet();
        IFacet protocolDETFBondingQueryFacet = create3Factory.deployEthereumProtocolDETFBondingQueryFacet();
        IFacet protocolNFTVaultFacet = create3Factory.deployProtocolNFTVaultFacet();
        IFacet richirFacet = create3Factory.deployRICHIRFacet();
        IFacet erc721Facet =
            IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("ProtocolDETF_ERC721Facet")));

        IProtocolNFTVaultDFPkg.PkgInit memory nftPkgInit = BaseProtocolDETF_Component_FactoryService.buildProtocolNFTVaultPkgInit(
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
                    keccak256("EthereumProtocolDETF_RICHIRDFPkg")
                )
            )
        );

        EthereumProtocolDETF_Component_FactoryService.EthereumProtocolDETFFacets memory facets =
            EthereumProtocolDETF_Component_FactoryService.EthereumProtocolDETFFacets({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                erc4626BasicVaultFacet: erc4626BasicVaultFacet,
                erc4626StandardVaultFacet: erc4626StandardVaultFacet,
                protocolDETFExchangeInFacet: protocolDETFExchangeInFacet,
                protocolDETFExchangeInQueryFacet: protocolDETFExchangeInQueryFacet,
                protocolDETFExchangeOutFacet: protocolDETFExchangeOutFacet,
                protocolDETFBondingFacet: protocolDETFBondingFacet,
                protocolDETFBridgeFacet: protocolDETFBridgeFacet,
                protocolDETFBondingQueryFacet: protocolDETFBondingQueryFacet
            });

        EthereumProtocolDETF_Component_FactoryService.EthereumProtocolDETFInfra memory infra =
            EthereumProtocolDETF_Component_FactoryService.EthereumProtocolDETFInfra({
                feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                permit2: permit2,
                balancerV3Vault: IBalancerVault(address(vault)),
                balancerV3Router: IRouter(address(router)),
                balancerV3PrepayRouter: seRouter,
                weightedPool8020Factory: weighted8020Factory,
                diamondFactory: diamondPackageFactory
            });

        EthereumProtocolDETF_Component_FactoryService.EthereumProtocolDETFPkgs memory pkgs =
            EthereumProtocolDETF_Component_FactoryService.EthereumProtocolDETFPkgs({
                uniswapV2StandardExchangeDFPkg: uniswapV2StandardExchangeDFPkg,
                protocolNFTVaultPkg: protocolNFTVaultPkg,
                richirPkg: richirPkg,
                rateProviderPkg: rateProviderPkg
            });
            ProtocolDETFSuperchainBridgeRepo.BridgeConfig memory bridgeConfig;

        IEthereumProtocolDETFDFPkg.PkgInit memory detfPkgInit =
            EthereumProtocolDETF_Component_FactoryService.buildEthereumProtocolDETFPkgInit(
                facets, infra, pkgs, bridgeConfig
            );

        vm.startPrank(owner);
        protocolDETFDFPkg = IVaultRegistryDeployment(address(indexedexManager)).deployEthereumProtocolDETFDFPkg(detfPkgInit);
        vm.stopPrank();

        assertGt(address(protocolDETFDFPkg).code.length, 0, "EthereumProtocolDETFDFPkg not deployed");
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
            "EthereumProtocolDETFDFPkg not registered"
        );
    }

    function test_deployVault_success() public {
        uint256 wethDeposit = INITIAL_WETH_DEPOSIT;
        uint256 richDeposit = INITIAL_RICH_DEPOSIT;

        deal(address(weth), owner, wethDeposit);

        vm.startPrank(owner);
        IERC20(address(weth)).approve(address(permit2), type(uint256).max);
        IERC20(address(richToken)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        permit2.approve(address(richToken), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IEthereumProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Ethereum Protocol DETF";
        pkgArgs.symbol = "eCHIR";
        pkgArgs.funder = owner;
        pkgArgs.protocolConfig = BaseProtocolDETFRepo.ProtocolConfig({
            richToken: address(richToken),
            richInitialDepositAmount: richDeposit,
            richMintChirPercent: 1e18,
            wethToken: address(weth),
            wethInitialDepositAmount: wethDeposit,
            wethMintChirPercent: 1e18
        });

        vm.startPrank(owner);
        address detfAddr = IVaultRegistryDeployment(address(indexedexManager)).deployVault(
            IStandardVaultPkg(address(protocolDETFDFPkg)),
            abi.encode(pkgArgs)
        );
        vm.stopPrank();

        assertGt(detfAddr.code.length, 0, "Ethereum Protocol DETF proxy not deployed");

        IProtocolDETF detf = IProtocolDETF(detfAddr);
        assertGt(address(detf.chirWethVault()).code.length, 0, "chirWethVault not deployed");
        assertGt(address(detf.richChirVault()).code.length, 0, "richChirVault not deployed");

        address reservePool = detf.reservePool();
        assertGt(reservePool.code.length, 0, "reservePool not deployed");
        assertGt(address(detf.protocolNFTVault()).code.length, 0, "protocolNFTVault not deployed");
        assertEq(address(detf.richToken()), address(richToken), "richToken mismatch");
        assertGt(address(detf.richirToken()).code.length, 0, "richirToken not deployed");

        uint256 protocolNFTId = detf.protocolNFTId();
        IProtocolNFTVault.Position memory pos = detf.protocolNFTVault().getPosition(protocolNFTId);
        assertEq(pos.unlockTime, 0, "protocol NFT should have no unlock time");
    }

    function test_processArgs_reverts_whenNotRegistry() public {
        IEthereumProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Ethereum Protocol DETF";
        pkgArgs.symbol = "eCHIR";
        pkgArgs.funder = address(this);
        pkgArgs.protocolConfig = BaseProtocolDETFRepo.ProtocolConfig({
            richToken: address(richToken),
            richInitialDepositAmount: 1,
            richMintChirPercent: 1e18,
            wethToken: address(weth),
            wethInitialDepositAmount: 1,
            wethMintChirPercent: 1e18
        });

        vm.expectRevert(abi.encodeWithSelector(IEthereumProtocolDETFDFPkg.NotCalledByRegistry.selector, address(this)));
        protocolDETFDFPkg.processArgs(abi.encode(pkgArgs));
    }

    function test_deployVault_reservePool_hasNonZeroTotalSupply() public {
        uint256 wethDeposit = INITIAL_WETH_DEPOSIT;
        uint256 richDeposit = INITIAL_RICH_DEPOSIT;

        deal(address(weth), owner, wethDeposit);

        vm.startPrank(owner);
        IERC20(address(weth)).approve(address(permit2), type(uint256).max);
        IERC20(address(richToken)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        permit2.approve(address(richToken), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IEthereumProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Ethereum Protocol DETF";
        pkgArgs.symbol = "eCHIR";
        pkgArgs.funder = owner;
        pkgArgs.protocolConfig = BaseProtocolDETFRepo.ProtocolConfig({
            richToken: address(richToken),
            richInitialDepositAmount: richDeposit,
            richMintChirPercent: 1e18,
            wethToken: address(weth),
            wethInitialDepositAmount: wethDeposit,
            wethMintChirPercent: 1e18
        });

        vm.startPrank(owner);
        address detfAddr = IVaultRegistryDeployment(address(indexedexManager)).deployVault(
            IStandardVaultPkg(address(protocolDETFDFPkg)),
            abi.encode(pkgArgs)
        );
        vm.stopPrank();

        IProtocolDETF detf = IProtocolDETF(detfAddr);
        uint256 totalSupply = IERC20(detf.reservePool()).totalSupply();
        assertGt(totalSupply, 0, "Reserve pool should have non-zero total supply after deployment");
    }

    function test_deployVault_detf_holdsBPTTokens() public {
        uint256 wethDeposit = INITIAL_WETH_DEPOSIT;
        uint256 richDeposit = INITIAL_RICH_DEPOSIT;

        deal(address(weth), owner, wethDeposit);

        vm.startPrank(owner);
        IERC20(address(weth)).approve(address(permit2), type(uint256).max);
        IERC20(address(richToken)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        permit2.approve(address(richToken), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IEthereumProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Ethereum Protocol DETF";
        pkgArgs.symbol = "eCHIR";
        pkgArgs.funder = owner;
        pkgArgs.protocolConfig = BaseProtocolDETFRepo.ProtocolConfig({
            richToken: address(richToken),
            richInitialDepositAmount: richDeposit,
            richMintChirPercent: 1e18,
            wethToken: address(weth),
            wethInitialDepositAmount: wethDeposit,
            wethMintChirPercent: 1e18
        });

        vm.startPrank(owner);
        address detfAddr = IVaultRegistryDeployment(address(indexedexManager)).deployVault(
            IStandardVaultPkg(address(protocolDETFDFPkg)),
            abi.encode(pkgArgs)
        );
        vm.stopPrank();

        IProtocolDETF detf = IProtocolDETF(detfAddr);
        uint256 detfBptBalance = IERC20(detf.reservePool()).balanceOf(detfAddr);
        assertGt(detfBptBalance, 0, "CHIR contract should hold BPT tokens after deployment");
    }

    function test_deployVault_vaultSharesTransferredToBalancerVault() public {
        uint256 wethDeposit = INITIAL_WETH_DEPOSIT;
        uint256 richDeposit = INITIAL_RICH_DEPOSIT;

        deal(address(weth), owner, wethDeposit);

        vm.startPrank(owner);
        IERC20(address(weth)).approve(address(permit2), type(uint256).max);
        IERC20(address(richToken)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        permit2.approve(address(richToken), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IEthereumProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Ethereum Protocol DETF";
        pkgArgs.symbol = "eCHIR";
        pkgArgs.funder = owner;
        pkgArgs.protocolConfig = BaseProtocolDETFRepo.ProtocolConfig({
            richToken: address(richToken),
            richInitialDepositAmount: richDeposit,
            richMintChirPercent: 1e18,
            wethToken: address(weth),
            wethInitialDepositAmount: wethDeposit,
            wethMintChirPercent: 1e18
        });

        vm.startPrank(owner);
        address detfAddr = IVaultRegistryDeployment(address(indexedexManager)).deployVault(
            IStandardVaultPkg(address(protocolDETFDFPkg)),
            abi.encode(pkgArgs)
        );
        vm.stopPrank();

        IProtocolDETF detf = IProtocolDETF(detfAddr);
        uint256 chirWethSharesInDETF = IERC20(address(detf.chirWethVault())).balanceOf(detfAddr);
        uint256 richChirSharesInDETF = IERC20(address(detf.richChirVault())).balanceOf(detfAddr);

        assertEq(chirWethSharesInDETF, 0, "CHIR/WETH vault shares should be transferred out of CHIR contract");
        assertEq(richChirSharesInDETF, 0, "RICH/CHIR vault shares should be transferred out of CHIR contract");
    }

    function test_uniswapStandardExchangeRateProviders_returnNonZeroRates() public {
        uint256 wethDeposit = 1_000e18;
        uint256 richDeposit = 10_000e18;
        uint256 chirSupply = 1_000_000e18;

        deal(address(weth), owner, wethDeposit);

        IERC20 chirToken = _deployStandaloneChirToken(chirSupply, owner);

        vm.startPrank(owner);
        IERC20(address(weth)).approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        IERC20(address(richToken)).approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        IERC20(address(chirToken)).approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);

        address chirWethVaultAddr = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(weth)), wethDeposit, chirToken, wethDeposit, owner
        );
        address richChirVaultAddr = uniswapV2StandardExchangeDFPkg.deployVault(
            IERC20(address(richToken)), richDeposit, chirToken, richDeposit, owner
        );
        vm.stopPrank();

        IRateProvider chirWethRateProvider = rateProviderPkg.deployRateProvider(
            IStandardExchange(chirWethVaultAddr), IERC20(address(weth))
        );
        IRateProvider richChirRateProvider = rateProviderPkg.deployRateProvider(
            IStandardExchange(richChirVaultAddr), IERC20(address(richToken))
        );

        assertGt(IERC20(chirWethVaultAddr).balanceOf(owner), 0, "chirWeth vault shares should mint");
        assertGt(IERC20(richChirVaultAddr).balanceOf(owner), 0, "richChir vault shares should mint");
        assertGt(chirWethRateProvider.getRate(), 0, "chirWeth rate should be non-zero");
        assertGt(richChirRateProvider.getRate(), 0, "richChir rate should be non-zero");
    }

    function _deployStandaloneChirToken(uint256 totalSupply, address recipient) internal returns (IERC20 chirToken) {
        IERC20PermitDFPkg.PkgArgs memory args = IERC20PermitDFPkg.PkgArgs({
            name: "CHIR",
            symbol: "CHIR",
            decimals: 18,
            totalSupply: totalSupply,
            recipient: recipient,
            optionalSalt: keccak256("EthereumProtocolDETF_StandaloneCHIR")
        });

        address chirAddr = diamondPackageFactory.deploy(IDiamondFactoryPackage(address(richTokenPkg)), abi.encode(args));
        chirToken = IERC20(chirAddr);
        vm.label(chirAddr, "EthereumProtocolDETF_StandaloneCHIR");
    }
}