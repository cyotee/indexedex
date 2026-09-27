// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {HostileReentrantShare} from "contracts/test/adversarial/HostileReentrantShare.sol";
import {DetfExactOutCreditAssertions} from "contracts/test/bases/DetfExactOutCreditAssertions.sol";

interface IDetfLifecycle {
    function donate(IERC20, uint256, bool) external;
    function synchronizeRewards() external returns (uint256);
    function rawSY() external view returns (address);
    function sweepDust() external;
    function reservePool() external view returns (address);
    function bondNftVault() external view returns (address);
    function rebasingClaimToken() external view returns (address);
    function reserveOfToken(address) external view returns (uint256);
}

/// @dev All calls exercise a deployed production DETF and its real reserve. Only the payment token is hostile.
abstract contract DetfStatefulActions is DetfExactOutCreditAssertions {
    struct StatefulCounts {
        uint256 attempted;
        uint256 succeeded;
        uint256 expectedRevert;
        uint256 unexpectedRevert;
    }
    mapping(bytes32 => StatefulCounts) public statefulCounts;
    AtomicPretransferCaller internal immutable prepaidCaller = new AtomicPretransferCaller();

    function _lifecycleSweepsOnMint() internal pure virtual returns (bool) {
        return false;
    }

    function _lifecycleHasCallback() internal pure virtual returns (bool) {
        return true;
    }

    function _lifecycleHasSweep() internal pure virtual returns (bool) {
        return true;
    }
    function _lifecycleFund(address, uint256) internal virtual;
    function _lifecycleTrade(address, uint256) internal virtual;
    function _lifecycleInput() internal view virtual returns (IERC20);
    function _lifecycleDetf() internal view virtual returns (address);

    function _lifecycleLiabilities() internal view returns (bytes32) {
        IDetfLifecycle info_ = IDetfLifecycle(_lifecycleDetf());
        IStakedDETF staking_ = IStakedDETF(info_.rebasingClaimToken());
        return keccak256(
            abi.encode(
                staking_.stakingState(),
                IERC20(info_.reservePool()).balanceOf(info_.bondNftVault()),
                IERC20(address(info_)).balanceOf(address(staking_)),
                IERC20(address(staking_)).balanceOf(info_.bondNftVault())
            )
        );
    }

    function _statefulActions(address actor_, address receiver_, uint256 raw_, bool exactOut_, uint256 cycles_)
        internal
    {
        // The depth-64 campaign reaches each supplementary action eight times.
        // Rotating them preserves honest deposits/redemptions on every sampled step.
        uint256 slot_ = (cycles_ - 1) % 8;
        if (slot_ == 0) {
            _prepaidMint(actor_);
        } else if (slot_ == 1) {
            _donation(actor_);
        } else if (slot_ == 2) {
            _shareTransfer(actor_, receiver_, raw_ / 32);
        } else if (slot_ == 3) {
            ++statefulCounts["market"].attempted;
            _lifecycleTrade(actor_, raw_ / 32);
            ++statefulCounts["market"].succeeded;
        } else if (slot_ == 4) {
            _maintenance();
        } else if (slot_ == 5) {
            if (_lifecycleHasCallback()) {
                _fundedReentry(actor_);
            } else {
                ++statefulCounts["market"].attempted;
                _lifecycleTrade(actor_, raw_ / 64);
                ++statefulCounts["market"].succeeded;
            }
        } else if (slot_ == 6) {
            _crossInterface(actor_, raw_ / 64);
        } else if (exactOut_) {
            ++statefulCounts["exactOut"].attempted;
            address detf_ = _lifecycleDetf();
            _assertDirectExactOutCredits(detf_, IStakedDETF(IDetfLifecycle(detf_).rebasingClaimToken()), actor_);
            ++statefulCounts["exactOut"].succeeded;
        } else if (_lifecycleHasSweep()) {
            ++statefulCounts["sweep"].attempted;
            IERC20 rawToken_ = IERC20(_lifecycleDetf());
            uint256 before_ = rawToken_.balanceOf(actor_);
            IDetfLifecycle(_lifecycleDetf()).sweepDust();
            assertEq(rawToken_.balanceOf(actor_), before_, "sweep creates no caller shares");
            ++statefulCounts["sweep"].succeeded;
        } else {
            _donation(actor_);
        }
    }

    struct PrepaidSnapshot {
        uint256 payer;
        uint256 output;
        uint256 held;
        uint256 caller;
        uint256 quote;
    }

    function _prepaidMint(address actor_) private {
        ++statefulCounts["prepaid"].attempted;
        IERC20 input_ = _lifecycleInput();
        address detf_ = _lifecycleDetf();
        uint256 amount_ = 1e15;
        uint256 excess_ = 13;
        _lifecycleFund(actor_, amount_ + excess_);
        PrepaidSnapshot memory before_ = PrepaidSnapshot(
            input_.balanceOf(actor_),
            IERC20(detf_).balanceOf(actor_),
            input_.balanceOf(detf_),
            input_.balanceOf(address(prepaidCaller)),
            IStandardExchangeIn(detf_).previewExchangeIn(input_, amount_, IERC20(detf_))
        );
        vm.prank(actor_);
        input_.approve(address(prepaidCaller), amount_ + excess_);
        uint256 minted_ = _atomicPrepaidMint(input_, actor_, amount_, excess_, before_.quote);
        assertGt(minted_, 0);
        assertEq(minted_, before_.quote);
        assertEq(input_.balanceOf(actor_), before_.payer - amount_ - excess_);
        assertEq(IERC20(detf_).balanceOf(actor_), before_.output + minted_);
        assertEq(input_.balanceOf(address(prepaidCaller)), before_.caller, "exact-in refunds nothing");
        // UniV4 joins or parks residual capital in its real reserve during mint.
        // Other families retain this excess locally and must account for it exactly.
        if (!_lifecycleSweepsOnMint()) assertGe(input_.balanceOf(detf_), before_.held + excess_, "surplus retained");
        assertEq(IDetfLifecycle(detf_).reserveOfToken(address(input_)), input_.balanceOf(detf_), "surplus booked");
        ++statefulCounts["prepaid"].succeeded;
        ++statefulCounts["replay"].attempted;
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1, 0));
        prepaidCaller.execute(
            detf_,
            abi.encodeCall(IStandardExchangeIn.exchangeIn, (input_, 1, IERC20(detf_), 0, actor_, true, block.timestamp))
        );
        assertEq(IERC20(detf_).balanceOf(actor_), before_.output + minted_);
        ++statefulCounts["replay"].expectedRevert;
    }

    function _atomicPrepaidMint(IERC20 input_, address actor_, uint256 amount_, uint256 excess_, uint256 minimum_)
        private
        returns (uint256)
    {
        address detf_ = _lifecycleDetf();
        bytes memory call_ = abi.encodeCall(
            IStandardExchangeIn.exchangeIn, (input_, amount_, IERC20(detf_), minimum_, actor_, true, block.timestamp)
        );
        return abi.decode(prepaidCaller.consumePretransfer(input_, actor_, detf_, amount_ + excess_, call_), (uint256));
    }

    function _donation(address actor_) private {
        ++statefulCounts["donate"].attempted;
        IERC20 input_ = _lifecycleInput();
        address detf_ = _lifecycleDetf();
        IDetfLifecycle info_ = IDetfLifecycle(detf_);
        IERC20 lp_ = IERC20(info_.reservePool());
        address nft_ = info_.bondNftVault();
        _lifecycleFund(actor_, 1e15);
        uint256 payer_ = input_.balanceOf(actor_);
        uint256 raw_ = IERC20(detf_).balanceOf(actor_);
        uint256 beforeLp_ = lp_.balanceOf(nft_);
        vm.startPrank(actor_);
        input_.approve(nft_, 1e15);
        info_.donate(input_, 1e15, false);
        vm.stopPrank();
        assertEq(input_.balanceOf(actor_), payer_ - 1e15);
        assertEq(IERC20(detf_).balanceOf(actor_), raw_);
        assertGt(lp_.balanceOf(nft_), beforeLp_, "donation funds protocol reserve custody");
        ++statefulCounts["donate"].succeeded;
    }

    function _shareTransfer(address actor_, address receiver_, uint256 amount_) private {
        ++statefulCounts["transfer"].attempted;
        IERC20 raw_ = IERC20(_lifecycleDetf());
        uint256 from_ = raw_.balanceOf(actor_);
        uint256 to_ = raw_.balanceOf(receiver_);
        uint256 supply_ = raw_.totalSupply();
        assertGt(amount_, 0);
        vm.prank(actor_);
        raw_.transfer(receiver_, amount_);
        assertEq(raw_.balanceOf(actor_), from_ - amount_);
        assertEq(raw_.balanceOf(receiver_), to_ + amount_);
        assertEq(raw_.totalSupply(), supply_);
        ++statefulCounts["transfer"].succeeded;
    }

    function _crossInterface(address actor_, uint256 amount_) private {
        ++statefulCounts["crossInterface"].attempted;
        address detf_ = _lifecycleDetf();
        IERC20 raw_ = IERC20(detf_);
        IStandardizedYield sy_ = IStandardizedYield(IDetfLifecycle(detf_).rawSY());
        uint256 beforeRaw_ = raw_.balanceOf(actor_);
        uint256 beforeSy_ = sy_.balanceOf(actor_);
        vm.startPrank(actor_);
        raw_.approve(address(sy_), amount_);
        uint256 minted_ = sy_.deposit(actor_, detf_, amount_, 1);
        vm.stopPrank();
        assertGt(minted_, 1);
        assertEq(raw_.balanceOf(actor_), beforeRaw_ - amount_);
        assertEq(sy_.balanceOf(actor_), beforeSy_ + minted_);
        beforeRaw_ = raw_.balanceOf(actor_);
        vm.prank(actor_);
        uint256 paid_ = sy_.redeem(actor_, minted_ / 2, detf_, 1, false);
        assertGt(paid_, 0);
        assertEq(raw_.balanceOf(actor_), beforeRaw_ + paid_);
        assertEq(sy_.balanceOf(actor_), beforeSy_ + minted_ - minted_ / 2);
        ++statefulCounts["crossInterface"].succeeded;
    }

    function _maintenance() private {
        ++statefulCounts["maintenance"].attempted;
        IDetfLifecycle info_ = IDetfLifecycle(_lifecycleDetf());
        uint256 lp_ = IERC20(info_.reservePool()).balanceOf(info_.bondNftVault());
        vm.warp(block.timestamp + 1 days);
        info_.synchronizeRewards();
        IStakedDETF staking_ = IStakedDETF(info_.rebasingClaimToken());
        assertEq(IERC20(address(info_)).balanceOf(address(staking_)), staking_.stakingState().accountedBacking);
        assertEq(IERC20(info_.reservePool()).balanceOf(info_.bondNftVault()), lp_, "epoch settlement does not spend LP");
        ++statefulCounts["maintenance"].succeeded;
    }

    function _fundedReentry(address actor_) private {
        ++statefulCounts["reentry"].attempted;
        HostileReentrantShare input_ = HostileReentrantShare(address(_lifecycleInput()));
        address detf_ = _lifecycleDetf();
        uint256 amount_ = 1e15;
        _lifecycleFund(address(input_), amount_ * 2);
        vm.prank(address(input_));
        input_.approve(detf_, amount_ * 2);
        bytes memory call_ = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (IERC20(address(input_)), amount_, IERC20(detf_), 1, address(input_), false, block.timestamp)
        );
        // Identical nested calldata has funding, approval and a valid route outside the lock.
        vm.prank(address(input_));
        uint256 control_ = IStandardExchangeIn(detf_)
            .exchangeIn(IERC20(address(input_)), amount_, IERC20(detf_), 1, address(input_), false, block.timestamp);
        assertGt(control_, 0);
        uint256 fundedBefore_ = input_.balanceOf(address(input_));
        input_.armForRecipient(detf_, detf_, call_);
        _lifecycleFund(actor_, amount_);
        uint256 payer_ = input_.balanceOf(actor_);
        uint256 raw_ = IERC20(detf_).balanceOf(actor_);
        vm.startPrank(actor_);
        input_.approve(detf_, amount_);
        uint256 minted_ = IStandardExchangeIn(detf_)
            .exchangeIn(IERC20(address(input_)), amount_, IERC20(detf_), 1, actor_, false, block.timestamp);
        vm.stopPrank();
        input_.disarm();
        assertGt(input_.reentryAttempts(), 0, "callback reached");
        assertFalse(input_.nestedCallSucceeded());
        assertEq(input_.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "nested money route reaches guard");
        assertEq(input_.balanceOf(address(input_)), fundedBefore_, "nested input not consumed");
        assertEq(input_.balanceOf(actor_), payer_ - amount_);
        assertEq(IERC20(detf_).balanceOf(actor_), raw_ + minted_);
        assertGt(minted_, 0);
        ++statefulCounts["reentry"].expectedRevert;
        ++statefulCounts["reentry"].succeeded;
    }

    function _slotCount(uint256 cycles_, uint256 slot_) private pure returns (uint256) {
        return cycles_ / 8 + (cycles_ % 8 > slot_ ? 1 : 0);
    }

    function _assertStatefulCounts(uint256 cycles_, bool exactOut_) internal view {
        _assertActionCount("prepaid", _slotCount(cycles_, 0), false);
        _assertActionCount("replay", _slotCount(cycles_, 0), true);
        _assertActionCount(
            "donate", _slotCount(cycles_, 1) + (!exactOut_ && !_lifecycleHasSweep() ? _slotCount(cycles_, 7) : 0), false
        );
        _assertActionCount("transfer", _slotCount(cycles_, 2), false);
        _assertActionCount("crossInterface", _slotCount(cycles_, 6), false);
        _assertActionCount(
            "market", _slotCount(cycles_, 3) + (!_lifecycleHasCallback() ? _slotCount(cycles_, 5) : 0), false
        );
        _assertActionCount("maintenance", _slotCount(cycles_, 4), false);
        if (_lifecycleHasCallback()) {
            _assertActionCount("reentry", _slotCount(cycles_, 5), false);
            assertEq(statefulCounts["reentry"].expectedRevert, _slotCount(cycles_, 5));
        }
        if (exactOut_ || _lifecycleHasSweep()) {
            _assertActionCount(exactOut_ ? bytes32("exactOut") : bytes32("sweep"), _slotCount(cycles_, 7), false);
        }
    }

    function _assertActionCount(bytes32 name_, uint256 expected_, bool rejected_) private view {
        StatefulCounts memory c_ = statefulCounts[name_];
        assertEq(c_.attempted, expected_);
        assertEq(c_.unexpectedRevert, 0);
        assertEq(rejected_ ? c_.expectedRevert : c_.succeeded, expected_);
    }
}
