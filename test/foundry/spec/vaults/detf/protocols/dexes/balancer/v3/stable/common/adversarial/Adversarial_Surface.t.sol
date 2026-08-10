// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {
    IComposedStableCommonDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/**
 * @title Adversarial_ComposedStable_Surface_Test
 * @notice J1–J3 diamond surface: Target ⊆ facetFuncs ⊆ loupe ⊆ **proxy** smoke (not facet impl alone).
 * @dev WP-J-DETF-CS-MB-001 (CS half). Production DETF proxy via IntegratedDeploy; multi-facet cut.
 *      CS CODE (I suite) already on main — this file is TEST-only surface coverage.
 */
contract Adversarial_ComposedStable_Surface_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    address internal attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("csSurfaceAttacker");
    }

    function _contains(bytes4[] memory arr_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < arr_.length; ++i) {
            if (arr_[i] == sel_) return true;
        }
        return false;
    }

    function _assertFacetFuncsOnLoupe(address instance_, IFacet facet_, address expectedFacet_) internal view {
        bytes4[] memory funcs_ = facet_.facetFuncs();
        for (uint256 i; i < funcs_.length; ++i) {
            address loupeFacet_ = IDiamondLoupe(instance_).facetAddress(funcs_[i]);
            assertEq(loupeFacet_, expectedFacet_, "loupe maps selector to CREATE3 facet");
            assertTrue(loupeFacet_ != instance_ && loupeFacet_ != address(0), "facet cut non-zero non-self");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*  J1: Target/product selectors ⊆ Facet.facetFuncs()                     */
    /* ---------------------------------------------------------------------- */

    /// @notice J1: exchangeIn Target + Info + compound ⊆ exchangeInFacet.facetFuncs().
    function test_J1_exchangeIn_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = exchangeInFacet.facetFuncs();
        assertTrue(funcs_.length >= 13, "exchangeIn facetFuncs length");

        assertTrue(_contains(funcs_, IStandardExchangeIn.previewExchangeIn.selector), "previewExchangeIn");
        assertTrue(_contains(funcs_, IStandardExchangeIn.exchangeIn.selector), "exchangeIn");
        assertTrue(_contains(funcs_, IComposedStableCommonDetfInfo.mintThreshold.selector), "mintThreshold");
        assertTrue(_contains(funcs_, IComposedStableCommonDetfInfo.burnThreshold.selector), "burnThreshold");
        assertTrue(_contains(funcs_, IComposedStableCommonDetfInfo.thresholdMode.selector), "thresholdMode");
        assertTrue(_contains(funcs_, IComposedStableCommonDetfInfo.isMintingAllowed.selector), "isMintingAllowed");
        assertTrue(_contains(funcs_, IComposedStableCommonDetfInfo.isBurningAllowed.selector), "isBurningAllowed");
        assertTrue(
            _contains(funcs_, IComposedStableCommonDetfInfo.lastExpansionTimestamp.selector), "lastExpansionTimestamp"
        );
        assertTrue(
            _contains(funcs_, IComposedStableCommonDetfInfo.expansionClosureRatePerSecond.selector),
            "expansionClosureRatePerSecond"
        );
        assertTrue(
            _contains(funcs_, IComposedStableCommonDetfInfo.expansionCatchUpMaxSeconds.selector),
            "expansionCatchUpMaxSeconds"
        );
        assertTrue(
            _contains(funcs_, IComposedStableCommonDetfInfo.expansionCatchUpCapBps.selector), "expansionCatchUpCapBps"
        );
        assertTrue(
            _contains(funcs_, IComposedStableCommonDetfInfo.compoundProtocolRewards.selector), "compoundProtocolRewards"
        );
        assertTrue(
            _contains(funcs_, bytes4(keccak256("compoundProtocolRewardsAtomic()"))), "compoundProtocolRewardsAtomic"
        );
    }

    /// @notice J1: bonding Target ⊆ bondingFacet.facetFuncs().
    function test_J1_bonding_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = bondingFacet.facetFuncs();
        assertTrue(funcs_.length >= 4, "bonding facetFuncs length");
        assertTrue(_contains(funcs_, IComposedStableCommonDetfBonding.acceptedBondTokens.selector), "accepted");
        assertTrue(_contains(funcs_, IComposedStableCommonDetfBonding.isAcceptedBondToken.selector), "isAccepted");
        assertTrue(_contains(funcs_, IComposedStableCommonDetfBonding.bond.selector), "bond");
        assertTrue(_contains(funcs_, IComposedStableCommonDetfBonding.sellNFT.selector), "sellNFT");
    }

    /// @notice J1: exchangeOut / claim Target ⊆ exchangeOutQueryFacet.facetFuncs().
    function test_J1_exchangeOut_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = exchangeOutQueryFacet.facetFuncs();
        assertTrue(funcs_.length >= 4, "exchangeOut facetFuncs length");
        assertTrue(_contains(funcs_, IStandardExchangeOut.previewExchangeOut.selector), "previewExchangeOut");
        assertTrue(_contains(funcs_, IStandardExchangeOut.exchangeOut.selector), "exchangeOut");
        assertTrue(_contains(funcs_, IDetf.previewClaimLiquidity.selector), "previewClaimLiquidity");
        assertTrue(_contains(funcs_, IDetf.claimLiquidity.selector), "claimLiquidity");
    }

    /// @notice J1: pricing IDETF Target ⊆ pricingFacet.facetFuncs().
    function test_J1_pricing_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = pricingFacet.facetFuncs();
        assertTrue(funcs_.length >= 10, "pricing facetFuncs length");
        assertTrue(_contains(funcs_, IDETF.bondNftVault.selector), "bondNftVault");
        assertTrue(_contains(funcs_, IDETF.detfNFTId.selector), "detfNFTId");
        assertTrue(_contains(funcs_, IDETF.rebasingDetfToken.selector), "rebasingDetfToken");
        assertTrue(_contains(funcs_, IDETF.reservePool.selector), "reservePool");
        assertTrue(_contains(funcs_, IDETF.previewRebasingDetfTokenReserveBpt.selector), "previewReserveBpt");
        assertTrue(_contains(funcs_, IDETF.previewRebasingDetfTokenEthValue.selector), "previewEthValue");
        assertTrue(_contains(funcs_, IDETF.previewStablePoolBptEthValue.selector), "previewStable");
        assertTrue(_contains(funcs_, IDETF.previewCommonPoolBptEthValue.selector), "previewCommon");
        assertTrue(_contains(funcs_, IDETF.syntheticDetfEthPrice.selector), "syntheticPrice");
        assertTrue(_contains(funcs_, IDETF.previewReservePoolDecomposition.selector), "decomposition");
    }

    /* ---------------------------------------------------------------------- */
    /*  J2: facetFuncs ⊆ loupe on production proxy                            */
    /* ---------------------------------------------------------------------- */

    /// @notice J2: every product facetFuncs selector is registered on the production proxy loupe.
    function test_J2_facetFuncs_subseteq_loupe_onProxy() public view {
        address instance_ = deployedDetfVault;
        _assertFacetFuncsOnLoupe(instance_, exchangeInFacet, address(exchangeInFacet));
        _assertFacetFuncsOnLoupe(instance_, bondingFacet, address(bondingFacet));
        _assertFacetFuncsOnLoupe(instance_, exchangeOutQueryFacet, address(exchangeOutQueryFacet));
        _assertFacetFuncsOnLoupe(instance_, pricingFacet, address(pricingFacet));
    }

    /* ---------------------------------------------------------------------- */
    /*  J3: money path + view smoke on proxy (not facet impl)                 */
    /* ---------------------------------------------------------------------- */

    /// @notice J3: proxy smoke — loupe-routed selectors execute on the production diamond.
    function test_J3_proxySmoke_moneyAndViews() public {
        _bootstrapReserveGraph();
        address instance_ = deployedDetfVault;

        // Prove cut is proxy-routed, not self / zero.
        address exchangeFacetAddr_ =
            IDiamondLoupe(instance_).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertEq(exchangeFacetAddr_, address(exchangeInFacet), "exchangeIn loupe facet");
        assertTrue(exchangeFacetAddr_ != instance_ && exchangeFacetAddr_ != address(0), "proxy cut");

        IComposedStableCommonDetfInfo info_ = IComposedStableCommonDetfInfo(instance_);
        IDETF pricing_ = IDETF(instance_);
        IComposedStableCommonDetfBonding bonding_ = IComposedStableCommonDetfBonding(instance_);
        IStandardExchangeIn exIn_ = IStandardExchangeIn(instance_);
        IStandardExchangeOut exOut_ = IStandardExchangeOut(instance_);

        // --- Views via proxy ---
        info_.mintThreshold();
        info_.burnThreshold();
        info_.thresholdMode();
        info_.isMintingAllowed();
        info_.isBurningAllowed();
        info_.lastExpansionTimestamp();
        info_.expansionClosureRatePerSecond();
        info_.expansionCatchUpMaxSeconds();
        info_.expansionCatchUpCapBps();

        assertTrue(pricing_.bondNftVault() != address(0), "proxy bondNftVault");
        assertTrue(pricing_.rebasingDetfToken() != address(0), "proxy rebasing");
        assertTrue(pricing_.reservePool() != address(0), "proxy reservePool");
        pricing_.detfNFTId();
        pricing_.syntheticDetfEthPrice();
        pricing_.previewRebasingDetfTokenReserveBpt(0);
        pricing_.previewReservePoolDecomposition(0);

        address[] memory accepted_ = bonding_.acceptedBondTokens();
        assertTrue(accepted_.length >= 1, "proxy acceptedBondTokens");
        assertTrue(bonding_.isAcceptedBondToken(dai), "proxy isAcceptedBondToken");

        // Previews via proxy (no state)
        assertEq(exIn_.previewExchangeIn(dai, 0, detfToken), 0, "zero mint preview");
        assertEq(exOut_.previewExchangeOut(detfToken, dai, 0), 0, "zero burn preview");

        // Money path: ZeroAmount proves selector is live on proxy (exact product error).
        vm.prank(attacker);
        vm.expectRevert(IDetfErrors.ZeroAmount.selector);
        exIn_.exchangeIn(dai, 0, detfToken, 0, attacker, false, block.timestamp + 1);

        vm.prank(attacker);
        vm.expectRevert(IDetfErrors.ZeroAmount.selector);
        bonding_.bond(dai, 0, 30 days, attacker, block.timestamp + 1);

        // Live money smoke: mint on diamond proxy (not facet impl).
        uint256 amountIn_ = 500e18;
        deal(address(dai), bob, amountIn_, true);
        uint256 preview_ = exIn_.previewExchangeIn(dai, amountIn_, detfToken);
        vm.startPrank(bob);
        dai.approve(instance_, amountIn_);
        uint256 out_ = exIn_.exchangeIn(dai, amountIn_, detfToken, 0, bob, false, block.timestamp + 1);
        vm.stopPrank();
        assertTrue(out_ > 0, "proxy mint ok");
        assertGe(out_, preview_, "proxy mint meets preview");
        assertEq(detfToken.balanceOf(bob), out_, "proxy mint balance");

        // compound: permissionless best-effort; must not be "function does not exist".
        info_.compoundProtocolRewards();

        // Explicit anti-theater: primary SUT is proxy, not facet implementation address.
        assertTrue(exchangeFacetAddr_ != instance_, "J3 primary target is proxy");
    }

    /// @notice J facet metadata parity (CREATE3-deployed facets).
    function test_J_facetMetadata_matches_CREATE3_facets() public view {
        _assertMetadataParity(exchangeInFacet, "ComposedStableCommonDetfExchangeIn");
        _assertMetadataParity(bondingFacet, "ComposedStableCommonDetfBondingFacet");
        _assertMetadataParity(exchangeOutQueryFacet, "ComposedStableCommonDetfExchangeOutQueryFacet");
        _assertMetadataParity(pricingFacet, "RebasingDETFTokenPricingFacet");
    }

    function _assertMetadataParity(IFacet facet_, string memory expectedName_) internal view {
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes(expectedName_)), "facet name");
        assertTrue(ifaces_.length >= 1, "interfaces");
        assertEq(facet_.facetFuncs().length, funcs_.length, "funcs match metadata");
        assertEq(
            keccak256(abi.encodePacked(funcs_)),
            keccak256(abi.encodePacked(facet_.facetFuncs())),
            "metadata funcs == facetFuncs"
        );
    }
}
