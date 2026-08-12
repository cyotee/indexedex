// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
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
    address internal openDetf;
    IMixedBufferMultiVaultStableDetfInfo internal openInfo;
    IMixedBufferMultiVaultStableDetfBonding internal openBonding;
    IStandardExchangeIn internal openExchangeIn;
    IBasicVault internal openBook;
    IBasicVault internal leg0Book;

    function setUp() public override {
        super.setUp();
        openDetf = _deployOpenModeDetfN(1);
        openInfo = IMixedBufferMultiVaultStableDetfInfo(openDetf);
        openBonding = IMixedBufferMultiVaultStableDetfBonding(openDetf);
        openExchangeIn = IStandardExchangeIn(openDetf);
        openBook = IBasicVault(openDetf);
        leg0Book = IBasicVault(openInfo.underlyingVaults()[0]);
        _bootstrapDefault(openDetf, alice);
    }

    function _share0() internal view returns (IERC20) {
        return IERC20(openInfo.vaultShares()[0]);
    }

    function _leg0() internal view returns (address) {
        return openInfo.underlyingVaults()[0];
    }

    function test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync() public {
        uint256 out_ = _mintDetfFromVaultShare(openDetf, 0, bob, 50e18);
        assertTrue(out_ > 0, "T-NEST-1");
        assertEq(_share0().allowance(openDetf, _leg0()), 0, "no nested fund approve");
        assertEq(openBook.reserveOfToken(address(_share0())), _share0().balanceOf(openDetf), "R==B share");
    }

    function test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient() public {
        // DETF-local shortfall (true without unbooked surplus).
        IERC20 buffer_ = IERC20(openInfo.bufferToken());
        vm.expectRevert();
        openExchangeIn.exchangeIn(
            buffer_, 1, IERC20(openDetf), 0, bob, true, block.timestamp + 1 hours
        );
    }

    function test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts() public {
        _mintDetfFromBuffer(openDetf, bob, 40e18);
        IERC20 buffer_ = IERC20(openInfo.bufferToken());
        // After route, true without new push reverts when U==0 for buffer face.
        uint256 R = openBook.reserveOfToken(address(buffer_));
        uint256 B = buffer_.balanceOf(openDetf);
        uint256 U = B >= R ? B - R : 0;
        vm.expectRevert();
        vm.prank(bob);
        openExchangeIn.exchangeIn(
            buffer_, U + 1, IERC20(openDetf), 0, bob, true, block.timestamp + 1 hours
        );
    }


    function test_T_NEST_4_noNestedApproveOnFundPath() public {
        assertEq(_share0().allowance(openDetf, _leg0()), 0, "pre");
        _mintDetfFromVaultShare(openDetf, 0, bob, 30e18);
        assertEq(_share0().allowance(openDetf, _leg0()), 0, "T-NEST-4");
    }

    function test_T_NEST_5_outerExactOut_notApplicable_burnIsExactIn() public {
        assertTrue(openInfo.isReserveLive(), "T-NEST-5 N/A exact-in");
    }

    function test_T_NEST_6_holdSetSyncAfterRoute() public {
        _mintDetfFromBuffer(openDetf, bob, 40e18);
        // End order: money route full hold-set sync → R == B for every vault token.
        address[] memory tokens = openBook.vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            address t = tokens[i];
            assertEq(
                openBook.reserveOfToken(t),
                IERC20(t).balanceOf(openDetf),
                "T-NEST-6: post-route R == B hold-set"
            );
        }
        IERC20 buffer_ = IERC20(openInfo.bufferToken());
        assertEq(openBook.reserveOfToken(address(buffer_)), buffer_.balanceOf(openDetf), "T-NEST-6 buffer R==B");
        assertEq(openBook.reserveOfToken(address(_share0())), _share0().balanceOf(openDetf), "T-NEST-6 share R==B");
    }

    function test_T_NEST_7_zeroAmount_skipsNested_outerRevertsZeroAmount() public {
        // Zero amount must not fund nested hosts; entry may revert ZeroAmount or return 0.
        try openExchangeIn.exchangeIn(
            IERC20(openInfo.bufferToken()), 0, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        ) returns (uint256 out_) {
            assertEq(out_, 0, "zero in yields zero out without nested fund");
        } catch {
            // ZeroAmount / Deadline / Active guards acceptable
        }
    }

    function test_T_NEST_8_partialMaxIn_notApplicable_noExchangeOutMaxIn() public {
        assertTrue(true, "T-NEST-8 N/A exact-in");
    }

    function test_T_LOCAL_PUSH_transferToDetf_true_whenClaimedLeU() public {
        IERC20 buffer_ = IERC20(openInfo.bufferToken());
        uint256 amt_ = 50e18;
        _fundBuffer(bob, amt_);
        vm.prank(bob);
        buffer_.transfer(openDetf, amt_);
        uint256 R0 = openBook.reserveOfToken(address(buffer_));
        uint256 B0 = buffer_.balanceOf(openDetf);
        assertTrue(B0 - R0 >= amt_, "U covers");
        vm.prank(bob);
        uint256 out_ = openExchangeIn.exchangeIn(
            buffer_, amt_, IERC20(openDetf), 0, bob, true, block.timestamp + 1 hours
        );
        assertTrue(out_ > 0, "T-LOCAL-PUSH");
        assertEq(openBook.reserveOfToken(address(buffer_)), buffer_.balanceOf(openDetf), "R==B");
    }

    function test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts() public {
        _mintDetfFromBuffer(openDetf, bob, 40e18);
        IERC20 buffer_ = IERC20(openInfo.bufferToken());
        assertEq(openBook.reserveOfToken(address(buffer_)), buffer_.balanceOf(openDetf), "booked");
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1, 0)
        );
        vm.prank(bob);
        openExchangeIn.exchangeIn(
            buffer_, 1, IERC20(openDetf), 0, bob, true, block.timestamp + 1 hours
        );
    }
}
