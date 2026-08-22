// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @notice D25 close on Multi-vault weighted.
contract MultiVaultWeightedDetf_Alignment_CloseD25 is TestBase_MultiVaultWeightedDetf {
    function setUp() public override {
        super.setUp();
        detf = _deployOpenModeDetf("D25 MVW", "d25mvw");
        detfInfo = IMultiVaultWeightedDetfInfo(detf);
        detfBonding = IMultiVaultWeightedDetfBonding(detf);
    }

    /// @dev Second vault-share bond after `_goLiveViaBptBond` (MVW has no `_bootstrapDetf`).
    function _bondBobAfterLive(uint256 lpAmount) internal returns (uint256 tokenId_) {
        uint256 seShares_ = _fundSeShares0(bob, lpAmount);
        vm.startPrank(bob);
        seShare0.approve(detf, seShares_);
        (tokenId_,) = detfBonding.bond(
            seShare0, seShares_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_D25_1_userDetfOnlyFromClaimRewards() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 tokenId_ = _bondBobAfterLive(200e18);
        _warpPastUnlock(detf, tokenId_);
        uint256 pending_ = _bondNftVault(detf).pendingRewards(tokenId_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(bob);
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _closeMinOut(detf), bob, block.timestamp + 1 hours);
        assertApproxEqAbs(IERC20(detf).balanceOf(bob) - detfBefore_, pending_, 1, "D25-1");
    }

    function test_D25_2_withdrawnDetfNotBurned() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 tokenId_ = _bondBobAfterLive(200e18);
        _warpPastUnlock(detf, tokenId_);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _closeMinOut(detf), bob, block.timestamp + 1 hours);
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "D25-2");
    }

    function test_D25_3_id0OriginalSharesRise() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 tokenId_ = _bondBobAfterLive(200e18);
        _warpPastUnlock(detf, tokenId_);
        IDETFNFTVault nft_ = _bondNftVault(detf);
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _closeMinOut(detf), bob, block.timestamp + 1 hours);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-3");
    }

    function test_D25_4_userReceivesNonDetfBasket() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 tokenId_ = _bondBobAfterLive(200e18);
        _warpPastUnlock(detf, tokenId_);
        vm.prank(bob);
        uint256[] memory out_ = detfBonding.closeBondMature(tokenId_, _closeMinOut(detf), bob, block.timestamp + 1 hours);
        uint256 sum_;
        for (uint256 i; i < out_.length; ++i) sum_ += out_[i];
        assertGt(sum_, 0, "D25-4 basket");
    }

    function test_D25_5_ids1and2CannotClose() public {
        _bootstrapViaFirstBond(alice, 800e18);
        uint256[] memory minOut_ = _closeMinOut(detf);
        vm.expectRevert();
        detfBonding.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, minOut_, alice, block.timestamp + 1 hours);
        vm.expectRevert();
        detfBonding.closeBondMature(DETF_CREATOR_BOND_NFT_ID, minOut_, alice, block.timestamp + 1 hours);
    }

    function test_D25_6_previewEqualsExecute() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 tokenId_ = _bondBobAfterLive(200e18);
        _warpPastUnlock(detf, tokenId_);
        uint256[] memory preview_ = detfBonding.previewCloseBondMature(tokenId_);
        vm.prank(bob);
        uint256[] memory out_ = detfBonding.closeBondMature(tokenId_, _closeMinOut(detf), bob, block.timestamp + 1 hours);
        assertEq(out_.length, preview_.length);
        for (uint256 i; i < out_.length; ++i) {
            assertApproxEqAbs(out_[i], preview_[i], 1);
        }
    }

    function test_D25_lastClose_feeCreatorPendingDoesNotJump() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 tokenId_ = _bondBobAfterLive(200e18);
        _warpPastUnlock(detf, tokenId_);
        IDETFNFTVault nft_ = _bondNftVault(detf);
        uint256 feePending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorPending_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _closeMinOut(detf), bob, block.timestamp + 1 hours);
        assertLe(nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID), feePending_ + 1, "feeTo pending");
        assertLe(nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID), creatorPending_ + 1, "creator pending");
    }
}