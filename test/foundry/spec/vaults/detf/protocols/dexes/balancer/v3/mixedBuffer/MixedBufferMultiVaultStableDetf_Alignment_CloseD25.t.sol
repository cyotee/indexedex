// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";

/// @notice D25 close on Mixed-buffer: basket is not buffer-only.
contract MixedBufferMultiVaultStableDetf_Alignment_CloseD25 is TestBase_MixedBufferMultiVaultStableDetf {
    uint256 internal aliceBondId;

    function setUp() public override {
        super.setUp();
        detf = _deployOpenModeDetfN(1);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        (aliceBondId,,) = _bootstrapDefault(detf, alice);
    }

    function _minOut() internal view returns (uint256[] memory m) {
        m = new uint256[](_reserveTokenCount(detf));
    }

    function _bondBob() internal returns (uint256 tokenId_) {
        _fundBuffer(bob, 100e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(detf, 100e18);
        (tokenId_,) = detfBonding.bond(
            IERC20(address(dai)), 100e18, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
    }

    function test_D25_1_userDetfOnlyFromClaimRewards() public {
        uint256 tokenId_ = _bondBob();
        uint256 pending_ = _bondNftVault(detf).pendingRewards(tokenId_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(bob);
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        assertApproxEqAbs(IERC20(detf).balanceOf(bob) - detfBefore_, pending_, 1, "D25-1");
    }

    function test_D25_2_withdrawnDetfNotBurned() public {
        uint256 tokenId_ = _bondBob();
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "D25-2");
    }

    function test_D25_3_id0OriginalSharesRise() public {
        uint256 tokenId_ = _bondBob();
        IDETFNFTVault nft_ = _bondNftVault(detf);
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-3");
    }

    function test_D25_4_userReceivesNonDetfBasket() public {
        uint256 tokenId_ = _bondBob();
        uint256 daiBefore_ = dai.balanceOf(bob);
        uint256 shareBefore_ = seShares[0].balanceOf(bob);
        vm.prank(bob);
        uint256[] memory out_ = detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        uint256 sum_;
        for (uint256 i; i < out_.length; ++i) sum_ += out_[i];
        assertGt(sum_, 0, "basket");
        assertTrue(
            dai.balanceOf(bob) > daiBefore_ || seShares[0].balanceOf(bob) > shareBefore_,
            "D25-4 not buffer-only required if both legs paid"
        );
    }

    function test_D25_5_ids1and2CannotClose() public {
        uint256[] memory minOut_ = _minOut();
        vm.expectRevert();
        detfBonding.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, minOut_, alice, block.timestamp + 1 hours);
        vm.expectRevert();
        detfBonding.closeBondMature(DETF_CREATOR_BOND_NFT_ID, minOut_, alice, block.timestamp + 1 hours);
    }

    function test_D25_6_previewEqualsExecute() public {
        uint256 tokenId_ = _bondBob();
        uint256[] memory preview_ = detfBonding.previewCloseBondMature(tokenId_);
        vm.prank(bob);
        uint256[] memory out_ = detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        assertEq(out_.length, preview_.length);
        for (uint256 i; i < out_.length; ++i) {
            assertApproxEqAbs(out_[i], preview_[i], 1);
        }
    }

    function test_D25_lastClose_feeCreatorPendingDoesNotJump() public {
        _warpPastUnlock(detf, aliceBondId);
        IDETFNFTVault nft_ = _bondNftVault(detf);
        uint256 feePending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorPending_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        vm.prank(alice);
        detfBonding.closeBondMature(aliceBondId, _minOut(), alice, block.timestamp + 1 hours);
        assertLe(nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID), feePending_ + 1, "feeTo pending");
        assertLe(nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID), creatorPending_ + 1, "creator pending");
    }
}