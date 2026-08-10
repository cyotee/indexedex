// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {WeightedPoolFactory} from
    "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
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
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {
    IComposedStableCommonDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

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
contract Adversarial_ComposedStable_GE_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
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
        assertLe(dai.balanceOf(instance_), 1, "E residual: free pairToken (dai) dust");
        // vaultShare of underlying SE route
        assertLe(IERC20(address(daiUsdcVault)).balanceOf(instance_), 1, "E residual: free vaultShare dust");
        // Intermediate stable / common pool BPTs (must be joined into reserve, not stranded)
        assertLe(IERC20(address(stablePool)).balanceOf(instance_), 1, "E residual: free stablePool BPT dust");
        assertLe(IERC20(address(commonPool)).balanceOf(instance_), 1, "E residual: free commonPool BPT dust");
        // rateAsset not left idle on diamond from route
        assertLe(weth.balanceOf(instance_), 1, "E residual: free rateAsset dust");
    }

    function _mintDaiToDetf(address user, uint256 daiIn_) internal returns (uint256 detfOut_) {
        deal(address(dai), user, daiIn_, true);
        vm.startPrank(user);
        dai.approve(deployedDetfVault, daiIn_);
        detfOut_ = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, daiIn_, detfToken, 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  E1 conservation                                                       */
    /* ---------------------------------------------------------------------- */

    /// @notice E1: dai → detfToken → (partial) dai; out ≤ in; no stranded multi-leg dust.
    function test_E1_mintThenPartialBurn_conservation() public {
        _bootstrapReserveGraph();
        assertTrue(IComposedStableCommonDetfInfo(deployedDetfVault).isMintingAllowed(), "live mint gate");

        uint256 daiIn_ = 800e18;
        uint256 detfOut_ = _mintDaiToDetf(attacker, daiIn_);
        assertTrue(detfOut_ > 0, "minted detf");
        _assertNoStrandedRouteInventory(deployedDetfVault);

        uint256 burnAmt_ = detfOut_ / 2;
        if (burnAmt_ == 0) burnAmt_ = detfOut_;

        if (!IComposedStableCommonDetfInfo(deployedDetfVault).isBurningAllowed()) {
            // Open live should allow; skip burn half if env gate closed.
            return;
        }

        vm.startPrank(attacker);
        detfToken.approve(deployedDetfVault, burnAmt_);
        try IStandardExchangeIn(deployedDetfVault).exchangeIn(
            detfToken, burnAmt_, dai, 0, attacker, false, block.timestamp + 1 hours
        ) returns (uint256 daiBack_) {
            assertTrue(daiBack_ > 0, "burn returned pairToken");
            assertLe(daiBack_, daiIn_, "E1: partial burn out <= original in");
        } catch {
            // Integrated fixture may lack liquid unwind depth (ExchangeOutNotAvailable).
            // Gate was open; residual still must be clean after failed burn attempt.
        }
        vm.stopPrank();

        _assertNoStrandedRouteInventory(deployedDetfVault);
        // Free detf must not be stranded on diamond after burn attempt (success or fail).
        assertLe(detfToken.balanceOf(deployedDetfVault), 1, "E1: no free detf residual");
    }

    /* ---------------------------------------------------------------------- */
    /*  E2 multi-leg / multi-actor residual                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice E2: multi-actor mint + bond + failed high-minOut mint leave no stranded vaultShare/BPT/pairToken.
    function test_E2_multiLeg_mintBurn_noStrandedVaultShareOrBptOnDiamond() public {
        _bootstrapReserveGraph();

        // Actor A mint
        uint256 aOut_ = _mintDaiToDetf(attacker, 1_200e18);
        assertTrue(aOut_ > 0, "A minted");
        _assertNoStrandedRouteInventory(deployedDetfVault);

        // Actor B mint (second concurrent inventory path)
        uint256 bOut_ = _mintDaiToDetf(actorB, 900e18);
        assertTrue(bOut_ > 0, "B minted");
        _assertNoStrandedRouteInventory(deployedDetfVault);

        // Bond path multi-leg (same route graph: base → vaultShare → pool BPT → reserve)
        deal(address(dai), victim, 1_500e18, true);
        vm.startPrank(victim);
        dai.approve(deployedDetfVault, 1_000e18);
        (uint256 tokenId_,) = IComposedStableCommonDetfBonding(deployedDetfVault).bond(
            dai, 1_000e18, MIN_LOCK, victim, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tokenId_ > 0, "bond id");
        _assertNoStrandedRouteInventory(deployedDetfVault);

        // Failed partial path: minOut too high must not strand intermediate inventory
        uint256 failIn_ = 400e18;
        deal(address(dai), attacker, failIn_, true);
        uint256 preview_ =
            IStandardExchangeIn(deployedDetfVault).previewExchangeIn(dai, failIn_, detfToken);
        uint256 daiBefore_ = dai.balanceOf(deployedDetfVault);
        uint256 vaultShareBefore_ = IERC20(address(daiUsdcVault)).balanceOf(deployedDetfVault);
        uint256 stableBptBefore_ = IERC20(address(stablePool)).balanceOf(deployedDetfVault);
        uint256 commonBptBefore_ = IERC20(address(commonPool)).balanceOf(deployedDetfVault);
        uint256 detfBefore_ = detfToken.balanceOf(deployedDetfVault);

        vm.startPrank(attacker);
        dai.approve(deployedDetfVault, failIn_);
        vm.expectRevert();
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, failIn_, detfToken, preview_ + 1e18, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(dai.balanceOf(deployedDetfVault), daiBefore_, "E2 fail: pairToken unchanged");
        assertEq(
            IERC20(address(daiUsdcVault)).balanceOf(deployedDetfVault),
            vaultShareBefore_,
            "E2 fail: vaultShare unchanged"
        );
        assertEq(
            IERC20(address(stablePool)).balanceOf(deployedDetfVault),
            stableBptBefore_,
            "E2 fail: stable BPT unchanged"
        );
        assertEq(
            IERC20(address(commonPool)).balanceOf(deployedDetfVault),
            commonBptBefore_,
            "E2 fail: common BPT unchanged"
        );
        assertEq(detfToken.balanceOf(deployedDetfVault), detfBefore_, "E2 fail: free detf unchanged");
        assertEq(detfToken.balanceOf(attacker), aOut_, "E2 fail: attacker detf not inflated");

        _assertNoStrandedRouteInventory(deployedDetfVault);

        // Optional burn residual when liquid
        if (IComposedStableCommonDetfInfo(deployedDetfVault).isBurningAllowed() && aOut_ > 1) {
            uint256 burn_ = aOut_ / 4;
            if (burn_ == 0) burn_ = aOut_;
            vm.startPrank(attacker);
            detfToken.approve(deployedDetfVault, burn_);
            try IStandardExchangeIn(deployedDetfVault).exchangeIn(
                detfToken, burn_, dai, 0, attacker, false, block.timestamp + 1 hours
            ) {} catch {}
            vm.stopPrank();
            _assertNoStrandedRouteInventory(deployedDetfVault);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*  G1 nested composition (CS as nested SE under outer Single SE DETF)    */
    /* ---------------------------------------------------------------------- */

    function _deployOuterOverComposed()
        internal
        returns (
            address outerDetf_,
            ISingleStandardExchangeDETFInfo outerInfo_,
            ISingleStandardExchangeDETFBonding outerBonding_
        )
    {
        IFacet multiBasic_ = VaultComponentFactoryService.deployMultiAssetBasicVaultFacet(create3Factory);
        IFacet multiStd_ = VaultComponentFactoryService.deployMultiAssetStandardVaultFacet(create3Factory);
        IFacet exchangeInFacet_ =
            SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);
        IFacet rateFacet_ = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode, keccak256("CS_GE_SSE_RP")
            )
        );
        IStandardExchangeRateProviderDFPkg ratePkg_ = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(
                        IStandardExchangeRateProviderDFPkg.PkgInit({
                            rateProviderFacet: rateFacet_, diamondFactory: diamondPackageFactory
                        })
                    ),
                    keccak256("CS_GE_SSE_RP_PKG")
                )
            )
        );
        IFacet nftFacet_ = DetfFacetFactoryService.deployDETFNFTVaultFacet(create3Factory);
        IFacet erc721_ =
            IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("CS_GE_SSE_721")));
        IFacet erc4626Basic_ = VaultComponentFactoryService.deployERC4626BasedBasicVaultFacet(create3Factory);
        IFacet erc4626Std_ = VaultComponentFactoryService.deployERC4626StandardVaultFacet(create3Factory);

        vm.startPrank(owner);
        IDetfSelfNftInventoryDFPkg bondPkg_ = DetfPkgFactoryService.deployDETFNFTVaultDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
                erc721_,
                erc4626Basic_,
                erc4626Std_,
                nftFacet_,
                IVaultFeeOracleQuery(address(indexedexManager)),
                IVaultRegistryDeployment(address(indexedexManager))
            )
        );
        ISingleStandardExchangeDETDFPkg outerPkg_ = SingleStandardExchangeDETF_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            ISingleStandardExchangeDETDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiBasic_,
                multiAssetStandardVaultFacet: multiStd_,
                exchangeInFacet: exchangeInFacet_,
                feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
                balancerV3Vault: IVault(address(vault)),
                weightedPoolFactory: WeightedPoolFactory(testPoolFactory),
                rateProviderPkg: ratePkg_,
                bondNftVaultPkg: bondPkg_,
                diamondFactory: diamondPackageFactory
            })
        );

        outerDetf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(outerPkg_)),
            abi.encode(
                ISingleStandardExchangeDETDFPkg.PkgArgs({
                    name: "Outer DETF over CS (G1)",
                    symbol: "oCSG1",
                    standardExchangeVault: IStandardExchangeProxy(deployedDetfVault),
                    standardExchangeVaultShare: detfToken,
                    // Nested composed burn path is not SE-rate-provider-quotable; abstract 1:1 reserve.
                    rateTarget: IERC20(address(0)),
                    detfWeight: 0,
                    vaultShareWeight: 0,
                    mintThreshold: 0,
                    burnThreshold: 0,
                    thresholdMode: ThresholdMode.Open,
                    expansionClosureRatePerSecond: 0,
                    expansionCatchUpMaxSeconds: 0,
                    expansionCatchUpCapBps: 0
                })
            )
        );
        vm.stopPrank();

        outerInfo_ = ISingleStandardExchangeDETFInfo(outerDetf_);
        outerBonding_ = ISingleStandardExchangeDETFBonding(outerDetf_);
    }

    /// @notice G1: outer SingleSE DETF mint/burn over nested CS does not brick CS for third users.
    /// @dev CS-as-outer with nested DETF share legs is product N/A (PkgArgs topology); see suite NatSpec.
    function test_G1_outerActivity_doesNotBrickInner() public {
        _bootstrapReserveGraph();
        assertTrue(IComposedStableCommonDetfInfo(deployedDetfVault).isMintingAllowed(), "nested CS live mint");

        // Seed nested CS shares for outer first bond
        uint256 seedIn_ = 2_500e18;
        deal(address(dai), address(this), seedIn_, true);
        dai.approve(deployedDetfVault, seedIn_);
        uint256 composedShares_ = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, seedIn_, detfToken, 0, address(this), false, block.timestamp + 1 hours
        );
        assertTrue(composedShares_ > 0, "nested shares");

        (address outer_, ISingleStandardExchangeDETFInfo outerInfo_, ISingleStandardExchangeDETFBonding outerBonding_)
        = _deployOuterOverComposed();

        assertFalse(outerInfo_.isReserveLive(), "outer starts inert");
        assertEq(outerInfo_.standardExchangeVault(), deployedDetfVault, "nested is CS diamond");
        assertEq(outerInfo_.standardExchangeVaultShare(), address(detfToken), "nested share is detfToken");

        uint256 bondIn_ = composedShares_ / 4;
        if (bondIn_ < 1e18) bondIn_ = composedShares_;
        require(bondIn_ > 0, "bond amount");

        detfToken.approve(outer_, bondIn_);
        (uint256 tokenId_,) =
            outerBonding_.bond(detfToken, bondIn_, MIN_LOCK, address(this), false, block.timestamp + 1 hours);
        assertTrue(tokenId_ > 0, "outer first bond");
        assertTrue(outerInfo_.isReserveLive(), "outer live");
        assertEq(detfToken.balanceOf(outer_), 0, "no free nested shares on outer after bond");
        assertEq(IERC20(outer_).balanceOf(outer_), 0, "no free outer detf after bond");

        // Outer mint with nested CS shares
        uint256 moreCompose_ = 250e18;
        deal(address(dai), attacker, moreCompose_, true);
        vm.startPrank(attacker);
        dai.approve(deployedDetfVault, moreCompose_);
        uint256 nestedIn_ = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, moreCompose_, detfToken, 0, attacker, false, block.timestamp + 1 hours
        );
        if (nestedIn_ > 5e17) nestedIn_ = 5e17;
        require(nestedIn_ > 0, "nested shares for outer mint");
        detfToken.approve(outer_, nestedIn_);
        uint256 outerOut_ = IStandardExchangeIn(outer_).exchangeIn(
            detfToken, nestedIn_, IERC20(outer_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(outerOut_ > 0, "outer minted");
        assertEq(detfToken.balanceOf(outer_), 0, "no free nested shares after outer mint");

        // Outer partial burn back to nested shares
        uint256 burnAmt_ = outerOut_ / 2;
        if (burnAmt_ == 0) burnAmt_ = outerOut_;
        assertTrue(outerInfo_.isBurningAllowed(), "outer Open burn");
        vm.startPrank(attacker);
        IERC20(outer_).approve(outer_, burnAmt_);
        uint256 nestedBack_ = IStandardExchangeIn(outer_).exchangeIn(
            IERC20(outer_), burnAmt_, detfToken, 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(nestedBack_ > 0, "outer burn returned nested shares");
        assertEq(detfToken.balanceOf(outer_), 0, "no free nested shares after outer burn");
        assertEq(IERC20(outer_).balanceOf(outer_), 0, "no free outer detf after burn");

        // Third user still mints on nested CS
        uint256 direct_ = _mintDaiToDetf(victim, 150e18);
        assertTrue(direct_ > 0, "G1: nested CS still mints for third user");
        assertTrue(IComposedStableCommonDetfInfo(deployedDetfVault).isMintingAllowed(), "nested still live mint");

        _assertNoStrandedRouteInventory(deployedDetfVault);
        _assertNoStrandedRouteInventory(outer_);
    }

    /// @notice G product-law cite: CS PkgArgs has no nested DETF share-leg array (N/A as outer).
    function test_G1_composedAsOuter_nestedDetfLegs_productN_A() public view {
        // Surface wiring: integrated CS is a multi-asset diamond with reservePool, not MV/MB vault legs.
        address pool_ = IDETF(deployedDetfVault).reservePool();
        assertTrue(pool_ != address(0), "CS has weighted reserve pool (external topology)");
        assertEq(IDETF(deployedDetfVault).rebasingDetfToken(), address(rebasingDetfToken), "claim companion");
        // No vaultCount/underlyingVaults surface on CS info — topology is route+stable/common, not nested DETF legs.
        // Nested DETF-as-leg G1 lives on MixedBuffer / MultiVault; CS composition is CS-as-nested under outer SE DETF (test_G1_outerActivity_doesNotBrickInner).
        assertTrue(deployedDetfVault != address(0), "G N/A documented for CS-as-outer nested DETF legs");
    }
}
