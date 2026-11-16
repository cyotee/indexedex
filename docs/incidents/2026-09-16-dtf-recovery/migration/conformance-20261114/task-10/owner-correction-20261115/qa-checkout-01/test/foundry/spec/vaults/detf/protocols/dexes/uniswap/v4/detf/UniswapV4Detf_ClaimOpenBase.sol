// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {UniswapV4Detf_ClaimBase} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ClaimBase.sol";

/// @notice Funded claim layer shared by existing family and provider fixtures.
abstract contract UniswapV4Detf_ClaimOpenBase is UniswapV4Detf_ClaimBase {
    function test_preMaturity_principalVestsLinearly() public {
        _firstBond(100 ether);
        (uint256 id_,) = _firstBond(20 ether);
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        DETFFundedStakingMath.BondPosition memory position_ = nft_.positionOf(id_);
        vm.prank(detfUser);
        assertEq(nft_.claimPrincipal(id_, detfUser), 0, "no principal vested at purchase");
        vm.warp(position_.startTimestamp + position_.vestingDuration / 2);
        uint256 before_ = IERC20(detfInfo.rebasingClaimToken()).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 paid_ = nft_.claimPrincipal(id_, detfUser);
        assertEq(paid_, position_.principal / 2, "halfway principal floors once");
        assertEq(IERC20(detfInfo.rebasingClaimToken()).balanceOf(detfUser) - before_, paid_, "principal is paid as sDETF");
        assertEq(nft_.positionOf(id_).principal, position_.principal, "fixed purchased principal retained");
        assertEq(nft_.positionOf(id_).claimedPrincipal, paid_, "principal debit recorded once");
    }

    function test_postMaturity_claimPaysFundedStaking() public {
        _firstBond(100 ether);
        (uint256 id_,) = _firstBond(20 ether);
        _assertFundedMatureClaim(detf, id_, detfUser);
    }

    function test_claimRewards_whileLocked() public {
        _setPfc(detf);
        (uint256 id_,) = _firstBond(100 ether);
        _firstBond(20 ether);
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        DETFFundedStakingMath.BondPosition memory position_ = nft_.positionOf(id_);
        assertLt(block.timestamp, position_.startTimestamp + position_.vestingDuration, "principal remains locked");
        uint256 pending_ = nft_.previewClaim(id_).rewardsDue;
        assertGt(pending_, 0, "funded rewards accrue while vesting");
        IERC20 staking_ = IERC20(detfInfo.rebasingClaimToken());
        uint256 before_ = staking_.balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 paid_ = nft_.claimRewards(id_, detfUser);
        assertEq(paid_, pending_, "reward preview equals execution");
        assertEq(staking_.balanceOf(detfUser) - before_, paid_, "reward paid as sDETF");
        assertEq(nft_.positionOf(id_).claimedPrincipal, 0, "reward claim cannot unlock principal");
        assertEq(nft_.previewClaim(id_).rewardsDue, 0, "funded reward debit applied once");
    }
}
