// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IDetfReserveDonation, IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";

interface IFundedDonationState {
    function lastExpansionTimestamp() external view returns (uint256);
    function reservePool() external view returns (address);
}

/// @notice Shared assertions run against each family's actual reserve and funded custody.
abstract contract FundedReserveDonationAssertions is Test {
    struct DonationSnapshot {
        uint256 donorBalance;
        uint256 heldLp;
        uint256 supply;
        uint256 boundary;
        uint256 quote;
        bytes32 staking;
        bytes32 position;
    }
    function _assertFundedDonation(
        address detf_, IDetfBondNFT nft_, IStakedDETF staking_,
        IERC20 token_, uint256 amount_, address donor_, uint256 id_
    ) internal {
        IDetfNftReserveDonation gift_ = IDetfNftReserveDonation(address(nft_));
        IERC20 lp_ = IERC20(IFundedDonationState(detf_).reservePool());
        DonationSnapshot memory s_;
        s_.donorBalance = token_.balanceOf(donor_);
        s_.heldLp = lp_.balanceOf(address(nft_));
        s_.supply = IERC20(detf_).totalSupply();
        s_.boundary = IFundedDonationState(detf_).lastExpansionTimestamp();
        s_.staking = keccak256(abi.encode(staking_.stakingState()));
        s_.position = keccak256(abi.encode(nft_.positionOf(id_)));
        s_.quote = gift_.previewDonate(token_, amount_);
        assertGt(s_.quote, 0, "funded reserve donation must have a positive quote");
        vm.expectRevert();
        IDetfReserveDonation(detf_).joinDonatedCapital(token_, amount_, block.timestamp);
        vm.prank(donor_); token_.approve(address(nft_), amount_);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, s_.quote + 1, s_.quote));
        vm.prank(donor_); gift_.donate(token_, amount_, s_.quote + 1, false, block.timestamp);
        assertEq(token_.balanceOf(donor_), s_.donorBalance, "failed minimum returns all payment");
        assertEq(lp_.balanceOf(address(nft_)), s_.heldLp, "failed minimum returns LP state");
        vm.prank(donor_);
        assertEq(gift_.donate(token_, amount_, s_.quote, false, block.timestamp), s_.quote);
        assertEq(token_.balanceOf(donor_), s_.donorBalance - amount_);
        assertEq(lp_.balanceOf(address(nft_)), s_.heldLp + s_.quote);
        assertEq(IERC20(detf_).totalSupply(), s_.supply, "reserve gift issues no DETF");
        assertEq(IFundedDonationState(detf_).lastExpansionTimestamp(), s_.boundary, "retained donation route does not settle expansion");
        assertEq(keccak256(abi.encode(staking_.stakingState())), s_.staking, "reserve gift cannot change staking backing or rewards");
        assertEq(keccak256(abi.encode(nft_.positionOf(id_))), s_.position, "reserve gift cannot create bond principal or gons");
    }
}
