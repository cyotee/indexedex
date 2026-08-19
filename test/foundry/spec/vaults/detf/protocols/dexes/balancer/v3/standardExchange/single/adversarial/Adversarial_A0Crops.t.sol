// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_SingleStandardExchangeDETF_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/TestBase_SingleStandardExchangeDETF_Adversarial.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/**
 * @title Adversarial_SingleSE_A0Crops
 * @notice A0 first-bond residual + CROPS disable-on-exit (WP-SEC-DETF-SSE-A0-001).
 */
contract Adversarial_SingleSE_A0Crops is TestBase_SingleStandardExchangeDETF_Adversarial {
    function test_A0_preLive_donatedVaultShare_cannotBeFirstMinted() public {
        address instance_ = _deployOpenModeDetf("A0 PreLive Mint", "a0plm");
        uint256 donate_ = _fundSeShares(attacker, 80e18);
        vm.prank(attacker);
        seShare.transfer(instance_, donate_);
        assertEq(seShare.balanceOf(instance_), donate_, "donation sitting");
        assertFalse(ISingleStandardExchangeDETFInfo(instance_).isReserveLive(), "inert");

        vm.startPrank(attacker);
        seShare.approve(instance_, 1e18);
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, 1e18, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertFalse(ISingleStandardExchangeDETFInfo(instance_).isReserveLive(), "still inert");
        assertEq(seShare.balanceOf(instance_), donate_, "donation unmoved");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "no free detfToken");
    }

    function test_A0_donatedInventory_firstBondDoesNotStealOthersSeed() public {
        address instance_ = _deployOpenModeDetf("A0 PreXfer Bond", "a0pxb");
        uint256 donate_ = _fundSeShares(attacker, 80e18);
        vm.prank(attacker);
        seShare.transfer(instance_, donate_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, donate_, uint256(0))
        );
        ISingleStandardExchangeDETFBonding(instance_).bond(
            seShare, donate_, DEFAULT_MIN_LOCK, attacker, true, block.timestamp + 1 hours
        );

        assertFalse(ISingleStandardExchangeDETFInfo(instance_).isReserveLive(), "still inert");
        assertEq(seShare.balanceOf(instance_), donate_, "donation unmoved");
    }

    function test_A0_preLive_pullFalse_doesNotCreditDonation() public {
        address instance_ = _deployOpenModeDetf("A0 PullFalse", "a0pf");
        uint256 donate_ = _fundSeShares(attacker, 50e18);
        vm.prank(attacker);
        seShare.transfer(instance_, donate_);

        uint256 tokenId_ = _bootstrapDetf(instance_, alice, 1_000e18);
        assertTrue(tokenId_ > 0, "honest first bond");
        assertTrue(ISingleStandardExchangeDETFInfo(instance_).isReserveLive(), "live after pull-false");
        assertGe(seShare.balanceOf(instance_), donate_, "donation leftover after pull-false go-live");
    }

    function test_A0_emptyUserSupply_donatedInventory_notDrainedByFirstMint() public {
        address instance_ = _deployOpenModeDetf("A0 First Mint", "a0fm");
        uint256 donate_ = _fundSeShares(attacker, 60e18);
        vm.prank(attacker);
        seShare.transfer(instance_, donate_);

        _bootstrapDetf(instance_, alice, 1_200e18);
        uint256 leftover_ = seShare.balanceOf(instance_);
        assertGe(leftover_, donate_, "seed booked after first bond");

        uint256 mintIn_ = _fundSeShares(attacker, 40e18);
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(seShare, mintIn_, IERC20(instance_));
        vm.startPrank(attacker);
        seShare.approve(instance_, mintIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShare, mintIn_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(out_, preview_, "first mint not inflated by donation");
        assertEq(seShare.balanceOf(instance_), leftover_, "donated vaultShare not drained");
    }

    function test_CROPS_disable_doesNotBlock_closeBondMature_or_redeemClaim() public {
        address instance_ = _deployOpenModeDetf("CROPS Close Redeem", "cropsCR");
        uint256 aliceId_ = _bootstrapDetf(instance_, alice, 1_500e18);
        uint256 bobId_ = _bootstrapDetf(instance_, bob, 300e18);
        ISingleStandardExchangeDETFBonding bonding_ = ISingleStandardExchangeDETFBonding(instance_);
        ISingleStandardExchangeDETFInfo info_ = ISingleStandardExchangeDETFInfo(instance_);

        _warpPastUnlock(instance_, aliceId_);
        vm.prank(alice);
        uint256 claimMinted_ = bonding_.sellPositionToDetfNft(aliceId_, 0, alice);
        assertGt(claimMinted_, 0, "claim minted");

        _warpPastUnlock(instance_, bobId_);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(instance_, true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(instance_));

        vm.prank(bob);
        uint256[] memory minOut_ = new uint256[](2);
        uint256[] memory closeOut_ = bonding_.closeBondMature(
            bobId_, minOut_, bob, block.timestamp + 1 hours
        );
        assertGt(closeOut_[0] + closeOut_[1], 0, "closeBondMature after disable");

        address claim_ = info_.rebasingClaimToken();
        uint256 claimBal_ = IRebasingClaimToken(claim_).balanceOf(alice);
        uint256 redeemAmt_ = claimBal_ / 2;
        if (redeemAmt_ == 0) redeemAmt_ = claimBal_;
        vm.prank(alice);
        uint256 redeemOut_ = bonding_.redeemClaim(
            redeemAmt_, IERC20(instance_), 0, alice, block.timestamp + 1 hours
        );
        assertGt(redeemOut_, 0, "redeemClaim after disable");
    }

    function test_CROPS_disable_doesNotBlock_burnExit() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 minted_ = _mintSeSharesToDetf(instance_, bob, 80e18);
        assertGt(minted_, 0, "minted detfToken");

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(instance_, true);

        uint256 burnAmt_ = minted_ / 2;
        vm.startPrank(bob);
        IERC20(instance_).approve(instance_, burnAmt_);
        uint256 burned_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnAmt_, seShare, 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(burned_, 0, "burn exit after disable");

        uint256 inbound_ = _fundSeShares(bob, 10e18);
        vm.startPrank(bob);
        seShare.approve(instance_, inbound_);
        vm.expectRevert(
            abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, instance_)
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, inbound_, IERC20(instance_), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
