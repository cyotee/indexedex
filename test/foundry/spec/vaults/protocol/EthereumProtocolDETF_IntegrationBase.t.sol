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
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IERC20PermitDFPkg, ERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";

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
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
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
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    BaseProtocolDETF_Component_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {
    BaseProtocolDETF_Facet_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {
    BaseProtocolDETF_Pkg_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {
    EthereumProtocolDETF_Component_FactoryService
} from "contracts/vaults/protocol/EthereumProtocolDETF_Component_FactoryService.sol";
import {
    EthereumProtocolDETF_Facet_FactoryService
} from "contracts/vaults/protocol/EthereumProtocolDETF_Facet_FactoryService.sol";
import {
    IEthereumProtocolDETFDFPkg
} from "contracts/vaults/protocol/EthereumProtocolDETFDFPkg.sol";
import {
    EthereumProtocolDETF_Pkg_FactoryService
} from "contracts/vaults/protocol/EthereumProtocolDETF_Pkg_FactoryService.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg, RICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";

interface IProtocolDETFBridgeInit {
    function initBridge(bytes calldata initData) external;
}

abstract contract ProtocolDETFIntegrationBase is TestBase_BalancerV3StandardExchangeRouter {
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

    IProtocolDETF internal detf;
    IERC20 internal rich;
    IRICHIR internal richir;
    IProtocolNFTVault internal protocolNFTVault;

    IStandardExchange internal chirWethVault;
    IStandardExchange internal richChirVault;

    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IWeightedPool internal reservePool;
    IWeightedPool8020Factory internal weighted8020Factory;

    IWETH internal weth9;
    address internal uniswapV2FeeToSetter;
    IUniswapV2Factory internal uniswapV2Factory;
    IUniswapV2Router internal uniswapV2Router;
    IFacet internal uniswapV2StandardExchangeInFacet;
    IFacet internal uniswapV2StandardExchangeOutFacet;
    IUniswapV2StandardExchangeDFPkg internal uniswapV2StandardExchangeDFPkg;

    IERC20PermitDFPkg internal richTokenPkg;
    IProtocolNFTVaultDFPkg internal protocolNFTVaultPkg;
    IRICHIRDFPkg internal richirPkg;
    IEthereumProtocolDETFDFPkg internal protocolDETFDFPkg;

    address internal detfAlice;
    address internal detfBob;
    uint256 internal chirWethVaultIndex;
    uint256 internal richChirVaultIndex;

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

        _deployWeightedPool8020Factory();
        _deployStandardExchangeRateProviderPkg();
        _deployRichTokenPkg();
        _deployRichToken();
        _deployUniswapV2StandardExchangePkg();
        _deployProtocolPkgs();
        _registerProtocolPkgs();
        _deployProtocolDetf();
        _fundUsers();
    }

    function _deployWeightedPool8020Factory() internal {
        bytes memory initArgs =
            abi.encode(IBalancerVault(address(vault)), uint32(365 days), "Factory v1", "8020Pool v1");

        address factoryAddr = create3Factory.create3WithArgs(
            type(WeightedPool8020Factory).creationCode,
            initArgs,
            keccak256("EthereumProtocolDETFWeightedPool8020Factory")
        );
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

        rich = IERC20(diamondPackageFactory.deploy(IDiamondFactoryPackage(address(richTokenPkg)), abi.encode(args)));
        vm.label(address(rich), "EthereumProtocolDETF_RICH");
    }

    function _deployUniswapV2StandardExchangePkg() internal {
        uniswapV2FeeToSetter = makeAddr("uniswapV2FeeToSetter");
        vm.label(uniswapV2FeeToSetter, "uniswapV2FeeToSetter");

        uniswapV2Factory = IUniswapV2Factory(address(new UniV2Factory(uniswapV2FeeToSetter)));
        uniswapV2Router = IUniswapV2Router(address(new UniV2Router02(address(uniswapV2Factory), address(weth9))));
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
        IFacet protocolDETFBondingQueryFacet = create3Factory.deployEthereumProtocolDETFBondingQueryFacet();
        IFacet protocolNFTVaultFacet = create3Factory.deployProtocolNFTVaultFacet();
        IFacet richirFacet = create3Factory.deployRICHIRFacet();
        IFacet erc721Facet =
            IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("ProtocolDETF_ERC721Facet")));

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

        IEthereumProtocolDETFDFPkg.PkgInit memory detfPkgInit =
            EthereumProtocolDETF_Component_FactoryService.buildEthereumProtocolDETFPkgInit(facets, infra, pkgs);

        vm.startPrank(owner);
        protocolDETFDFPkg = IVaultRegistryDeployment(address(indexedexManager)).deployEthereumProtocolDETFDFPkg(detfPkgInit);
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
            "EthereumProtocolDETFDFPkg not registered"
        );
    }

    function _deployProtocolDetf() internal {
        deal(address(weth9), owner, INITIAL_WETH_DEPOSIT);

        vm.startPrank(owner);
        IERC20(address(weth9)).approve(address(permit2), type(uint256).max);
        rich.approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth9), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        permit2.approve(address(rich), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);

        IEthereumProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Ethereum Protocol DETF";
        pkgArgs.symbol = "eCHIR";
        pkgArgs.funder = owner;
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

        (chirWethVaultIndex, richChirVaultIndex) =
            address(chirWethVault) < address(richChirVault) ? (0, 1) : (1, 0);

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

    function _initBridge(bytes memory initData) internal {
        IProtocolDETFBridgeInit(address(detf)).initBridge(initData);
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
            IBaseProtocolDETFBonding(address(detf)).bondWithWeth(chunk, 30 days, user, block.timestamp + 1 hours);
            remaining -= chunk;
        }
        vm.stopPrank();
    }
}