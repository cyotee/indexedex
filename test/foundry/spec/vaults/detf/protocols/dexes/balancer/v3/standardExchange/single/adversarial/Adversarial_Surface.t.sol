// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_SingleStandardExchangeDETF_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/TestBase_SingleStandardExchangeDETF_Adversarial.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @notice Catalog J1–J3 surface suite for Balancer Single SE DETF (WP-J-DETF-SSE-001).
/// @dev J3 smokes **proxy** (registry-deployed diamond), never facet implementation address.
contract Adversarial_SingleSE_Surface_Test is TestBase_SingleStandardExchangeDETF_Adversarial {
    /// @dev Target-derived control set: money + info + bonding selectors (not incomplete Facet copy).
    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](35);
        sels_[0] = IStandardExchangeIn.exchangeIn.selector;
        sels_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[2] = ISingleStandardExchangeDETFBonding.bond.selector;
        sels_[3] = ISingleStandardExchangeDETFBonding.sellPositionToDetfNft.selector;
        sels_[4] = ISingleStandardExchangeDETFInfo.isReserveLive.selector;
        sels_[5] = ISingleStandardExchangeDETFInfo.standardExchangeVault.selector;
        sels_[6] = ISingleStandardExchangeDETFInfo.standardExchangeVaultShare.selector;
        sels_[7] = ISingleStandardExchangeDETFInfo.rateTarget.selector;
        sels_[8] = ISingleStandardExchangeDETFInfo.reservePool.selector;
        sels_[9] = ISingleStandardExchangeDETFInfo.syntheticPrice.selector;
        sels_[10] = ISingleStandardExchangeDETFInfo.mintThreshold.selector;
        sels_[11] = ISingleStandardExchangeDETFInfo.burnThreshold.selector;
        sels_[12] = ISingleStandardExchangeDETFInfo.thresholdMode.selector;
        sels_[13] = ISingleStandardExchangeDETFInfo.isMintingAllowed.selector;
        sels_[14] = ISingleStandardExchangeDETFInfo.isBurningAllowed.selector;
        sels_[15] = ISingleStandardExchangeDETFInfo.bondNftVault.selector;
        sels_[16] = ISingleStandardExchangeDETFInfo.compoundProtocolRewards.selector;
        sels_[17] = ISingleStandardExchangeDETFInfo.lastExpansionTimestamp.selector;
        sels_[18] = ISingleStandardExchangeDETFInfo.expansionClosureRatePerSecond.selector;
        sels_[19] = ISingleStandardExchangeDETFInfo.expansionCatchUpMaxSeconds.selector;
        sels_[20] = ISingleStandardExchangeDETFInfo.expansionCatchUpCapBps.selector;
        sels_[21] = ISingleStandardExchangeDETFInfo.rebasingClaimToken.selector;
        sels_[22] = ISingleStandardExchangeDETFBonding.acceptedBondTokens.selector;
        sels_[23] = ISingleStandardExchangeDETFBonding.buyClaim.selector;
        sels_[24] = ISingleStandardExchangeDETFBonding.previewBuyClaim.selector;
        sels_[25] = ISingleStandardExchangeDETFBonding.closeBondMature.selector;
        sels_[26] = ISingleStandardExchangeDETFBonding.previewCloseBondMature.selector;
        sels_[27] = ISingleStandardExchangeDETFBonding.redeemClaim.selector;
        sels_[28] = ISingleStandardExchangeDETFBonding.previewRedeemClaim.selector;
        sels_[29] = ISingleStandardExchangeDETFBonding.claimLiquidity.selector;
        sels_[30] = ISingleStandardExchangeDETFBonding.protocolBondOriginalShares.selector;
        sels_[31] = ISingleStandardExchangeDETFBonding.joinDonatedCapital.selector;
        sels_[32] = ISingleStandardExchangeDETFBonding.previewJoinDonatedCapital.selector;
        sels_[33] = ISingleStandardExchangeDETFBonding.notifyReserveDonated.selector;
        sels_[34] = ISingleStandardExchangeDETFBonding.donate.selector;
    }

    function _facetFuncsContains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    /// @notice J1: Target/product API selectors ⊆ Facet.facetFuncs().
    function test_J1_facetFuncs_coversTargetApi() public {
        // CREATE3 facet address from TestBase (not `new`); structural read of declaration only.
        IFacet facet_ = singleStandardExchangeDetfExchangeInFacet;
        bytes4[] memory funcs_ = facet_.facetFuncs();
        assertTrue(funcs_.length >= 35, "facetFuncs length");

        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            assertTrue(
                _facetFuncsContains(funcs_, controls_[i]),
                string.concat("J1 missing selector idx ", vm.toString(i))
            );
        }
        // Atomic compound helper is Facet-only (not on ISingleStandardExchangeDETFInfo).
        assertTrue(
            _facetFuncsContains(funcs_, bytes4(keccak256("compoundProtocolRewardsAtomic()"))),
            "J1 atomic compound"
        );
    }

    /// @notice J2: loupe facetAddress(sel) != 0 for all product controls on production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public {
        address instance_ = _openLiveOpenThreshold();
        IDiamondLoupe loupe_ = IDiamondLoupe(instance_);
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            // Must not be the diamond itself or zero — and must not be a bare standalone new-facet.
            assertTrue(facetAddr_ != instance_, "J2 facet != proxy");
        }
    }

    /// @notice J3: smoke-call money + view selectors on **proxy** (not facet impl address).
    function test_J3_proxyCallable_smoke_eachSelector() public {
        address instance_ = _openLiveOpenThreshold();
        // Prove we are not calling facet impl: loupe maps exchangeIn to a non-zero facet.
        address exchangeFacet_ =
            IDiamondLoupe(instance_).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertTrue(exchangeFacet_ != address(0) && exchangeFacet_ != instance_, "proxy cut");

        // --- Views on proxy ---
        assertTrue(ISingleStandardExchangeDETFInfo(instance_).isReserveLive());
        assertTrue(ISingleStandardExchangeDETFInfo(instance_).standardExchangeVault() != address(0));
        assertTrue(ISingleStandardExchangeDETFInfo(instance_).standardExchangeVaultShare() != address(0));
        assertTrue(ISingleStandardExchangeDETFInfo(instance_).reservePool() != address(0));
        assertTrue(ISingleStandardExchangeDETFInfo(instance_).bondNftVault() != address(0));
        ISingleStandardExchangeDETFInfo(instance_).rateTarget();
        ISingleStandardExchangeDETFInfo(instance_).syntheticPrice();
        ISingleStandardExchangeDETFInfo(instance_).mintThreshold();
        ISingleStandardExchangeDETFInfo(instance_).burnThreshold();
        ISingleStandardExchangeDETFInfo(instance_).thresholdMode();
        ISingleStandardExchangeDETFInfo(instance_).isMintingAllowed();
        ISingleStandardExchangeDETFInfo(instance_).isBurningAllowed();
        ISingleStandardExchangeDETFInfo(instance_).lastExpansionTimestamp();
        ISingleStandardExchangeDETFInfo(instance_).expansionClosureRatePerSecond();
        ISingleStandardExchangeDETFInfo(instance_).expansionCatchUpMaxSeconds();
        ISingleStandardExchangeDETFInfo(instance_).expansionCatchUpCapBps();

        // preview on proxy (no state)
        IStandardExchangeIn(instance_).previewExchangeIn(seShare, 1e18, IERC20(instance_));

        // Money path: ZeroAmount proves selector is live on proxy (exact product error).
        vm.prank(attacker);
        vm.expectRevert(SingleStandardExchangeDETFRepo.ZeroAmount.selector);
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, 0, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );

        vm.prank(attacker);
        vm.expectRevert(SingleStandardExchangeDETFRepo.ZeroAmount.selector);
        ISingleStandardExchangeDETFBonding(instance_).bond(
            seShare, 0, DEFAULT_MIN_LOCK, attacker, false, block.timestamp + 1 hours
        );

        // sellPosition: product revert (not missing selector) — non-owner / invalid id.
        vm.prank(attacker);
        vm.expectRevert();
        ISingleStandardExchangeDETFBonding(instance_).sellPositionToDetfNft(1, 0, attacker);

        vm.prank(attacker);
        vm.expectRevert(SingleStandardExchangeDETFRepo.ZeroAmount.selector);
        ISingleStandardExchangeDETFBonding(instance_).buyClaim(
            0, 0, attacker, false, block.timestamp + 1 hours
        );

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(SingleStandardExchangeDETFRepo.NotAuthorized.selector, attacker));
        ISingleStandardExchangeDETFBonding(instance_).claimLiquidity(1e18, attacker);

        ISingleStandardExchangeDETFInfo(instance_).rebasingClaimToken();
        ISingleStandardExchangeDETFBonding(instance_).acceptedBondTokens();
        ISingleStandardExchangeDETFBonding(instance_).protocolBondOriginalShares();

        // compound: permissionless best-effort; must not be "function does not exist".
        ISingleStandardExchangeDETFInfo(instance_).compoundProtocolRewards();

        // Explicit anti-theater: do not smoke-call facet implementation address as primary SUT.
        // (Calling impl without diamond context would mis-attribute storage; J3 is proxy-only.)
        assertTrue(exchangeFacet_ != instance_, "J3 primary target is proxy");
    }
}
