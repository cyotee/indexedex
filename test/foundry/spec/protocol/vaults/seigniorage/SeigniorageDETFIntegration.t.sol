// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {PoolRoleAccounts} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";

import {IVaultMock} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/IVaultMock.sol";

import {
    WeightedPool8020Factory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";

import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
import {
    CastingHelpers
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/CastingHelpers.sol";

// Crane IERC20 imported below

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {
    IERC20PermitMintBurnLockedOwnableDFPkg,
    ERC20PermitMintBurnLockedOwnableDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20PermitMintBurnLockedOwnableDFPkg.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";
import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {ISeigniorageDETFUnderwriting} from "contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol";

import {ISeigniorageDETFDFPkg, SeigniorageDETFDFPkg} from "contracts/vaults/seigniorage/SeigniorageDETFDFPkg.sol";

import {
    ISeigniorageNFTVaultDFPkg,
    SeigniorageNFTVaultDFPkg
} from "contracts/vaults/seigniorage/SeigniorageNFTVaultDFPkg.sol";

import {
    Seigniorage_Component_FactoryService
} from "contracts/vaults/seigniorage/Seigniorage_Component_FactoryService.sol";
import {ERC4626BasedBasicVaultFacet} from "contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol";
import {ERC4626StandardVaultFacet} from "contracts/vaults/standard/ERC4626StandardVaultFacet.sol";

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

/* -------------------------------------------------------------------------- */
/*                               Test-Only Mocks                              */
/* -------------------------------------------------------------------------- */

contract MockSeigniorageNFTVaultDFPkg is SeigniorageNFTVaultDFPkg {
    constructor(PkgInit memory pkgInit) SeigniorageNFTVaultDFPkg(pkgInit) {}

    function processArgs(bytes memory pkgArgs) public pure override returns (bytes memory) {
        return pkgArgs;
    }
}

/* -------------------------------------------------------------------------- */
/*                              Integration Tests                             */
/* -------------------------------------------------------------------------- */

contract SeigniorageDETFIntegration_Test is TestBase_BalancerV3StandardExchangeRouter {
    using Seigniorage_Component_FactoryService for *;
    using BetterAddress for address;
    using CastingHelpers for address[];

    uint256 internal constant UNDERWRITE_AMOUNT = 1_000e18;
    uint256 internal constant LOCK_DURATION = 30 days;
    // Hardcoded reserve pool weights in production:
    // - DETF token: 80%
    // - reserve vault token: 20%
    uint256 internal constant RESERVE_VAULT_WEIGHT = 20e16;
    uint256 internal constant SELF_WEIGHT = 80e16;
    uint256 internal constant DEFAULT_SWAP_FEE = 1e16;

    // Deployed components
    WeightedPool8020Factory internal weighted8020Factory;
    RateProviderMock internal reserveVaultRateProvider;

    ISeigniorageDETFDFPkg internal detfDFPkg;
    ISeigniorageDETF internal detf;

    address internal reservePoolAddress;

    struct DeploymentScenario {
        address detfPredicted;
        address poolPredicted;
        uint256 reserveVaultIndex;
        uint256 selfIndex;
        uint256[] poolWeights;
        ISeigniorageDETFDFPkg.PkgArgs pkgArgs;
    }

    function setUp() public override {
        super.setUp();

        // SeigniorageDETFDFPkg sources the pool swap fee from the fee oracle.
        // Ensure it's non-zero so WeightedPool8020Factory.create doesn't revert.
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultDexSwapFeeOfTypeId(type(ISeigniorageDETFUnderwriting).interfaceId, DEFAULT_SWAP_FEE);

        _deployWeightedPool8020Factory();
        _deploySeigniorageDetf();
    }

    function _deployWeightedPool8020Factory() internal {
        // Deploy a WeightedPool8020Factory via CREATE3 (avoid `new` in this repo).
        bytes32 salt = keccak256("SeigniorageWeightedPool8020Factory");
        bytes memory initCode = type(WeightedPool8020Factory).creationCode;
        bytes memory initArgs = abi.encode(IVault(address(vault)), uint32(365 days), "Factory v1", "8020Pool v1");

        address factoryAddr = create3Factory.create3WithArgs(initCode, initArgs, salt);

        weighted8020Factory = WeightedPool8020Factory(factoryAddr);
        vm.label(factoryAddr, "WeightedPool8020Factory");

        // Deploy a constant 1.0 rate provider for reserve vault shares.
        bytes32 rpSalt = keccak256("SeigniorageReserveVaultRateProvider");

        address rpAddr = create3Factory.create3(type(RateProviderMock).creationCode, rpSalt);

        reserveVaultRateProvider = RateProviderMock(rpAddr);
        vm.label(rpAddr, "ReserveVaultRateProvider");
    }

    function _deploySeigniorageDetf() internal {
        // Reserve vault is the Aerodrome Standard Exchange vault deployed by the inherited base.
        IStandardExchangeProxy reserveVault = daiUsdcVault;

        (IFacet exchangeInFacet, IFacet exchangeOutFacet, IFacet underwritingFacet, IFacet nftVaultFacet) =
            _deploySeigniorageFacets();
        IFacet erc721Facet = _deployERC721Facet();
        ISeigniorageNFTVaultDFPkg nftVaultPkg = _deployMockNftVaultPkg(erc721Facet, nftVaultFacet);
        IERC20PermitMintBurnLockedOwnableDFPkg seigniorageTokenPkg = _deploySeigniorageTokenPkg();

        IStandardExchangeRateProviderDFPkg reserveVaultRateProviderPkg = _deployStandardExchangeRateProviderPkg();

        detfDFPkg = _deployDetfPkg(
            exchangeInFacet,
            exchangeOutFacet,
            underwritingFacet,
            seigniorageTokenPkg,
            nftVaultPkg,
            reserveVaultRateProviderPkg
        );
        vm.label(address(detfDFPkg), "SeigniorageDETFDFPkg");

        // Ensure the deployed package is registered in the vault registry before deploying a vault.
        // `deployVault` will revert with `PkgNotRegistered` otherwise.
        vm.startPrank(owner);
        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(address(detfDFPkg), IStandardVaultPkg(address(detfDFPkg)).vaultDeclaration());
        vm.stopPrank();

        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(detfDFPkg)),
            "DETF package not registered"
        );

        DeploymentScenario memory s = _computeDeploymentScenario(reserveVault);

        // Deploy DETF first so its address has code before Balancer pool registration.
        // (Balancer calls `decimals()` on pool tokens during `registerPool`.)
        vm.startPrank(owner);
        address detfAddr = IVaultRegistryDeployment(address(indexedexManager))
            .deployVault(IStandardVaultPkg(address(detfDFPkg)), abi.encode(s.pkgArgs));
        vm.stopPrank();
        assertEq(detfAddr, s.detfPredicted, "DETF predicted address mismatch");

        detf = ISeigniorageDETF(detfAddr);
        vm.label(detfAddr, "SeigniorageDETF");

        // Reserve pool is created by the DETF package during postDeploy().
        // WeightedPool8020Factory.getPool(high, low) expects (80% token, 20% token).
        reservePoolAddress = weighted8020Factory.getPool(IERC20(detfAddr), IERC20(address(reserveVault)));
        vm.label(reservePoolAddress, "SeigniorageReservePool8020");

        assertEq(detf.reservePool(), reservePoolAddress, "DETF reservePool mismatch");
        assertTrue(reservePoolAddress.isContract(), "Reserve pool not deployed");
    }

    function _deploySeigniorageFacets()
        internal
        returns (IFacet exchangeInFacet, IFacet exchangeOutFacet, IFacet underwritingFacet, IFacet nftVaultFacet)
    {
        exchangeInFacet = create3Factory.deploySeigniorageDETFExchangeInFacet();
        exchangeOutFacet = create3Factory.deploySeigniorageDETFExchangeOutFacet();
        underwritingFacet = create3Factory.deploySeigniorageDETFUnderwritingFacet();
        nftVaultFacet = create3Factory.deploySeigniorageNFTVaultFacet();
    }

    function _deployVaultViewFacets() internal returns (IFacet basicVaultFacet, IFacet standardVaultFacet) {
        if (address(erc4626BasicVaultFacet) == address(0)) {
            erc4626BasicVaultFacet = IFacet(
                create3Factory.deployFacet(
                    type(ERC4626BasedBasicVaultFacet).creationCode, keccak256("ERC4626BasedBasicVaultFacet")
                )
            );
            vm.label(address(erc4626BasicVaultFacet), "ERC4626BasedBasicVaultFacet");
        }
        if (address(erc4626StandardVaultFacet) == address(0)) {
            erc4626StandardVaultFacet = IFacet(
                create3Factory.deployFacet(
                    type(ERC4626StandardVaultFacet).creationCode, keccak256("ERC4626StandardVaultFacet")
                )
            );
            vm.label(address(erc4626StandardVaultFacet), "ERC4626StandardVaultFacet");
        }

        return (erc4626BasicVaultFacet, erc4626StandardVaultFacet);
    }

    function _deployERC721Facet() internal returns (IFacet erc721Facet) {
        bytes32 facetSalt = keccak256("SeigniorageERC721Facet");
        erc721Facet = IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, facetSalt));
    }

    function _deployERC20MintBurnOwnableFacet() internal returns (IFacet facet) {
        bytes32 facetSalt = keccak256("SeigniorageERC20MintBurnOwnableFacet");
        facet = IFacet(create3Factory.deployFacet(type(ERC20MintBurnOwnableFacet).creationCode, facetSalt));
        vm.label(address(facet), "ERC20MintBurnOwnableFacet");
    }

    function _deployMockNftVaultPkg(IFacet erc721Facet, IFacet seigniorageNFTVaultFacet)
        internal
        returns (ISeigniorageNFTVaultDFPkg nftVaultPkg)
    {
        (IFacet basicVaultFacet, IFacet standardVaultFacet) = _deployVaultViewFacets();

        ISeigniorageNFTVaultDFPkg.PkgInit memory nftPkgInit = ISeigniorageNFTVaultDFPkg.PkgInit({
            erc721Facet: erc721Facet,
            erc4626BasicVaultFacet: basicVaultFacet,
            erc4626StandardVaultFacet: standardVaultFacet,
            seigniorageNFTVaultFacet: seigniorageNFTVaultFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager))
        });

        bytes memory initArgs = abi.encode(nftPkgInit);
        bytes memory initCode = type(MockSeigniorageNFTVaultDFPkg).creationCode;

        address pkgAddr = create3Factory.create3WithArgs(initCode, initArgs, keccak256("MockSeigniorageNFTVaultDFPkg"));

        nftVaultPkg = ISeigniorageNFTVaultDFPkg(pkgAddr);
        vm.label(pkgAddr, "MockSeigniorageNFTVaultDFPkg");

        // `SeigniorageNFTVaultDFPkg.deployVault()` routes through `IVaultRegistryDeployment.deployVault`,
        // which requires the package to be registered, even in tests.
        vm.startPrank(owner);
        IVaultRegistryVaultPackageManager(address(indexedexManager))
            .registerPackage(pkgAddr, IStandardVaultPkg(pkgAddr).vaultDeclaration());
        vm.stopPrank();

        assertTrue(
            IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(pkgAddr),
            "NFT vault package not registered"
        );
    }

    function _deploySeigniorageTokenPkg()
        internal
        returns (IERC20PermitMintBurnLockedOwnableDFPkg seigniorageTokenPkg)
    {
        bytes32 pkgSalt = keccak256("ERC20PermitMintBurnLockedOwnableDFPkg");

        IFacet mintBurnFacet = _deployERC20MintBurnOwnableFacet();

        IERC20PermitMintBurnLockedOwnableDFPkg.PkgInit memory pkgInit = IERC20PermitMintBurnLockedOwnableDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            erc20MintBurnOwnableFacet: mintBurnFacet,
            diamondFactory: diamondPackageFactory
        });

        seigniorageTokenPkg = IERC20PermitMintBurnLockedOwnableDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitMintBurnLockedOwnableDFPkg).creationCode, abi.encode(pkgInit), pkgSalt
                )
            )
        );
        vm.label(address(seigniorageTokenPkg), "ERC20PermitMintBurnLockedOwnableDFPkg");
    }

    function _deployDetfPkg(
        IFacet exchangeInFacet,
        IFacet exchangeOutFacet,
        IFacet underwritingFacet,
        IERC20PermitMintBurnLockedOwnableDFPkg seigniorageTokenPkg,
        ISeigniorageNFTVaultDFPkg nftVaultPkg,
        IStandardExchangeRateProviderDFPkg reserveVaultRateProviderPkg
    ) internal returns (ISeigniorageDETFDFPkg) {
        (IFacet basicVaultFacet, IFacet standardVaultFacet) = _deployVaultViewFacets();

        ISeigniorageDETFDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.erc4626BasicVaultFacet = basicVaultFacet;
        pkgInit.erc4626StandardVaultFacet = standardVaultFacet;
        pkgInit.seigniorageDETFExchangeInFacet = exchangeInFacet;
        pkgInit.seigniorageDETFExchangeOutFacet = exchangeOutFacet;
        pkgInit.seigniorageDETFUnderwritingFacet = underwritingFacet;
        pkgInit.feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.permit2 = permit2;
        pkgInit.balancerV3Vault = IVault(address(vault));
        pkgInit.balancerV3Router = IRouter(address(router));
        pkgInit.balancerV3PrepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(seRouter));
        pkgInit.weightedPool8020Factory = IWeightedPool8020Factory(address(weighted8020Factory));
        pkgInit.diamondFactory = diamondPackageFactory;
        pkgInit.seigniorageTokenPkg = seigniorageTokenPkg;
        pkgInit.seigniorageNFTVaultPkg = nftVaultPkg;
        pkgInit.reserveVaultRateProviderPkg = reserveVaultRateProviderPkg;

        // `indexedexManager.deployPkg(...)` is guarded by OperableRepo._onlyOwnerOrOperator.
        // The manager diamond does not expose `setOperator`, so perform deployments as its owner.
        vm.startPrank(owner);
        ISeigniorageDETFDFPkg pkg = Seigniorage_Component_FactoryService.deploySeigniorageDETFDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        return pkg;
    }

    function _deployStandardExchangeRateProviderPkg() internal returns (IStandardExchangeRateProviderDFPkg pkg) {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode, keccak256("StandardExchangeRateProviderFacet")
            )
        );
        vm.label(address(rateProviderFacet), "StandardExchangeRateProviderFacet");

        IStandardExchangeRateProviderDFPkg.PkgInit memory pkgInit = IStandardExchangeRateProviderDFPkg.PkgInit({
            rateProviderFacet: rateProviderFacet, diamondFactory: diamondPackageFactory
        });

        bytes32 pkgSalt = keccak256("StandardExchangeRateProviderDFPkg");

        pkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode, abi.encode(pkgInit), pkgSalt
                )
            )
        );
        vm.label(address(pkg), "StandardExchangeRateProviderDFPkg");
    }

    function _computeDeploymentScenario(IStandardExchangeProxy reserveVault)
        internal
        view
        returns (DeploymentScenario memory s)
    {
        // NOTE: with the 80/20 factory, the pool address depends on the final DETF address.
        // We can compute the predicted DETF address here, but must not call `getPool()` until
        // after the DETF is deployed (the factory queries token metadata).
        ISeigniorageDETFDFPkg.PkgArgs memory pkgArgsA;
        pkgArgsA.name = "Seigniorage DETF";
        pkgArgsA.symbol = "RBT";
        pkgArgsA.reserveVault = reserveVault;
        pkgArgsA.reserveVaultRateTarget = IERC20Metadata(address(dai));
        address detfPredictedA =
            diamondPackageFactory.calcAddress(IDiamondFactoryPackage(address(detfDFPkg)), abi.encode(pkgArgsA));

        (uint256 selfIndex, uint256 reserveVaultIndex) = detfPredictedA < address(reserveVault) ? (0, 1) : (1, 0);

        s = DeploymentScenario({
            detfPredicted: detfPredictedA,
            poolPredicted: address(0),
            reserveVaultIndex: reserveVaultIndex,
            selfIndex: selfIndex,
            poolWeights: new uint256[](0),
            pkgArgs: pkgArgsA
        });
    }

    function _mintReserveAssetTo(address user, uint256 tokenAmount) internal returns (uint256 liquidity) {
        dai.mint(user, tokenAmount);
        usdc.mint(user, tokenAmount);

        vm.startPrank(user);
        dai.approve(address(aerodromeRouter), tokenAmount);
        usdc.approve(address(aerodromeRouter), tokenAmount);

        (,, liquidity) = aerodromeRouter.addLiquidity(
            address(dai), address(usdc), false, tokenAmount, tokenAmount, 1, 1, user, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                                   Tests                                */
    /* ---------------------------------------------------------------------- */

    function test_integration_previewUnderwrite_matches_lockInfoShares() public {
        // Seed the reserve vault so its rate provider returns a non-zero rate during the first preview.
        _mintVaultShares(owner, 1e18);

        IERC20 reserveAsset = _vaultAsset();
        uint256 assetIn = _mintReserveAssetTo(alice, UNDERWRITE_AMOUNT);

        // Preview
        (uint256 originalShares, uint256 effectiveShares, uint256 bonusMultiplier) = ISeigniorageDETFUnderwriting(
                address(detf)
            ).previewUnderwrite(IERC20(address(reserveAsset)), assetIn, LOCK_DURATION);

        assertGt(originalShares, 0, "preview originalShares should be > 0");
        assertGt(effectiveShares, 0, "preview effectiveShares should be > 0");
        assertGe(bonusMultiplier, FixedPoint.ONE, "bonusMultiplier should be >= 1x");

        // Underwrite
        vm.startPrank(alice);
        reserveAsset.approve(address(detf), assetIn);
        uint256 tokenId = detf.underwrite(IERC20(address(reserveAsset)), assetIn, LOCK_DURATION, alice, false);
        vm.stopPrank();

        ISeigniorageNFTVault.LockInfo memory info = detf.seigniorageNFTVault().lockInfoOf(tokenId);
        assertEq(info.sharesAwarded, originalShares, "lockInfo sharesAwarded mismatch");
        assertEq(info.bonusPercentage, bonusMultiplier, "lockInfo bonusPercentage mismatch");
    }

    function test_integration_underwrite_then_redeem_returns_rateTarget() public {
        // Seed the reserve vault so its rate provider returns a non-zero rate during the first deposit path.
        _mintVaultShares(owner, 1e18);

        IERC20 reserveAsset = _vaultAsset();
        uint256 assetIn = _mintReserveAssetTo(alice, UNDERWRITE_AMOUNT);

        uint256 assetBalanceBefore = reserveAsset.balanceOf(alice);

        vm.startPrank(alice);
        reserveAsset.approve(address(detf), assetIn);
        uint256 tokenId = detf.underwrite(IERC20(address(reserveAsset)), assetIn, LOCK_DURATION, alice, false);
        // Underwrite consumes the input
        assertEq(
            reserveAsset.balanceOf(alice),
            assetBalanceBefore - assetIn,
            "reserve asset should be spent into underwriting"
        );

        // Warp beyond lock duration and redeem.
        vm.warp(block.timestamp + LOCK_DURATION + 1);
        uint256 daiOut = ISeigniorageDETFUnderwriting(address(detf)).redeem(tokenId, alice);
        vm.stopPrank();

        assertGt(daiOut, 0, "redeem should return some rate target");
        assertGt(dai.balanceOf(alice), 0, "alice should receive rate target on redeem");
    }

    function test_integration_underwrite_invalidToken_reverts() public {
        // WETH is not a configured reserve vault token for this DETF.
        deal(alice, UNDERWRITE_AMOUNT);
        vm.startPrank(alice);
        weth.deposit{value: UNDERWRITE_AMOUNT}();
        weth.approve(address(detf), UNDERWRITE_AMOUNT);
        vm.expectRevert();
        detf.underwrite(IERC20(address(weth)), UNDERWRITE_AMOUNT, LOCK_DURATION, alice, false);
        vm.stopPrank();
    }
}
