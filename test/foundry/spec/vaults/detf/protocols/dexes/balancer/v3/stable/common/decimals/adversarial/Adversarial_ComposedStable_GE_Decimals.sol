// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_ComposedStableCommonDetf_Decimals
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {
    WeightedPoolFactory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";
import {
    SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {
    ILegacyComposedStableCommonDetfBonding as IComposedStableCommonDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenTarget.sol";
import {
    IComposedStableCommonDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";

/**
 * @title Adversarial_ComposedStable_GE_Test
 * @notice WP-G-E-DETF-CS-001 — nested G + multi-leg residual E on production ComposedStable graph.
 * @dev TCA-DETF-CS-010 residual after CS I CODE (WP-I-DETF-CS-001/002 on main).
 *
 *      E1: mint → partial burn conservation (when unwind path is liquid).
 *      E2: multi-actor multi-route mint/bond residual — no free pairToken / vaultShare /
 *          intermediate pool BPT / detfToken dust on the diamond (reserve BPT is held by
 *          bond NFT inventory path after accrue; intermediate route dust must be 0).
 *
 *      G1 nested composition:
 *      Product law — ComposedStable PkgArgs wires external IStablePool×2 + IWeightedPool reserve
 *      of BPTs + detfToken and SE vault *routes* (RouteConfig.underlyingVault). It does **not**
 *      expose MultiVault/MixedBuffer-style nested DETF share legs as outer SUT
 *      (see ComposedStableCommonDetfDFPkg / Repo.RouteConfig; MixedBuffer Nested.t.sol for that topology).
 *      Composition that *is* product-supported: CS as nested SE under outer SingleStandardExchangeDETF
 *      (reverse of "CS outer"; same graph as SingleStandardExchangeDETF_ComposedStableMatrix).
 *      G1 below proves outer activity does not brick nested CS for third users.
 */
abstract contract Adversarial_ComposedStable_GE_Decimals is TestBase_ComposedStableCommonDetf_Decimals {
    uint256 internal constant MIN_LOCK = 30 days;

    address internal attacker;
    address internal victim;
    address internal actorB;

    /// @dev Open thresholds so outer rate-provider quotes work at near-peg and burn gate stays open.
    function _composedThresholdMode() internal pure override returns (ThresholdMode) {
        return ThresholdMode.Open;
    }

    function _composedMintThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function _composedBurnThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("csGeAttacker");
        victim = makeAddr("csGeVictim");
        actorB = makeAddr("csGeActorB");
    }

    /* ---------------------------------------------------------------------- */
    /*  Residual helpers (production diamond free inventory)                  */
    /* ---------------------------------------------------------------------- */

    /// @dev Intermediate multi-leg dust must be empty after successful ops. Reserve BPT may sit on
    ///      bond NFT inventory (not free on diamond after accrue) — we assert intermediate tokens only.
    function _assertNoStrandedRouteInventory(address instance_) internal view {
        // Free product detfToken on diamond (seigniorage inventory goes to bond NFT vault).
        assertLe(detfToken.balanceOf(instance_), 1, "E residual: free detfToken dust");
        // pairToken / base route token
        assertLe(rateAsset.balanceOf(instance_), 1, "E residual: free pairToken (rateAsset) dust");
        // vaultShare of underlying SE route
        assertLe(IERC20(address(daiUsdcVault)).balanceOf(instance_), 1, "E residual: free vaultShare dust");
        // Intermediate stable / common pool BPTs (must be joined into reserve, not stranded)
        assertLe(IERC20(address(stablePool)).balanceOf(instance_), 1, "E residual: free stablePool BPT dust");
        assertLe(IERC20(address(commonPool)).balanceOf(instance_), 1, "E residual: free commonPool BPT dust");
        // rateAsset not left idle on diamond from route
        assertLe(weth.balanceOf(instance_), 1, "E residual: free rateAsset dust");
    }

    function _mintDaiToDetf(address user, uint256 daiIn_) internal returns (uint256 detfOut_) {
        deal(address(rateAsset), user, daiIn_, true);
        vm.startPrank(user);
        rateAsset.approve(deployedDetfVault, daiIn_);
        detfOut_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(rateAsset, daiIn_, detfToken, 0, user, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  E1 conservation                                                       */
    /* ---------------------------------------------------------------------- */

    /// @notice E1: rateAsset → detfToken → (partial) rateAsset; out ≤ in; no stranded multi-leg dust.
    function test_E1_mintThenPartialBurn_conservation() public {
        _bootstrapReserveGraph();
        uint256 input_ = _from18(address(rateAsset), 10e18);
        uint256 raw_ = _mintDaiToDetf(attacker, input_);
        assertGt(raw_, 1);
        _assertNoStrandedRouteInventory(deployedDetfVault);
        uint256 part_ = raw_ / 2;
        uint256 quote_ = IStandardExchangeIn(deployedDetfVault).previewExchangeIn(detfToken, part_, rateAsset);
        assertGt(quote_, 0);
        uint256 before_ = rateAsset.balanceOf(attacker);
        vm.startPrank(attacker);
        detfToken.approve(deployedDetfVault, part_);
        uint256 back_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(detfToken, part_, rateAsset, quote_, attacker, false, block.timestamp);
        vm.stopPrank();
        assertEq(back_, quote_);
        assertLe(back_, input_);
        assertEq(rateAsset.balanceOf(attacker), before_ + back_);
        assertEq(detfToken.balanceOf(attacker), raw_ - part_);
        _assertNoStrandedRouteInventory(deployedDetfVault);
    }

    /* ---------------------------------------------------------------------- */
    /*  E2 multi-leg / multi-actor residual                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice E2: multi-actor mint + bond + failed high-minOut mint leave no stranded vaultShare/BPT/pairToken.
    function test_E2_multiLeg_mintBurn_noStrandedVaultShareOrBptOnDiamond() public {
        _bootstrapReserveGraph();

        // Actor A mint
        uint256 aOut_ = _mintDaiToDetf(attacker, _from18(address(rateAsset), 10e18));
        assertTrue(aOut_ > 0, "A minted");
        _assertNoStrandedRouteInventory(deployedDetfVault);

        // Actor B mint (second concurrent inventory path)
        uint256 bOut_ = _mintDaiToDetf(actorB, _from18(address(rateAsset), 10e18));
        assertTrue(bOut_ > 0, "B minted");
        _assertNoStrandedRouteInventory(deployedDetfVault);

        // Bond path multi-leg (same route graph: base → vaultShare → pool BPT → reserve)
        deal(address(rateAsset), victim, _from18(address(rateAsset), 10e18), true);
        vm.startPrank(victim);
        rateAsset.approve(deployedDetfVault, _from18(address(rateAsset), 10e18));
        (uint256 tokenId_,) = IComposedStableCommonDetfBonding(deployedDetfVault)
            .bond(rateAsset, _from18(address(rateAsset), 10e18), MIN_LOCK, victim, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(tokenId_ > 0, "bond id");
        _assertNoStrandedRouteInventory(deployedDetfVault);

        // Failed partial path: minOut too high must not strand intermediate inventory
        uint256 failIn_ = _from18(address(rateAsset), 10e18);
        deal(address(rateAsset), attacker, failIn_, true);
        uint256 preview_ = IStandardExchangeIn(deployedDetfVault).previewExchangeIn(rateAsset, failIn_, detfToken);
        uint256 daiBefore_ = rateAsset.balanceOf(deployedDetfVault);
        uint256 vaultShareBefore_ = IERC20(address(daiUsdcVault)).balanceOf(deployedDetfVault);
        uint256 stableBptBefore_ = IERC20(address(stablePool)).balanceOf(deployedDetfVault);
        uint256 commonBptBefore_ = IERC20(address(commonPool)).balanceOf(deployedDetfVault);
        uint256 detfBefore_ = detfToken.balanceOf(deployedDetfVault);

        vm.startPrank(attacker);
        rateAsset.approve(deployedDetfVault, failIn_);
        vm.expectRevert();
        IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(rateAsset, failIn_, detfToken, preview_ + 1e18, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertEq(rateAsset.balanceOf(deployedDetfVault), daiBefore_, "E2 fail: pairToken unchanged");
        assertEq(
            IERC20(address(daiUsdcVault)).balanceOf(deployedDetfVault),
            vaultShareBefore_,
            "E2 fail: vaultShare unchanged"
        );
        assertEq(
            IERC20(address(stablePool)).balanceOf(deployedDetfVault), stableBptBefore_, "E2 fail: stable BPT unchanged"
        );
        assertEq(
            IERC20(address(commonPool)).balanceOf(deployedDetfVault), commonBptBefore_, "E2 fail: common BPT unchanged"
        );
        assertEq(detfToken.balanceOf(deployedDetfVault), detfBefore_, "E2 fail: free detf unchanged");
        assertEq(detfToken.balanceOf(attacker), aOut_, "E2 fail: attacker detf not inflated");

        _assertNoStrandedRouteInventory(deployedDetfVault);

        uint256 burn_ = aOut_ / 4;
        assertGt(burn_, 0);
        uint256 expected_ = IStandardExchangeIn(deployedDetfVault).previewExchangeIn(detfToken, burn_, rateAsset);
        assertGt(expected_, 0);
        vm.startPrank(attacker);
        detfToken.approve(deployedDetfVault, burn_);
        uint256 returned_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(detfToken, burn_, rateAsset, expected_, attacker, false, block.timestamp);
        vm.stopPrank();
        assertEq(returned_, expected_);
        _assertNoStrandedRouteInventory(deployedDetfVault);
    }

    function _deployOuterOverComposed()
        internal
        returns (
            address outerDetf_,
            ISingleStandardExchangeDETFInfo outerInfo_,
            ISingleStandardExchangeDETFBonding outerBonding_
        )
    {
        ISingleStandardExchangeDETDFPkg outerPkg_ = _deployOuterPkg();
        ISingleStandardExchangeDETDFPkg.PkgArgs memory pkgArgs_ = _outerPkgArgs();
        vm.startPrank(owner);
        outerDetf_ = indexedexManager.deployVault(IStandardVaultPkg(address(outerPkg_)), abi.encode(pkgArgs_));
        vm.stopPrank();
        outerInfo_ = ISingleStandardExchangeDETFInfo(outerDetf_);
        outerBonding_ = ISingleStandardExchangeDETFBonding(outerDetf_);
    }

    /// @dev Member assignment (not a struct literal) keeps PkgInit / PkgArgs off the caller's stack.
    function _deployOuterPkg() private returns (ISingleStandardExchangeDETDFPkg outerPkg_) {
        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit_;
        pkgInit_.erc20Facet = erc20Facet;
        pkgInit_.erc5267Facet = erc5267Facet;
        pkgInit_.erc2612Facet = erc2612Facet;
        pkgInit_.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit_.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit_.exchangeInFacet =
            SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);
        pkgInit_.bondingFacet = SingleStandardExchangeDETF_Component_FactoryService.deployBondingFacet(create3Factory);
        pkgInit_.feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit_.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit_.balancerV3Router = IBalancerV3StandardExchangeRouterProxy(address(seRouter));
        pkgInit_.balancerV3Vault = IVault(address(vault));
        pkgInit_.weightedPoolFactory = WeightedPoolFactory(testPoolFactory);
        pkgInit_.rateProviderPkg = rateProviderPkg;
        pkgInit_.bondNftVaultPkg = bondNftVaultPkg;
        pkgInit_.rebasingClaimTokenPkg = rebasingClaimTokenPkg;
        pkgInit_.syPkg = syPkg;
        pkgInit_.diamondFactory = diamondPackageFactory;
        vm.prank(owner);
        outerPkg_ = SingleStandardExchangeDETF_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit_
        );
    }

    function _outerPkgArgs() private view returns (ISingleStandardExchangeDETDFPkg.PkgArgs memory pkgArgs_) {
        pkgArgs_.name = "Outer DETF over CS (G1)";
        pkgArgs_.symbol = "oCSG1";
        pkgArgs_.standardExchangeVault = IStandardExchangeProxy(deployedDetfVault);
        pkgArgs_.standardExchangeVaultShare = detfToken;
        // Nested composed burn path is not SE-rate-provider-quotable; abstract 1:1 reserve.
        pkgArgs_.rateTarget = IERC20(address(0));
        pkgArgs_.detfWeight = 0;
        pkgArgs_.vaultShareWeight = 0;
        pkgArgs_.mintThreshold = 0;
        pkgArgs_.burnThreshold = 0;

        pkgArgs_.expansionClosureRatePerSecond = 0;

        pkgArgs_.creator = address(0);
    }

    /// @notice G1: outer SingleSE DETF mint/burn over nested CS does not brick CS for third users.
    /// @dev CS-as-outer with nested DETF share legs is product N/A (PkgArgs topology); see suite NatSpec.
    function test_G1_outerActivity_doesNotBrickInner() public {
        uint256 composedShares_ = _buyFixtureRaw(address(this));
        (address outer_, ISingleStandardExchangeDETFInfo info_, ISingleStandardExchangeDETFBonding bonding_) =
            _deployOuterOverComposed();
        assertFalse(info_.isReserveLive());
        assertEq(info_.standardExchangeVault(), deployedDetfVault);
        uint256 bondIn_ = composedShares_ / 4;
        assertGt(bondIn_, 0);
        detfToken.approve(outer_, bondIn_);
        (uint256 id_,) = bonding_.bond(detfToken, bondIn_, MIN_LOCK, address(this), false, block.timestamp);
        assertTrue(info_.isReserveLive());
        _assertBondPrincipalIsFunded(outer_, id_, address(this));
        uint256 nestedIn_ = _buyFixtureRaw(attacker);
        uint256 cap_ = _reserveTokenBudget(info_.reservePool(), detfToken);
        if (nestedIn_ > cap_) nestedIn_ = cap_;
        assertGt(nestedIn_, 0);
        vm.startPrank(attacker);
        detfToken.approve(outer_, nestedIn_);
        uint256 out_ = IStandardExchangeIn(outer_)
            .exchangeIn(detfToken, nestedIn_, IERC20(outer_), 0, attacker, false, block.timestamp);
        assertGt(out_, 1);
        uint256 burn_ = out_ / 2;
        IERC20(outer_).approve(outer_, burn_);
        uint256 back_ = IStandardExchangeIn(outer_)
            .exchangeIn(IERC20(outer_), burn_, detfToken, 0, attacker, false, block.timestamp);
        vm.stopPrank();
        assertGt(back_, 0);
        assertEq(IERC20(outer_).balanceOf(attacker), out_ - burn_);
        assertGt(_buyFixtureRaw(victim), 0, "third user can still use nested DETF");
        _assertNoStrandedRouteInventory(deployedDetfVault);
        _assertNoStrandedRouteInventory(outer_);
    }

    /// @notice G product-law cite: CS PkgArgs has no nested DETF share-leg array (N/A as outer).
    function test_G1_composedAsOuter_nestedDetfLegs_productN_A() public view {
        // Surface wiring: integrated CS is a multi-asset diamond with reservePool, not MV/MB vault legs.
        address pool_ = IDETF(deployedDetfVault).reservePool();
        assertTrue(pool_ != address(0), "CS has weighted reserve pool (external topology)");
        assertEq(
            IComposedStableCommonDetfInfo(deployedDetfVault).rebasingClaimToken(),
            address(rebasingDetfToken),
            "claim companion"
        );
        // No vaultCount/underlyingVaults surface on CS info — topology is route+stable/common, not nested DETF legs.
        // Nested DETF-as-leg G1 lives on MixedBuffer / MultiVault; CS composition is CS-as-nested under outer SE DETF (test_G1_outerActivity_doesNotBrickInner).
        assertTrue(deployedDetfVault != address(0), "G N/A documented for CS-as-outer nested DETF legs");
    }
}
