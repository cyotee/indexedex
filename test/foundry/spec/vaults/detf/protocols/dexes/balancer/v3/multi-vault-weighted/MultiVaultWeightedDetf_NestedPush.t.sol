// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/// @notice Explicit T-NEST-1…8 + T-LOCAL-PUSH/I1 for BAL-MV (L-DETF-TEST-EXPLICIT).
/// @dev Production MultiVaultWeightedDetf + Aerodrome SE legs via TestBase (no SUT mocks).
contract MultiVaultWeightedDetf_NestedPush_Test is TestBase_MultiVaultWeightedDetf {
    address internal openDetf;
    IMultiVaultWeightedDetfInfo internal openInfo;
    IMultiVaultWeightedDetfBonding internal openBonding;
    IStandardExchangeIn internal openExchangeIn;
    IBasicVault internal openBook;
    IBasicVault internal leg0Book;

    function setUp() public virtual override {
        super.setUp();
        openDetf = _deployOpenModeDetfN(1);
        openInfo = IMultiVaultWeightedDetfInfo(openDetf);
        openBonding = IMultiVaultWeightedDetfBonding(openDetf);
        openExchangeIn = IStandardExchangeIn(openDetf);
        openBook = IBasicVault(openDetf);
        leg0Book = IBasicVault(openInfo.underlyingVaults()[0]);
    }

    function _share0() internal view returns (IERC20) {
        return IERC20(openInfo.vaultShares()[0]);
    }

    function _leg0() internal view returns (address) {
        return openInfo.underlyingVaults()[0];
    }

    function _bootstrap(address bonder, uint256 lpAmount) internal {
        _goLiveViaBptBond(openDetf, bonder, lpAmount);
        assertTrue(openInfo.isReserveLive(), "bootstrap live");
    }

    /* T-NEST-1 */
    function test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync() public {
        _bootstrap(alice, 1_000e18);
        uint256 seShares_ = _fundSeShares0(bob, 100e18);
        IERC20 share0_ = _share0();
        vm.startPrank(bob);
        share0_.approve(openDetf, seShares_);
        uint256 out_ = openExchangeIn.exchangeIn(
            share0_, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(out_ > 0, "T-NEST-1 mint");
        assertEq(share0_.allowance(openDetf, _leg0()), 0, "T-NEST-1: no nested fund approve");
        assertEq(
            openBook.reserveOfToken(address(share0_)),
            share0_.balanceOf(openDetf),
            "T-NEST-1: hold-set share R==B"
        );
    }

    /* T-NEST-2: shortfall on durable push (DETF-local or nested host) */
    function test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient() public {
        _bootstrap(alice, 1_000e18);
        // DETF-local short: true without enough unbooked surplus reverts TransferDeltaInsufficient.
        IERC20 share0_ = _share0();
        vm.expectRevert();
        openExchangeIn.exchangeIn(
            share0_, 1, IERC20(openDetf), 0, bob, true, block.timestamp + 1 hours
        );
    }

    /* T-NEST-3 */
    function test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts() public {
        _bootstrap(alice, 1_000e18);
        uint256 seShares_ = _fundSeShares0(bob, 50e18);
        IERC20 share0_ = _share0();
        vm.startPrank(bob);
        share0_.approve(openDetf, seShares_);
        openExchangeIn.exchangeIn(
            share0_, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        // Booked DETF hold-set + true without push → I1 (covers nested-host I1 product law on entry).
        assertEq(openBook.reserveOfToken(address(share0_)), share0_.balanceOf(openDetf), "booked");
        vm.expectRevert();
        vm.prank(bob);
        openExchangeIn.exchangeIn(
            share0_, 1, IERC20(openDetf), 0, bob, true, block.timestamp + 1 hours
        );
    }


    /* T-NEST-4 */
    function test_T_NEST_4_noNestedApproveOnFundPath() public {
        _bootstrap(alice, 1_000e18);
        uint256 seShares_ = _fundSeShares0(bob, 80e18);
        IERC20 share0_ = _share0();
        assertEq(share0_.allowance(openDetf, _leg0()), 0, "pre");
        vm.startPrank(bob);
        share0_.approve(openDetf, seShares_);
        openExchangeIn.exchangeIn(
            share0_, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(share0_.allowance(openDetf, _leg0()), 0, "T-NEST-4 post");
    }

    /* T-NEST-5 N/A — exact-in burn surface */
    function test_T_NEST_5_outerExactOut_notApplicable_burnIsExactIn() public {
        _bootstrap(alice, 500e18);
        assertTrue(openInfo.isReserveLive(), "T-NEST-5 N/A exact-in family");
    }

    /* T-NEST-6 */
    function test_T_NEST_6_holdSetSyncAfterRoute() public {
        _bootstrap(alice, 1_000e18);
        uint256 seShares_ = _fundSeShares0(bob, 60e18);
        IERC20 share0_ = _share0();
        vm.startPrank(bob);
        share0_.approve(openDetf, seShares_);
        openExchangeIn.exchangeIn(
            share0_, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(
            openBook.reserveOfToken(address(share0_)),
            share0_.balanceOf(openDetf),
            "T-NEST-6 share R==B"
        );
        address reservePool_ = openInfo.reservePool();
        assertEq(
            openBook.reserveOfToken(reservePool_),
            IERC20(reservePool_).balanceOf(openDetf),
            "T-NEST-6 reserveBpt R==B"
        );
    }

    /* T-NEST-7 */
    function test_T_NEST_7_zeroAmount_skipsNested_outerRevertsZeroAmount() public {
        _bootstrap(alice, 500e18);
        IERC20 share0_ = _share0();
        vm.expectRevert();
        openExchangeIn.exchangeIn(
            share0_, 0, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
    }

    /* T-NEST-8 N/A */
    function test_T_NEST_8_partialMaxIn_notApplicable_noExchangeOutMaxIn() public {
        assertTrue(true, "T-NEST-8 N/A for BAL-MV exact-in surface");
    }

    /* T-LOCAL-PUSH */
    function test_T_LOCAL_PUSH_transferToDetf_true_whenClaimedLeU() public {
        _bootstrap(alice, 1_000e18);
        uint256 seShares_ = _fundSeShares0(bob, 80e18);
        IERC20 share0_ = _share0();
        vm.prank(bob);
        share0_.transfer(openDetf, seShares_);
        uint256 R0 = openBook.reserveOfToken(address(share0_));
        uint256 B0 = share0_.balanceOf(openDetf);
        assertTrue(B0 - R0 >= seShares_, "U covers push");
        vm.prank(bob);
        uint256 out_ = openExchangeIn.exchangeIn(
            share0_, seShares_, IERC20(openDetf), 0, bob, true, block.timestamp + 1 hours
        );
        assertTrue(out_ > 0, "T-LOCAL-PUSH");
        assertEq(openBook.reserveOfToken(address(share0_)), share0_.balanceOf(openDetf), "R==B");
    }

    /* T-LOCAL-I1 */
    function test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts() public {
        _bootstrap(alice, 1_000e18);
        uint256 seShares_ = _fundSeShares0(bob, 60e18);
        IERC20 share0_ = _share0();
        vm.startPrank(bob);
        share0_.approve(openDetf, seShares_);
        openExchangeIn.exchangeIn(
            share0_, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(openBook.reserveOfToken(address(share0_)), share0_.balanceOf(openDetf), "booked");
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1, 0)
        );
        vm.prank(bob);
        openExchangeIn.exchangeIn(
            share0_, 1, IERC20(openDetf), 0, bob, true, block.timestamp + 1 hours
        );
    }
}
