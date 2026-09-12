// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {StakedDETFTarget} from "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {DETFFundedStakingArtifacts} from "contracts/test/bases/DETFFundedStakingArtifacts.sol";

/// @notice Catalog I1/I2/I3 using real paid bonds and the funded staking proxy.
/// @dev Covers both standard exact-input and exact-output routes in both directions.
contract RebasingClaimToken_TrustFlags_Test is TestBase_UniswapV4Detf, DETFFundedStakingArtifacts {
    IStakedDETF private staking_;
    uint256 private liquid_;

    function setUp() public override {
        super.setUp();
        staking_ = IStakedDETF(detfInfo.rebasingClaimToken());
        IDetfBondNFT bonds_ = IDetfBondNFT(detfInfo.bondNftVault());
        (uint256 id_,) = _firstBond(1_000 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        vm.prank(detfUser);
        (uint256 principal_, uint256 rewards_) = bonds_.claimBond(id_, detfUser);
        liquid_ = principal_ + rewards_;
    }

    function test_pretransferredNeverCreditsHeldStakingOrBacking() public {
        // Actual sDETF transferred before the call remains outside its authenticated pull window.
        uint256 held_ = liquid_ / 2;
        vm.prank(detfUser);
        staking_.transfer(address(staking_), held_);
        IStakedDETF.StakingState memory state_ = staking_.stakingState();
        uint256 backing_ = IERC20(detf).balanceOf(address(staking_));
        address attacker_ = makeAddr("unfunded staking attacker");
        uint256[3] memory claims_ = [uint256(1), held_, held_ + 1];
        for (uint256 direction_; direction_ < 2; ++direction_) {
            IERC20 in_ = direction_ == 0 ? IERC20(detf) : IERC20(address(staking_));
            IERC20 out_ = direction_ == 0 ? IERC20(address(staking_)) : IERC20(detf);
            for (uint256 i_; i_ < claims_.length; ++i_) {
                uint256 amount_ = claims_[i_];
                bytes memory error_ = abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount_, 0);
                vm.prank(attacker_);
                vm.expectRevert(error_);
                staking_.exchangeIn(in_, amount_, out_, 0, attacker_, true, block.timestamp);
                vm.prank(attacker_);
                vm.expectRevert(error_);
                staking_.exchangeOut(in_, amount_, out_, amount_, attacker_, true, block.timestamp);
            }
        }
        assertEq(staking_.balanceOf(address(staking_)), held_);
        assertEq(IERC20(detf).balanceOf(address(staking_)), backing_);
        assertEq(abi.encode(staking_.stakingState()), abi.encode(state_));
        assertEq(staking_.balanceOf(attacker_), 0);
        assertEq(IERC20(detf).balanceOf(attacker_), 0);
    }

    function test_honestPrincipalRoutesLeaveUnsolicitedBackingUnallocated() public {
        vm.startPrank(detfUser);
        staking_.exchangeIn(IERC20(address(staking_)), liquid_, IERC20(detf), liquid_, detfUser, false, block.timestamp);
        uint256 donation_ = liquid_ / 7;
        IERC20(detf).transfer(address(staking_), donation_);
        IERC20(detf).approve(address(staking_), liquid_ - donation_);
        uint256 stake_ = liquid_ - donation_;
        uint256 before_ = staking_.stakingState().accountedBacking;
        assertEq(staking_.exchangeIn(IERC20(detf), stake_, IERC20(address(staking_)), stake_, detfUser, false, block.timestamp), stake_);
        assertEq(staking_.stakingState().accountedBacking, before_ + stake_);
        staking_.exchangeOut(IERC20(address(staking_)), stake_, IERC20(detf), stake_ / 2, detfUser, false, block.timestamp);
        vm.stopPrank();
        uint256 remaining_ = staking_.balanceOf(detfUser);
        uint256 backing_ = IERC20(detf).balanceOf(address(staking_));
        address attacker_ = makeAddr("residual staking attacker");
        vm.prank(attacker_);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, donation_, 0));
        staking_.exchangeIn(IERC20(detf), donation_, IERC20(address(staking_)), 0, attacker_, true, block.timestamp);
        assertEq(staking_.balanceOf(detfUser), remaining_);
        assertEq(staking_.balanceOf(attacker_), 0);
        assertEq(IERC20(detf).balanceOf(address(staking_)), backing_);
        assertEq(backing_ - staking_.stakingState().accountedBacking, donation_);
    }

    function test_exactOutputNativeLimitsAfterFundedRebase() public {
        // A funded bond reward has already moved K below its initial value.
        assertLt(staking_.stakingState().gonsPerUnit, 1e36);
        vm.startPrank(detfUser);
        staking_.exchangeIn(IERC20(address(staking_)), liquid_ / 2, IERC20(detf), 0, detfUser, false, block.timestamp);
        IERC20(detf).approve(address(staking_), type(uint256).max);
        vm.stopPrank();
        uint256[6] memory amounts_ = [uint256(1), 2, 31, 32, 1e9, liquid_ / 100];
        for (uint256 direction_; direction_ < 2; ++direction_) {
            IERC20 in_ = direction_ == 0 ? IERC20(detf) : IERC20(address(staking_));
            IERC20 out_ = direction_ == 0 ? IERC20(address(staking_)) : IERC20(detf);
            assertEq(staking_.previewExchangeOut(in_, out_, 0), 0);
            for (uint256 i_; i_ < amounts_.length; ++i_) _checkExactOutput(in_, out_, amounts_[i_]);
        }
    }

    function _checkExactOutput(IERC20 in_, IERC20 out_, uint256 amount_) private {
        uint256 quoted_ = staking_.previewExchangeOut(in_, out_, amount_);
        assertEq(quoted_, amount_, "one native balance unit always buys one native principal unit");
        assertEq(staking_.previewExchangeIn(in_, quoted_, out_), amount_);
        assertLt(staking_.previewExchangeIn(in_, quoted_ - 1, out_), amount_);
        uint256 inputBefore_ = in_.balanceOf(detfUser);
        uint256 outputBefore_ = out_.balanceOf(detfUser);
        bytes memory stateBefore_ = abi.encode(staking_.stakingState());
        vm.startPrank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(StakedDETFTarget.MaximumInputExceeded.selector, amount_ - 1, amount_));
        staking_.exchangeOut(in_, amount_ - 1, out_, amount_, detfUser, false, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(StakedDETFTarget.MinimumOutputNotMet.selector, amount_ + 1, amount_));
        staking_.exchangeIn(in_, amount_, out_, amount_ + 1, detfUser, false, block.timestamp);
        vm.stopPrank();
        assertEq(abi.encode(staking_.stakingState()), stateBefore_);
        assertEq(in_.balanceOf(detfUser), inputBefore_);
        assertEq(out_.balanceOf(detfUser), outputBefore_);
        vm.prank(detfUser);
        uint256 used_ = staking_.exchangeOut(in_, amount_ + 13, out_, amount_, detfUser, false, block.timestamp);
        assertEq(used_, amount_, "maximum input is a limit, not the amount consumed");
        assertEq(in_.balanceOf(detfUser), inputBefore_ - amount_);
        assertEq(out_.balanceOf(detfUser), outputBefore_ + amount_);
    }
}
