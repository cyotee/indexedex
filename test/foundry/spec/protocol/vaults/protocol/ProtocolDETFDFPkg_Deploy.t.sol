// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {
    WeightedPool8020Factory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {IERC20PermitDFPkg, ERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
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

import {IBaseProtocolDETFDFPkg, BaseProtocolDETFDFPkg} from "contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg, RICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {BaseProtocolDETF_Component_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";

contract BaseProtocolDETFDFPkg_Deploy_Test is TestBase_BalancerV3StandardExchangeRouter {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Facet_FactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Pkg_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_SWAP_FEE = 1e16;

    IWeightedPool8020Factory internal weighted8020Factory;
    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IERC20PermitDFPkg internal richTokenPkg;
    IERC20 internal richToken;

    IProtocolNFTVaultDFPkg internal protocolNFTVaultPkg;
    IRICHIRDFPkg internal richirPkg;
    IBaseProtocolDETFDFPkg internal protocolDETFDFPkg;

    IStandardExchangeProxy internal daiWethVault;

    function setUp() public override {
        super.setUp();

        _deploySecondStandardExchangeVault();

        _deployWeightedPool8020Factory();
        _deployStandardExchangeRateProviderPkg();
        _deployRichTokenPkg();
        _deployRichToken();

        _deployProtocolPkgs();
        _registerProtocolPkgs();

        // Ensure the pool swap fee is non-zero for reserve pool creation.
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultDexSwapFeeOfTypeId(type(IBaseProtocolDETFBonding).interfaceId, DEFAULT_SWAP_FEE);
        vm.stopPrank();
    }

    function _deploySecondStandardExchangeVault() internal {
        // Create a second Aerodrome pool (DAI/WETH) and wrap it with a StandardExchange vault.
        address poolAddr = aerodromePoolFactory.createPool(address(dai), address(weth), false);
        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(poolAddr));
        daiWethVault = IStandardExchangeProxy(vaultAddr);
        vm.label(vaultAddr, "DaiWethVault");
    }

    function _deployWeightedPool8020Factory() internal {
        bytes32 salt = keccak256("ProtocolDETFWeightedPool8020Factory");
        bytes memory initCode = type(WeightedPool8020Factory).creationCode;
        bytes memory initArgs =
            abi.encode(IBalancerVault(address(vault)), uint32(365 days), "Factory v1", "8020Pool v1");

        address factoryAddr = create3Factory.create3WithArgs(initCode, initArgs, salt);
        weighted8020Factory = IWeightedPool8020Factory(factoryAddr);
        vm.label(factoryAddr, "WeightedPool8020Factory");
    }

    function _deployStandardExchangeRateProviderPkg() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("ProtocolDETF_StandardExchangeRateProviderFacet")
            )
        );
        vm.label(address(rateProviderFacet), "StandardExchangeRateProviderFacet");

        IStandardExchangeRateProviderDFPkg.PkgInit memory pkgInit = IStandardExchangeRateProviderDFPkg.PkgInit({
            rateProviderFacet: rateProviderFacet, diamondFactory: diamondPackageFactory
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
        vm.label(address(rateProviderPkg), "StandardExchangeRateProviderDFPkg");
    }

    function _deployRichTokenPkg() internal {
        IERC20PermitDFPkg.PkgInit memory pkgInit =
            IERC20PermitDFPkg.PkgInit({erc20Facet: erc20Facet, erc5267Facet: erc5267Facet, erc2612Facet: erc2612Facet});

        richTokenPkg = IERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode, abi.encode(pkgInit), keccak256("ProtocolDETF_RichTokenPkg")
                )
            )
        );
        vm.label(address(richTokenPkg), "ERC20PermitDFPkg");
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
        vm.label(richAddr, "RICH");
    }

    function _deployProtocolPkgs() internal {
        // Deploy protocol facets.
        IFacet protocolDETFExchangeInFacet = create3Factory.deployBaseProtocolDETFExchangeInFacet();
        IFacet protocolDETFExchangeInQueryFacet = create3Factory.deployBaseProtocolDETFExchangeInQueryFacet();
        IFacet protocolDETFExchangeOutFacet = create3Factory.deployBaseProtocolDETFExchangeOutFacet();
        IFacet protocolDETFBondingFacet = create3Factory.deployBaseProtocolDETFBondingFacet();
        IFacet protocolDETFBondingQueryFacet = create3Factory.deployBaseProtocolDETFBondingQueryFacet();
        IFacet protocolNFTVaultFacet = create3Factory.deployProtocolNFTVaultFacet();
        IFacet richirFacet = create3Factory.deployRICHIRFacet();
        IFacet erc721Facet =
            IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("ProtocolDETF_ERC721Facet")));
        IFacet multiStepOwnableFacet = create3Factory.deployMultiStepOwnableFacet();
        IFacet operableFacet = create3Factory.deployOperableFacet();
        IFacet protocolDETFRichirRedeemFacet = create3Factory.deployBaseProtocolDETFRichirRedeemFacet();

        // Deploy Protocol NFT Vault package via the vault registry.
        IProtocolNFTVaultDFPkg.PkgInit memory nftPkgInit = BaseProtocolDETF_Component_FactoryService.buildProtocolNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            protocolNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        // Deploy RICHIR package.
        IRICHIRDFPkg.PkgInit memory richirPkgInit = BaseProtocolDETF_Component_FactoryService.buildRICHIRPkgInit(
            erc20Facet, erc5267Facet, erc2612Facet, richirFacet, diamondPackageFactory
        );

        vm.startPrank(owner);
        protocolNFTVaultPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployProtocolNFTVaultDFPkg(nftPkgInit);
        vm.stopPrank();

        // NOTE: RICHIRDFPkg is NOT an IStandardVaultPkg, so it must NOT be deployed via VaultRegistryDeployment.
        richirPkg = IRICHIRDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RICHIRDFPkg).creationCode, abi.encode(richirPkgInit), keccak256("ProtocolDETF_RICHIRDFPkg")
                )
            )
        );

        vm.startPrank(owner);
        // Deploy Protocol DETF package.
        BaseProtocolDETF_Component_FactoryService.ProtocolDETFFacets memory facets =
            BaseProtocolDETF_Component_FactoryService.ProtocolDETFFacets({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                erc4626BasicVaultFacet: erc4626BasicVaultFacet,
                erc4626StandardVaultFacet: erc4626StandardVaultFacet,
                protocolDETFExchangeInFacet: protocolDETFExchangeInFacet,
                protocolDETFExchangeInQueryFacet: protocolDETFExchangeInQueryFacet,
                protocolDETFExchangeOutFacet: protocolDETFExchangeOutFacet,
                protocolDETFBondingFacet: protocolDETFBondingFacet,
                protocolDETFBondingQueryFacet: protocolDETFBondingQueryFacet,
                multiStepOwnableFacet: multiStepOwnableFacet,
                operableFacet: operableFacet,
                protocolDETFRichirRedeemFacet: protocolDETFRichirRedeemFacet
            });

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
            BaseProtocolDETF_Component_FactoryService.buildProtocolDETFPkgInit(facets, infra, pkgs);

        protocolDETFDFPkg = IVaultRegistryDeployment(address(indexedexManager)).deployBaseProtocolDETFDFPkg(detfPkgInit);
        vm.stopPrank();

        assertGt(address(protocolDETFDFPkg).code.length, 0, "BaseProtocolDETFDFPkg not deployed");
    }

    function _registerProtocolPkgs() internal {
        vm.startPrank(owner);
        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(
                address(protocolNFTVaultPkg), IStandardVaultPkg(address(protocolNFTVaultPkg)).vaultDeclaration()
            );
        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(
                address(protocolDETFDFPkg), IStandardVaultPkg(address(protocolDETFDFPkg)).vaultDeclaration()
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

    function test_deployVault_success() public {
        uint256 wethDeposit = 1_000e18;
        uint256 richDeposit = 10_000e18;

        // Fund owner for initial deposits.
        deal(address(weth), owner, wethDeposit);

        // Approve Permit2 for token transfer, then approve the Protocol DETF package on Permit2.
        vm.startPrank(owner);
        IERC20(address(weth)).approve(address(permit2), type(uint256).max);
        IERC20(address(richToken)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        permit2.approve(address(richToken), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IBaseProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Protocol DETF";
        pkgArgs.symbol = "CHIR";
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
        address detfAddr = IVaultRegistryDeployment(address(indexedexManager))
            .deployVault(IStandardVaultPkg(address(protocolDETFDFPkg)), abi.encode(pkgArgs));
        vm.stopPrank();

        assertGt(detfAddr.code.length, 0, "ProtocolDETF proxy not deployed");

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
        IBaseProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Protocol DETF";
        pkgArgs.symbol = "CHIR";
        pkgArgs.funder = address(this);
        pkgArgs.protocolConfig = BaseProtocolDETFRepo.ProtocolConfig({
            richToken: address(richToken),
            richInitialDepositAmount: 1,
            richMintChirPercent: 1e18,
            wethToken: address(weth),
            wethInitialDepositAmount: 1,
            wethMintChirPercent: 1e18
        });

        vm.expectRevert(abi.encodeWithSelector(IBaseProtocolDETFDFPkg.NotCalledByRegistry.selector, address(this)));
        protocolDETFDFPkg.processArgs(abi.encode(pkgArgs));
    }

    /* ---------------------------------------------------------------------- */
    /*               Reserve Pool Initialization Tests (US-016.3)             */
    /* ---------------------------------------------------------------------- */

    function test_deployVault_reservePool_hasNonZeroTotalSupply() public {
        uint256 wethDeposit = 1_000e18;
        uint256 richDeposit = 10_000e18;

        deal(address(weth), owner, wethDeposit);

        vm.startPrank(owner);
        IERC20(address(weth)).approve(address(permit2), type(uint256).max);
        IERC20(address(richToken)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        permit2.approve(address(richToken), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IBaseProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Protocol DETF";
        pkgArgs.symbol = "CHIR";
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
        address detfAddr = IVaultRegistryDeployment(address(indexedexManager))
            .deployVault(IStandardVaultPkg(address(protocolDETFDFPkg)), abi.encode(pkgArgs));
        vm.stopPrank();

        IProtocolDETF detf = IProtocolDETF(detfAddr);
        address reservePool = detf.reservePool();

        // Verify reserve pool has non-zero total supply
        uint256 totalSupply = IERC20(reservePool).totalSupply();
        assertGt(totalSupply, 0, "Reserve pool should have non-zero total supply after deployment");
    }

    function test_deployVault_detf_holdsBPTTokens() public {
        uint256 wethDeposit = 1_000e18;
        uint256 richDeposit = 10_000e18;

        deal(address(weth), owner, wethDeposit);

        vm.startPrank(owner);
        IERC20(address(weth)).approve(address(permit2), type(uint256).max);
        IERC20(address(richToken)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        permit2.approve(address(richToken), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IBaseProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Protocol DETF";
        pkgArgs.symbol = "CHIR";
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
        address detfAddr = IVaultRegistryDeployment(address(indexedexManager))
            .deployVault(IStandardVaultPkg(address(protocolDETFDFPkg)), abi.encode(pkgArgs));
        vm.stopPrank();

        IProtocolDETF detf = IProtocolDETF(detfAddr);
        address reservePool = detf.reservePool();

        // Verify CHIR contract holds BPT tokens
        uint256 detfBptBalance = IERC20(reservePool).balanceOf(detfAddr);
        assertGt(detfBptBalance, 0, "CHIR contract should hold BPT tokens after deployment");
    }

    function test_deployVault_vaultSharesTransferredToBalancerVault() public {
        uint256 wethDeposit = 1_000e18;
        uint256 richDeposit = 10_000e18;

        deal(address(weth), owner, wethDeposit);

        vm.startPrank(owner);
        IERC20(address(weth)).approve(address(permit2), type(uint256).max);
        IERC20(address(richToken)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        permit2.approve(address(richToken), address(protocolDETFDFPkg), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IBaseProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Protocol DETF";
        pkgArgs.symbol = "CHIR";
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
        address detfAddr = IVaultRegistryDeployment(address(indexedexManager))
            .deployVault(IStandardVaultPkg(address(protocolDETFDFPkg)), abi.encode(pkgArgs));
        vm.stopPrank();

        IProtocolDETF detf = IProtocolDETF(detfAddr);

        // Verify vault shares are NOT held by CHIR contract (they should be in Balancer vault)
        uint256 chirWethSharesInDETF = IERC20(address(detf.chirWethVault())).balanceOf(detfAddr);
        uint256 richChirSharesInDETF = IERC20(address(detf.richChirVault())).balanceOf(detfAddr);

        // After initialization, shares should have been transferred to the Balancer vault
        assertEq(chirWethSharesInDETF, 0, "CHIR/WETH vault shares should be transferred out of CHIR contract");
        assertEq(richChirSharesInDETF, 0, "RICH/CHIR vault shares should be transferred out of CHIR contract");
    }
}
