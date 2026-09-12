// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {TestBase_FundedComposedDETF} from "contracts/test/bases/TestBase_FundedComposedDETF.sol";
import {FundedBondLifecycleAssertions} from "contracts/test/bases/FundedBondLifecycleAssertions.sol";

/// @notice Production registry fixture for composed reserve and funded child routes.
abstract contract TestBase_ComposedFundedRoutes is TestBase_FundedComposedDETF, FundedBondLifecycleAssertions {
    function _bondNft() internal view returns (IDetfBondNFT) {
        return IDetfBondNFT(composedInfo.bondNftVault());
    }

    function _staked() internal view returns (IStakedDETF) {
        return IStakedDETF(composedInfo.rebasingClaimToken());
    }

    function _live() internal {
        if (!composedInfo.isReserveLive()) _bootstrapComposed(owner);
    }

    function _fundBpt(address who_, uint256 amount_) internal returns (IERC20 token_) {
        token_ = IERC20(address(composedStable));
        vm.prank(owner);
        token_.transfer(who_, amount_);
    }

    function _buyRaw(address who_, uint256 bpt_) internal returns (uint256 out_) {
        _live();
        IERC20 input_ = _fundBpt(who_, bpt_);
        uint256 quote_ = composedIn.previewExchangeIn(input_, bpt_, IERC20(composedDetf));
        assertGt(quote_, 0, "positive funded reserve quote");
        uint256 before_ = IERC20(composedDetf).balanceOf(who_);
        vm.startPrank(who_);
        input_.approve(composedDetf, bpt_);
        out_ = composedIn.exchangeIn(input_, bpt_, IERC20(composedDetf), quote_, who_, false, block.timestamp);
        vm.stopPrank();
        assertEq(out_, quote_);
        assertEq(IERC20(composedDetf).balanceOf(who_), before_ + out_);
    }

    function _buyBond(address who_, uint256 bpt_) internal returns (uint256 id_) {
        _live();
        IERC20 input_ = _fundBpt(who_, bpt_);
        (uint256 quote_,,) = composedBonding.previewBond(input_, bpt_, DEFAULT_MIN_LOCK);
        vm.startPrank(who_);
        input_.approve(composedDetf, bpt_);
        uint256 paid_;
        (id_, paid_) = composedBonding.bond(input_, bpt_, DEFAULT_MIN_LOCK, who_, block.timestamp);
        vm.stopPrank();
        assertEq(paid_, quote_);
        _assertBondPrincipalIsFunded(composedDetf, id_, who_);
    }

    function _assertExactOut(IERC20 output_, address to_) internal returns (uint256 paid_) {
        uint256 raw_ = _buyRaw(alice, 100e18);
        uint256 wanted_ = 1e15;
        uint256 quote_ = composedOut.previewExchangeOut(IERC20(composedDetf), output_, wanted_);
        assertGt(quote_, 0);
        assertLe(quote_, raw_);
        address recipient_ = to_ == address(0) ? alice : to_;
        uint256 before_ = output_.balanceOf(recipient_);
        vm.startPrank(alice);
        IERC20(composedDetf).approve(composedDetf, raw_);
        paid_ = composedOut.exchangeOut(IERC20(composedDetf), raw_, output_, wanted_, to_, false, block.timestamp);
        vm.stopPrank();
        assertLe(paid_, quote_);
        assertGt(paid_, 0);
        assertEq(output_.balanceOf(recipient_), before_ + wanted_, "exact requested output delivered");
        assertEq(IERC20(composedDetf).balanceOf(alice), raw_ - paid_, "only actual input spent");
        assertEq(IERC20(composedDetf).balanceOf(composedDetf), 0, "unused input returned");
    }
}
