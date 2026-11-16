// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

interface IExactOutCreditBook {
    function reserveOfToken(address) external view returns (uint256);
}

/// @dev Production DETF routes; the caller is an integrating contract, never a SUT replacement.
abstract contract DetfExactOutCreditAssertions is Test {
    struct CreditSnapshot {
        uint256 payer;
        uint256 recipient;
        uint256 caller;
        uint256 held;
        uint256 booked;
    }

    function _assertDirectExactOutCredits(address detf_, IStakedDETF staking_, address actor_) internal {
        AtomicPretransferCaller caller_ = new AtomicPretransferCaller();
        _assertCreditDirection(detf_, IERC20(detf_), IERC20(address(staking_)), actor_, caller_, 1000);
        _assertCreditDirection(detf_, IERC20(address(staking_)), IERC20(detf_), actor_, caller_, 400);
        assertEq(
            IERC20(detf_).balanceOf(address(staking_)),
            staking_.stakingState().accountedBacking,
            "direct refunds preserve staking backing"
        );
    }

    function _assertDirectExactOutUnstakeCredit(address detf_, IStakedDETF staking_, address actor_) internal {
        // Independently fund the reverse route through a supported pull before
        // checking its refund, so a failing stake assertion cannot mask this case.
        vm.startPrank(actor_);
        IERC20(detf_).approve(detf_, 1000);
        assertEq(
            IStandardExchangeOut(detf_)
                .exchangeOut(IERC20(detf_), 1000, IERC20(address(staking_)), 1000, actor_, false, block.timestamp),
            1000
        );
        vm.stopPrank();
        _assertCreditDirection(
            detf_, IERC20(address(staking_)), IERC20(detf_), actor_, new AtomicPretransferCaller(), 400
        );
        assertEq(IERC20(detf_).balanceOf(address(staking_)), staking_.stakingState().accountedBacking);
    }

    function _creditSnapshot(address detf_, IERC20 in_, IERC20 out_, address actor_, address caller_)
        private
        view
        returns (CreditSnapshot memory s_)
    {
        s_ = CreditSnapshot(
            in_.balanceOf(actor_),
            out_.balanceOf(actor_),
            in_.balanceOf(caller_),
            in_.balanceOf(detf_),
            IExactOutCreditBook(detf_).reserveOfToken(address(in_))
        );
    }

    function _assertCreditDirection(
        address detf_,
        IERC20 in_,
        IERC20 out_,
        address actor_,
        AtomicPretransferCaller caller_,
        uint256 wanted_
    ) private {
        // Book pre-existing input dust through a funded false-flag route first.
        vm.startPrank(actor_);
        in_.transfer(detf_, 3);
        in_.approve(detf_, type(uint256).max);
        IStandardExchangeOut(detf_).exchangeOut(in_, 9, out_, 3, actor_, false, block.timestamp);
        in_.approve(address(caller_), type(uint256).max);
        vm.stopPrank();
        CreditSnapshot memory before_ = _creditSnapshot(detf_, in_, out_, actor_, address(caller_));
        assertGe(before_.booked, 3, "protected dust was booked");
        uint256 paid_ = abi.decode(
            caller_.consumePretransfer(
                in_,
                actor_,
                detf_,
                wanted_ + 10,
                abi.encodeCall(
                    IStandardExchangeOut.exchangeOut, (in_, wanted_ + 3, out_, wanted_, actor_, true, block.timestamp)
                )
            ),
            (uint256)
        );
        assertEq(paid_, wanted_, "actual input used");
        assertEq(before_.payer - in_.balanceOf(actor_), wanted_ + 10, "payer pretransfers exact amount");
        assertEq(out_.balanceOf(actor_) - before_.recipient, wanted_, "exact output delivered");
        assertEq(in_.balanceOf(address(caller_)) - before_.caller, 3, "only bounded unused credit refunded to caller");
        assertEq(in_.balanceOf(detf_), before_.held + 7, "over-maximum excess and old dust retained");
        assertEq(IExactOutCreditBook(detf_).reserveOfToken(address(in_)), before_.held + 7, "retained excess booked");
        _assertCreditRejects(detf_, in_, out_, actor_, caller_);
        before_ = _creditSnapshot(detf_, in_, out_, actor_, address(caller_));
        vm.prank(actor_);
        paid_ = IStandardExchangeOut(detf_).exchangeOut(in_, 20, out_, 11, actor_, false, block.timestamp);
        assertEq(paid_, 11);
        assertEq(before_.payer - in_.balanceOf(actor_), 11, "false flag pulls only used input");
        assertEq(out_.balanceOf(actor_) - before_.recipient, 11);
        assertEq(in_.balanceOf(address(caller_)), before_.caller, "false flag refunds nothing");
        assertEq(in_.balanceOf(detf_), before_.held, "false flag preserves protected input");
    }

    function _assertCreditRejects(
        address detf_,
        IERC20 in_,
        IERC20 out_,
        address actor_,
        AtomicPretransferCaller caller_
    ) private {
        CreditSnapshot memory before_ = _creditSnapshot(detf_, in_, out_, actor_, address(caller_));
        bytes memory data_ =
            abi.encodeCall(IStandardExchangeOut.exchangeOut, (in_, 1, out_, 1, actor_, true, block.timestamp));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1, 0));
        caller_.execute(detf_, data_);
        vm.prank(actor_);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardExchangeOut(detf_).exchangeOut(in_, 1, out_, 1, actor_, true, block.timestamp);
        CreditSnapshot memory after_ = _creditSnapshot(detf_, in_, out_, actor_, address(caller_));
        assertEq(
            keccak256(abi.encode(after_)),
            keccak256(abi.encode(before_)),
            "rejected replay and EOA preserve all balances/books"
        );
    }
}
