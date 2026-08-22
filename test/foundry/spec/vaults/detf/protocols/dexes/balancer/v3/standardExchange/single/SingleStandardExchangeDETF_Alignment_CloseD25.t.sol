// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/// @notice D25: mature close rejoins DETF to id 0 and pays the vault-share basket.
contract SingleStandardExchangeDETF_Alignment_CloseD25 is TestBase_SingleStandardExchangeDETF {
    function setUp() public override {
        super.setUp();
        detf = _deployOpenModeDetf("D25 Single SE", "d25sse");
        detfInfo = ISingleStandardExchangeDETFInfo(detf);
        detfBonding = ISingleStandardExchangeDETFBonding(detf);
    }

    function _nft() internal view returns (IDETFNFTVault) {
        return _bondNftVault(detf);
    }

    function _minOut() internal pure returns (uint256[] memory m) {
        m = new uint256[](2);
    }

    function test_D25_1_userDetfOnlyFromClaimRewards() public {
        _bootstrapViaFirstBond(alice, 1_200e18);
        uint256 tokenId_ = _bootstrapDetf(detf, bob, 200e18);
        _warpPastUnlock(detf, tokenId_);
        uint256 pending_ = _nft().pendingRewards(tokenId_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(bob);
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        assertApproxEqAbs(IERC20(detf).balanceOf(bob) - detfBefore_, pending_, 1, "D25-1");
    }

    function test_D25_2_withdrawnDetfNotBurned() public {
        _bootstrapViaFirstBond(alice, 1_200e18);
        uint256 tokenId_ = _bootstrapDetf(detf, bob, 200e18);
        _warpPastUnlock(detf, tokenId_);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "D25-2");
    }

    function test_D25_3_id0OriginalSharesRise() public {
        _bootstrapViaFirstBond(alice, 1_200e18);
        uint256 tokenId_ = _bootstrapDetf(detf, bob, 200e18);
        _warpPastUnlock(detf, tokenId_);
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-3");
    }

    function test_D25_4_userReceivesNonDetfBasket() public {
        _bootstrapViaFirstBond(alice, 1_200e18);
        uint256 tokenId_ = _bootstrapDetf(detf, bob, 200e18);
        _warpPastUnlock(detf, tokenId_);
        uint256 seBefore_ = seShare.balanceOf(bob);
        vm.prank(bob);
        uint256[] memory out_ = detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        assertTrue(seShare.balanceOf(bob) > seBefore_, "D25-4 vault share");
        assertGt(out_[0] + out_[1], 0, "basket");
    }

    function test_D25_5_ids1and2CannotClose() public {
        _bootstrapViaFirstBond(alice, 800e18);
        vm.expectRevert();
        detfBonding.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, _minOut(), alice, block.timestamp + 1 hours);
        vm.expectRevert();
        detfBonding.closeBondMature(DETF_CREATOR_BOND_NFT_ID, _minOut(), alice, block.timestamp + 1 hours);
    }

    function test_D25_6_previewEqualsExecute() public {
        _bootstrapViaFirstBond(alice, 1_200e18);
        uint256 tokenId_ = _bootstrapDetf(detf, bob, 200e18);
        _warpPastUnlock(detf, tokenId_);
        uint256[] memory preview_ = detfBonding.previewCloseBondMature(tokenId_);
        vm.prank(bob);
        uint256[] memory out_ = detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        assertEq(out_.length, preview_.length);
        assertApproxEqAbs(out_[0], preview_[0], 1);
        assertApproxEqAbs(out_[1], preview_[1], 1);
    }

    function test_D25_lastClose_feeCreatorPendingDoesNotJump() public {
        _bootstrapViaFirstBond(alice, 1_200e18);
        uint256 tokenId_ = _bootstrapDetf(detf, bob, 200e18);
        _warpPastUnlock(detf, tokenId_);
        IDETFNFTVault nft_ = _nft();
        uint256 feePending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorPending_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        vm.prank(bob);
        detfBonding.closeBondMature(tokenId_, _minOut(), bob, block.timestamp + 1 hours);
        assertLe(nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID), feePending_ + 1, "feeTo pending");
        assertLe(nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID), creatorPending_ + 1, "creator pending");
    }
}