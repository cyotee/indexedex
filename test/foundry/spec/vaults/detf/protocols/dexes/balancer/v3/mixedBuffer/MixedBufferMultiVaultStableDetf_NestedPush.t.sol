// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {MixedBufferMultiVaultStableDetfRepo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/// @notice Explicit T-NEST-1…8 + T-LOCAL for BAL-MB (L-DETF-TEST-EXPLICIT).
contract MixedBufferMultiVaultStableDetf_NestedPush_Test is TestBase_MixedBufferMultiVaultStableDetf {
    address internal liveDetf;
    IMixedBufferMultiVaultStableDetfInfo internal liveInfo;
    IMixedBufferMultiVaultStableDetfBonding internal liveBonding;
    IStandardExchangeIn internal liveExchangeIn;
    IBasicVault internal liveBook;
    IBasicVault internal leg0Book;

    function setUp() public virtual override {
        super.setUp();
        liveDetf = _deployDetfN(1, 0, 0);
        liveInfo = IMixedBufferMultiVaultStableDetfInfo(liveDetf);
        liveBonding = IMixedBufferMultiVaultStableDetfBonding(liveDetf);
        liveExchangeIn = IStandardExchangeIn(liveDetf);
        liveBook = IBasicVault(liveDetf);
        leg0Book = IBasicVault(liveInfo.underlyingVaults()[0]);
        _bootstrapDefault(liveDetf, alice);
    }

    function _share0() internal view returns (IERC20) {
        return IERC20(liveInfo.vaultShares()[0]);
    }

    function _leg0() internal view returns (address) {
        return liveInfo.underlyingVaults()[0];
    }

    function test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync() public virtual {
        uint256 out_ = _mintDetfFromVaultShare(liveDetf, 0, bob, 50e18);
        assertTrue(out_ > 0, "T-NEST-1");
        assertEq(_share0().allowance(liveDetf, _leg0()), 0, "no nested fund approve");
        assertEq(liveBook.reserveOfToken(address(_share0())), _share0().balanceOf(liveDetf), "R==B share");
    }

    function test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient() public virtual {
        // DETF-local shortfall (true without unbooked surplus).
        IERC20 buffer_ = IERC20(liveInfo.bufferToken());
        vm.expectRevert();
        liveExchangeIn.exchangeIn(
            buffer_, 1, IERC20(liveDetf), 0, bob, true, block.timestamp + 1 hours
        );
    }

    function test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts() public virtual {
        _mintDetfFromBuffer(liveDetf, bob, _fixtureAmount(40e18));
        IERC20 buffer_ = IERC20(liveInfo.bufferToken());
        // After route, true without new push reverts when U==0 for buffer face.
        uint256 R = liveBook.reserveOfToken(address(buffer_));
        uint256 B = buffer_.balanceOf(liveDetf);
        uint256 U = B >= R ? B - R : 0;
        vm.expectRevert();
        vm.prank(bob);
        liveExchangeIn.exchangeIn(
            buffer_, U + 1, IERC20(liveDetf), 0, bob, true, block.timestamp + 1 hours
        );
    }


    function test_T_NEST_4_noNestedApproveOnFundPath() public virtual {
        assertEq(_share0().allowance(liveDetf, _leg0()), 0, "pre");
        _mintDetfFromVaultShare(liveDetf, 0, bob, 30e18);
        assertEq(_share0().allowance(liveDetf, _leg0()), 0, "T-NEST-4");
    }

    function test_T_NEST_5_standardExactOut_stakesFundedDetf() public virtual { _directStakingExactOut(false); }

    function test_T_NEST_6_holdSetSyncAfterRoute() public virtual {
        _mintDetfFromBuffer(liveDetf, bob, _fixtureAmount(40e18));
        // End order: money route full hold-set sync → R == B for every vault token.
        address[] memory tokens = liveBook.vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            address t = tokens[i];
            assertEq(
                liveBook.reserveOfToken(t),
                IERC20(t).balanceOf(liveDetf),
                "T-NEST-6: post-route R == B hold-set"
            );
        }
        IERC20 buffer_ = IERC20(liveInfo.bufferToken());
        assertEq(liveBook.reserveOfToken(address(buffer_)), buffer_.balanceOf(liveDetf), "T-NEST-6 buffer R==B");
        assertEq(liveBook.reserveOfToken(address(_share0())), _share0().balanceOf(liveDetf), "T-NEST-6 share R==B");
    }

    function test_T_NEST_7_zeroAmount_skipsNested_outerRevertsZeroAmount() public virtual {
        IERC20 buffer_ = IERC20(liveInfo.bufferToken());
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        liveExchangeIn.exchangeIn(
            buffer_, 0, IERC20(liveDetf), 0, bob, false, block.timestamp + 1 hours
        );
    }

    function test_T_NEST_8_standardExactOut_unstakeLeavesUnusedMaximum() public virtual { _directStakingExactOut(true); }

    function _directStakingExactOut(bool unstake_) private {
        uint256 bought_ = _mintDetfFromBuffer(liveDetf, bob, _fixtureAmount(50e18));
        uint256 target_ = bought_ / 4;
        assertGt(target_, 0);
        IERC20 raw_ = IERC20(liveDetf);
        IERC20 receipt_ = IERC20(liveInfo.rebasingClaimToken());
        IStandardExchangeOut exchange_ = IStandardExchangeOut(liveDetf);
        vm.startPrank(bob);
        if (unstake_) {
            raw_.approve(liveDetf, target_ * 2);
            assertEq(liveExchangeIn.exchangeIn(raw_, target_ * 2, receipt_, target_ * 2,
                bob, false, block.timestamp), target_ * 2);
        }
        IERC20 input_ = unstake_ ? receipt_ : raw_;
        IERC20 output_ = unstake_ ? raw_ : receipt_;
        uint256 balance_ = input_.balanceOf(bob);
        uint256 received_ = output_.balanceOf(bob);
        uint256 supply_ = raw_.totalSupply();
        assertGe(balance_, target_ * 2);
        input_.approve(liveDetf, target_ * 2);
        assertEq(exchange_.previewExchangeOut(input_, output_, target_), target_);
        vm.expectRevert();
        exchange_.exchangeOut(input_, target_ - 1, output_, target_, bob, false, block.timestamp);
        assertEq(input_.balanceOf(bob), balance_);
        assertEq(output_.balanceOf(bob), received_);
        assertEq(exchange_.exchangeOut(input_, target_ * 2, output_, target_, bob, false, block.timestamp), target_);
        vm.stopPrank();
        assertEq(input_.balanceOf(bob), balance_ - target_);
        assertEq(output_.balanceOf(bob), received_ + target_);
        assertEq(raw_.totalSupply(), supply_);
    }

    function test_T_LOCAL_PUSH_transferToDetf_true_whenClaimedLeU() public virtual {
        IERC20 buffer_ = IERC20(liveInfo.bufferToken());
        uint256 amt_ = _fixtureAmount(50e18);
        _fundBuffer(bob, amt_);
        vm.prank(bob);
        buffer_.transfer(liveDetf, amt_);
        uint256 R0 = liveBook.reserveOfToken(address(buffer_));
        uint256 B0 = buffer_.balanceOf(liveDetf);
        assertTrue(B0 - R0 >= amt_, "U covers");
        vm.prank(bob);
        uint256 out_ = liveExchangeIn.exchangeIn(
            buffer_, amt_, IERC20(liveDetf), 0, bob, true, block.timestamp + 1 hours
        );
        assertTrue(out_ > 0, "T-LOCAL-PUSH");
        assertEq(liveBook.reserveOfToken(address(buffer_)), buffer_.balanceOf(liveDetf), "R==B");
    }

    function test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts() public virtual {
        _mintDetfFromBuffer(liveDetf, bob, _fixtureAmount(40e18));
        IERC20 buffer_ = IERC20(liveInfo.bufferToken());
        assertEq(liveBook.reserveOfToken(address(buffer_)), buffer_.balanceOf(liveDetf), "booked");
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1, 0)
        );
        vm.prank(bob);
        liveExchangeIn.exchangeIn(
            buffer_, 1, IERC20(liveDetf), 0, bob, true, block.timestamp + 1 hours
        );
    }
}
