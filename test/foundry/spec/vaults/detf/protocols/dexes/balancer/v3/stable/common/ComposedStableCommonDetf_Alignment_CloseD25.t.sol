// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/// @notice D25 close on Composed stable. Conversion still reads diamond reserve (N10 NatSpec defer).
contract ComposedStableCommonDetf_Alignment_CloseD25 is ComposedStableCommonDetf_IntegratedDeploy_Test {
    uint256 internal constant MIN_LOCK = 30 days;

    function _composedThresholdMode() internal pure override returns (ThresholdMode) {
        return ThresholdMode.Open;
    }

    function _composedMintThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function _composedBurnThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function _bonding() internal view returns (IComposedStableCommonDetfBonding) {
        return IComposedStableCommonDetfBonding(deployedDetfVault);
    }

    function _minOut() internal pure returns (uint256[] memory m) {
        m = new uint256[](3);
    }

    function _bondDai(address bonder_, uint256 daiIn_) internal returns (uint256 tokenId_) {
        deal(address(dai), bonder_, daiIn_, true);
        vm.startPrank(bonder_);
        dai.approve(deployedDetfVault, daiIn_);
        (tokenId_,) = _bonding().bond(dai, daiIn_, MIN_LOCK, bonder_, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _bootstrapAndBond(address bonder_, uint256 daiIn_) internal returns (uint256 tokenId_) {
        _bootstrapReserveGraph();
        address keep_ = bonder_ == alice ? bob : alice;
        _bondDai(keep_, 2_000e18);
        uint256 closeIn_ = daiIn_ > 100e18 ? 100e18 : daiIn_;
        tokenId_ = _bondDai(bonder_, closeIn_);
        vm.warp(block.timestamp + MIN_LOCK + 1);
    }

    function test_D25_1_userDetfOnlyFromClaimRewards() public {
        uint256 tokenId_ = _bootstrapAndBond(alice, 1_000e18);
        uint256 pending_ = bondNFTVault.pendingRewards(tokenId_);
        uint256 detfBefore_ = detfToken.balanceOf(alice);
        vm.prank(alice);
        _bonding().closeBondMature(tokenId_, _minOut(), alice, block.timestamp + 1 hours);
        assertLt(detfToken.balanceOf(alice) - detfBefore_, pending_ + 1e16, "D25-1 no self-leg payout");
    }

    function test_D25_2_withdrawnDetfNotBurned() public {
        uint256 tokenId_ = _bootstrapAndBond(alice, 1_000e18);
        uint256 supplyBefore_ = detfToken.totalSupply();
        vm.prank(alice);
        _bonding().closeBondMature(tokenId_, _minOut(), alice, block.timestamp + 1 hours);
        assertGe(detfToken.totalSupply(), supplyBefore_, "D25-2");
    }

    function test_D25_3_id0OriginalSharesRise() public {
        uint256 tokenId_ = _bootstrapAndBond(alice, 1_000e18);
        uint256 id0Before_ = bondNFTVault.originalSharesOf(bondNFTVault.detfNFTId());
        vm.prank(alice);
        _bonding().closeBondMature(tokenId_, _minOut(), alice, block.timestamp + 1 hours);
        assertGt(bondNFTVault.originalSharesOf(bondNFTVault.detfNFTId()), id0Before_, "D25-3");
    }

    function test_D25_4_userReceivesNonDetfBasket() public {
        uint256 tokenId_ = _bootstrapAndBond(alice, 1_000e18);
        uint256 stableBefore_ = IERC20(address(stablePool)).balanceOf(alice);
        uint256 commonBefore_ = IERC20(address(commonPool)).balanceOf(alice);
        vm.prank(alice);
        uint256[] memory out_ = _bonding().closeBondMature(tokenId_, _minOut(), alice, block.timestamp + 1 hours);
        assertEq(out_.length, 3);
        assertTrue(
            IERC20(address(stablePool)).balanceOf(alice) > stableBefore_
                || IERC20(address(commonPool)).balanceOf(alice) > commonBefore_,
            "D25-4 basket"
        );
    }

    function test_D25_5_ids1and2CannotClose() public {
        _bootstrapAndBond(alice, 500e18);
        vm.expectRevert();
        _bonding().closeBondMature(DETF_FEE_TO_BOND_NFT_ID, _minOut(), alice, block.timestamp + 1 hours);
        vm.expectRevert();
        _bonding().closeBondMature(DETF_CREATOR_BOND_NFT_ID, _minOut(), alice, block.timestamp + 1 hours);
    }

    function test_D25_6_previewEqualsExecute() public {
        uint256 tokenId_ = _bootstrapAndBond(alice, 1_000e18);
        uint256[] memory preview_ = _bonding().previewCloseBondMature(tokenId_);
        vm.prank(alice);
        uint256[] memory out_ = _bonding().closeBondMature(tokenId_, _minOut(), alice, block.timestamp + 1 hours);
        assertEq(out_.length, preview_.length);
        for (uint256 i; i < out_.length; ++i) {
            assertApproxEqAbs(out_[i], preview_[i], 1);
        }
    }

    function test_D25_lastClose_feeCreatorPendingDoesNotJump() public {
        uint256 tokenId_ = _bootstrapAndBond(alice, 1_000e18);
        uint256 feePending_ = bondNFTVault.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorPending_ = bondNFTVault.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        vm.prank(alice);
        _bonding().closeBondMature(tokenId_, _minOut(), alice, block.timestamp + 1 hours);
        assertLe(bondNFTVault.pendingRewards(DETF_FEE_TO_BOND_NFT_ID), feePending_ + 1, "feeTo pending");
        assertLe(bondNFTVault.pendingRewards(DETF_CREATOR_BOND_NFT_ID), creatorPending_ + 1, "creator pending");
    }
}