// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {
    IERC20PermitMintBurnLockedOwnableDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20PermitMintBurnLockedOwnableDFPkg.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    TestBase_AerodromeStandardExchange
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";

import {IBaseProtocolDETFDFPkg, BaseProtocolDETFDFPkg} from "contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol";
import {IProtocolNFTVaultDFPkg, ProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg, RICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {BaseProtocolDETF_Component_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";

import {
    IAerodromeStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";

/* -------------------------------------------------------------------------- */
/*                                  Test Base                                 */
/* -------------------------------------------------------------------------- */

/**
 * @title TestBase_BaseBaseProtocolDETF
 * @notice Base test contract for Protocol DETF tests.
 * @dev Provides infrastructure for testing:
 *      - CHIR minting with WETH
 *      - WETH and RICH bonding
 *      - NFT vault operations
 *      - RICHIR rebasing and redemption
 *      - Seigniorage capture
 */
contract TestBase_BaseProtocolDETF is TestBase_AerodromeStandardExchange {
    using BaseProtocolDETF_Facet_FactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Pkg_FactoryService for IVaultRegistryDeployment;
    using BetterEfficientHashLib for bytes;

    /* ---------------------------------------------------------------------- */
    /*                              Test Constants                            */
    /* ---------------------------------------------------------------------- */

    uint256 internal constant INITIAL_WETH_MINT = 1_000_000e18;
    uint256 internal constant INITIAL_RICH_MINT = 10_000_000e18;
    uint256 internal constant MINT_AMOUNT = 1000e18;
    uint256 internal constant BOND_AMOUNT = 100e18;

    uint256 internal constant MIN_LOCK_DURATION = 1 days;
    uint256 internal constant MAX_LOCK_DURATION = 365 days;
    uint256 internal constant DEFAULT_LOCK_DURATION = 30 days;

    uint256 internal constant MINT_THRESHOLD = 1005e15; // 1.005
    uint256 internal constant BURN_THRESHOLD = 995e15; // 0.995

    /* ---------------------------------------------------------------------- */
    /*                               Test Users                               */
    /* ---------------------------------------------------------------------- */

    address internal alice;
    address internal bob;
    address internal charlie;

    /* ---------------------------------------------------------------------- */
    /*                              Mock Tokens                               */
    /* ---------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------- */
    /*                         Protocol Components                            */
    /* ---------------------------------------------------------------------- */

    // Facets
    IFacet internal erc721Facet;
    IFacet internal protocolDETFExchangeInFacet;
    IFacet internal protocolDETFExchangeOutFacet;
    IFacet internal protocolDETFBondingFacet;
    IFacet internal protocolDETFBridgeFacet;
    IFacet internal protocolNFTVaultFacet;
    IFacet internal richirFacet;

    // Packages
    IBaseProtocolDETFDFPkg internal protocolDETFDFPkg;
    IProtocolNFTVaultDFPkg internal protocolNFTVaultDFPkg;
    IRICHIRDFPkg internal richirDFPkg;
    IERC20PermitMintBurnLockedOwnableDFPkg internal richTokenPkg;
    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;

    // Standard Exchange Vaults
    IStandardExchangeProxy internal chirWethVault;
    IStandardExchangeProxy internal richChirVault;

    // Protocol DETF (CHIR)
    IProtocolDETF internal protocolDETF;
    IERC20 internal chir;

    // RICH token (static supply)
    IERC20 internal rich;

    // Protocol NFT Vault
    IProtocolNFTVault internal protocolNFTVault;

    // RICHIR rebasing token
    IRICHIR internal richir;

    // Reserve pool (Balancer 80/20)
    address internal reservePool;

    // Mocked Balancer V3 components (for unit testing)
    IBalancerVault internal balancerV3Vault;
    IRouter internal balancerV3Router;
    IBalancerV3StandardExchangeRouterPrepay internal balancerV3PrepayRouter;
    IWeightedPool8020Factory internal weightedPool8020Factory;

    /* ---------------------------------------------------------------------- */
    /*                                 Setup                                  */
    /* ---------------------------------------------------------------------- */

    function setUp() public virtual override {
        // Initialize Aerodrome Standard Exchange infrastructure
        TestBase_AerodromeStandardExchange.setUp();

        // Create test users
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy Protocol DETF facets
        _deployProtocolFacets();

        // Deploy Protocol DETF packages
        _deployProtocolPackages();

        // Deploy Standard Exchange vaults for CHIR/WETH and RICH/CHIR
        _deployStandardExchangeVaults();

        // Deploy Protocol DETF (CHIR)
        _deployBaseProtocolDETF();

        // Distribute tokens to users
        _distributeTokens();
    }

    /* ---------------------------------------------------------------------- */
    /*                            Facet Deployment                            */
    /* ---------------------------------------------------------------------- */

    function _deployProtocolFacets() internal virtual {
        // ERC721 facet for NFT vault
        erc721Facet = IFacet(address(new ERC721Facet()));
        vm.label(address(erc721Facet), "ERC721Facet");

        // Protocol DETF facets
        protocolDETFExchangeInFacet = create3Factory.deployBaseProtocolDETFExchangeInFacet();
        protocolDETFExchangeOutFacet = create3Factory.deployBaseProtocolDETFExchangeOutFacet();
        protocolDETFBondingFacet = create3Factory.deployBaseProtocolDETFBondingFacet();
        protocolDETFBridgeFacet = create3Factory.deployBaseProtocolDETFBridgeFacet();

        // Protocol NFT Vault facet
        protocolNFTVaultFacet = create3Factory.deployProtocolNFTVaultFacet();

        // RICHIR facet
        richirFacet = create3Factory.deployRICHIRFacet();
    }

    /* ---------------------------------------------------------------------- */
    /*                           Package Deployment                           */
    /* ---------------------------------------------------------------------- */

    function _deployProtocolPackages() internal virtual {
        // Deploy RICH token package (static supply ERC20)
        // Note: Using the crane ERC20PermitMintBurnLockedOwnableDFPkg
        // TODO: Deploy from factory service

        // Deploy Protocol NFT Vault package
        IProtocolNFTVaultDFPkg.PkgInit memory nftPkgInit = IProtocolNFTVaultDFPkg.PkgInit({
            erc721Facet: erc721Facet,
            erc4626BasicVaultFacet: erc4626BasicVaultFacet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            protocolNFTVaultFacet: protocolNFTVaultFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager))
        });
        protocolNFTVaultDFPkg = IProtocolNFTVaultDFPkg(address(new ProtocolNFTVaultDFPkg(nftPkgInit)));
        vm.label(address(protocolNFTVaultDFPkg), "ProtocolNFTVaultDFPkg");

        // Deploy RICHIR package
        IRICHIRDFPkg.PkgInit memory richirPkgInit = IRICHIRDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            richirFacet: richirFacet,
            diamondFactory: diamondPackageFactory
        });
        richirDFPkg = IRICHIRDFPkg(address(new RICHIRDFPkg(richirPkgInit)));
        vm.label(address(richirDFPkg), "RICHIRDFPkg");
    }

    /* ---------------------------------------------------------------------- */
    /*                    Standard Exchange Vault Deployment                  */
    /* ---------------------------------------------------------------------- */

    function _deployStandardExchangeVaults() internal virtual {
        // Deploy CHIR/WETH Aerodrome Standard Exchange Vault
        // This requires setting up an Aerodrome pool first
        // For unit tests, we'll mock these vaults

        // TODO: Deploy actual Aerodrome pools and vaults for integration tests
        // For now, skip vault deployment in base - subclasses can override
    }

    /* ---------------------------------------------------------------------- */
    /*                       Protocol DETF Deployment                         */
    /* ---------------------------------------------------------------------- */

    function _deployBaseProtocolDETF() internal virtual {
        // Note: Full deployment requires Balancer V3 components and Aerodrome pools
        // For unit tests, we'll need to mock these dependencies
        // Integration tests should use fork tests against Base mainnet

        // TODO: Deploy Protocol DETF package and instance
        // For now, skip in base - subclasses can override for integration tests
    }

    /* ---------------------------------------------------------------------- */
    /*                          Token Distribution                            */
    /* ---------------------------------------------------------------------- */

    function _distributeTokens() internal virtual {
        // Fund users with ETH and wrap into WETH9.
        _fundWeth(alice, INITIAL_WETH_MINT);
        _fundWeth(bob, INITIAL_WETH_MINT);
        _fundWeth(charlie, INITIAL_WETH_MINT);

        // Fund owner for initial liquidity
        _fundWeth(owner, INITIAL_WETH_MINT * 10);
    }

    function _fundWeth(address user, uint256 wethAmount) internal {
        vm.deal(user, wethAmount);
        vm.prank(user);
        weth.deposit{value: wethAmount}();
    }

    /* ---------------------------------------------------------------------- */
    /*                            Helper Functions                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mint CHIR tokens by depositing WETH.
     * @param user The user performing the mint.
     * @param wethAmount The amount of WETH to deposit.
     * @return chirAmount The amount of CHIR received.
     */
    function _mintChir(address user, uint256 wethAmount) internal returns (uint256 chirAmount) {
        vm.startPrank(user);
        IERC20(address(weth)).approve(address(protocolDETF), wethAmount);
        chirAmount = IStandardExchangeIn(address(protocolDETF))
            .exchangeIn(
                IERC20(address(weth)),
                wethAmount,
                chir,
                0, // minAmountOut
                user,
                false, // not pretransferred
                block.timestamp + 1 hours
            );
        vm.stopPrank();
    }

    /**
     * @notice Bond with WETH to create an NFT position.
     * @param user The user performing the bond.
     * @param wethAmount The amount of WETH to bond.
     * @param lockDuration The lock duration for the NFT.
     * @return tokenId The NFT token ID.
     */
    function _bondWithWeth(address user, uint256 wethAmount, uint256 lockDuration) internal returns (uint256 tokenId) {
        vm.startPrank(user);
        IERC20(address(weth)).approve(address(protocolDETF), wethAmount);
        (tokenId,) = IBaseProtocolDETFBonding(address(protocolDETF))
            .bond(IERC20(address(weth)), wethAmount, lockDuration, user, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /**
     * @notice Bond with RICH to create an NFT position.
     * @param user The user performing the bond.
     * @param richAmount The amount of RICH to bond.
     * @param lockDuration The lock duration for the NFT.
     * @return tokenId The NFT token ID.
     */
    function _bondWithRich(address user, uint256 richAmount, uint256 lockDuration) internal returns (uint256 tokenId) {
        vm.startPrank(user);
        rich.approve(address(protocolDETF), richAmount);
        (tokenId,) = IBaseProtocolDETFBonding(address(protocolDETF))
            .bond(rich, richAmount, lockDuration, user, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /**
     * @notice Sell an NFT to the protocol for RICHIR.
     * @param user The user selling the NFT.
     * @return richirAmount The amount of RICHIR received.
     */
    function _sellNFT(address user, uint256 tokenId) internal returns (uint256 richirAmount) {
        vm.startPrank(user);
        richirAmount = IBaseProtocolDETFBonding(address(protocolDETF)).sellNFT(tokenId, user);
        vm.stopPrank();
    }

    /**
     * @notice Redeem RICHIR for WETH.
     * @param user The user redeeming.
     * @param richirAmount The amount of RICHIR to redeem.
     * @return wethAmount The amount of WETH received.
     */
    function _redeemRichir(address user, uint256 richirAmount) internal returns (uint256 wethAmount) {
        vm.startPrank(user);
        wethAmount = richir.redeem(richirAmount, user, false);
        vm.stopPrank();
    }

    /**
     * @notice Calculate synthetic price from pool reserves.
     * @dev synthetic_price = (St / G) * (CHIR_gas / CHIR_static)
     */
    function _calcSyntheticPrice(
        uint256 chirInWethPool,
        uint256 wethInWethPool,
        uint256 chirInRichPool,
        uint256 richInRichPool
    ) internal pure returns (uint256) {
        if (chirInRichPool == 0 || wethInWethPool == 0) return 0;
        return (richInRichPool * chirInWethPool * ONE_WAD) / (wethInWethPool * chirInRichPool);
    }

    /**
     * @notice Skip time by a given duration.
     */
    function _skipTime(uint256 duration) internal {
        skip(duration);
    }

    /**
     * @notice Warp to a position's unlock time.
     */
    function _warpToUnlock(uint256 tokenId) internal {
        IProtocolNFTVault.Position memory pos = protocolNFTVault.getPosition(tokenId);
        vm.warp(pos.unlockTime);
    }
}
