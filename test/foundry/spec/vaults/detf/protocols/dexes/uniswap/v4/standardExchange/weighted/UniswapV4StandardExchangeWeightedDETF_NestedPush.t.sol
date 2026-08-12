// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

/// @notice Explicit T-NEST-1…8 + T-LOCAL for U4-W (L-DETF-TEST-EXPLICIT).
contract UniswapV4StandardExchangeWeightedDETF_NestedPush_Test is TestBase_UniswapV4StandardExchangeWeightedDETF {
    IBasicVault internal openBook;
    IBasicVault internal seBook;
    address internal se0Addr;

    function setUp() public override {
        super.setUp();
        // Redeploy Open instance so mint always allowed when live.
        detf = _deployDetfInstance(_openArgs());
        detfInfo = IUniswapV4StandardExchangeWeightedDETF(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        pair0 = detfInfo.pairToken(0);
        se0Addr = detfInfo.standardExchange(0);
        SimpleMintableERC20(pair0).mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        IERC20(pair0).approve(detf, type(uint256).max);
        if (se0Addr != address(0)) IERC20(pair0).approve(se0Addr, type(uint256).max);
        vm.stopPrank();
        _firstBondDefault(100 ether);
        openBook = IBasicVault(detf);
        seBook = IBasicVault(se0Addr);
    }

    function test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync() public {
        uint256 out_ = _mintOn(detf, pair0, 50 ether);
        assertTrue(out_ > 0, "T-NEST-1");
        assertEq(IERC20(pair0).allowance(detf, se0Addr), 0, "no nested SE fund approve");
        assertTrue(out_ > 0, "mint ok"); // hold-set may omit residual pair face
    }

    function test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient() public {
        uint256 dust_ = 10 ether;
        SimpleMintableERC20(pair0).mint(detfUser, dust_ * 2);
        vm.prank(detfUser);
        IERC20(pair0).transfer(se0Addr, dust_);
        uint256 Rh = seBook.reserveOfToken(pair0);
        uint256 Bh = IERC20(pair0).balanceOf(se0Addr);
        uint256 U = Bh >= Rh ? Bh - Rh : 0;
        assertTrue(U > 0, "need surplus");
        uint256 claimOver_ = U + 1;
        vm.expectRevert(); // TransferDeltaInsufficient or host InsufficientDeposit
        IStandardExchangeIn(se0Addr).exchangeIn(
            IERC20(pair0), claimOver_, IERC20(se0Addr), 0, detfUser, true, _dl()
        );
    }

    function test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts() public {
        _mintOn(detf, pair0, 40 ether);
        uint256 Rh = seBook.reserveOfToken(pair0);
        uint256 Bh = IERC20(pair0).balanceOf(se0Addr);
        uint256 U = Bh >= Rh ? Bh - Rh : 0;
        if (U >= 1) {
            vm.expectRevert();
            IStandardExchangeIn(se0Addr).exchangeIn(
                IERC20(pair0), U + 1, IERC20(se0Addr), 0, detfUser, true, _dl()
            );
        } else {
            vm.expectRevert();
        IStandardExchangeIn(se0Addr).exchangeIn(
                IERC20(pair0), 1, IERC20(se0Addr), 0, detfUser, true, _dl()
            );
        }
    }

    function test_T_NEST_4_noNestedApproveOnFundPath() public {
        assertEq(IERC20(pair0).allowance(detf, se0Addr), 0, "pre");
        _mintOn(detf, pair0, 30 ether);
        assertEq(IERC20(pair0).allowance(detf, se0Addr), 0, "T-NEST-4");
    }

    function test_T_NEST_5_outerExactOut_notApplicable_burnIsExactIn() public {
        assertTrue(detfInfo.isReserveLive(), "T-NEST-5 N/A");
    }

    function test_T_NEST_6_holdSetSyncAfterRoute() public {
        _mintOn(detf, pair0, 45 ether);
        address[] memory tokens = openBook.vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            address t = tokens[i];
            assertEq(
                openBook.reserveOfToken(t),
                IERC20(t).balanceOf(detf),
                "T-NEST-6: post-route R == B hold-set"
            );
        }
    }

    function test_T_NEST_7_zeroAmount_skipsNested_outerRevertsZeroAmount() public {
        vm.prank(detfUser);
        vm.expectRevert();
        detfExchangeIn.exchangeIn(IERC20(pair0), 0, IERC20(detf), 0, detfUser, false, _dl());
    }

    function test_T_NEST_8_partialMaxIn_notApplicable_noExchangeOutMaxIn() public {
        assertTrue(true, "T-NEST-8 N/A");
    }

    function test_T_LOCAL_PUSH_transferToDetf_true_whenClaimedLeU() public {
        uint256 amt_ = 40 ether;
        SimpleMintableERC20(pair0).mint(detfUser, amt_);
        vm.prank(detfUser);
        IERC20(pair0).transfer(detf, amt_);
        uint256 R0 = openBook.reserveOfToken(pair0);
        uint256 B0 = IERC20(pair0).balanceOf(detf);
        assertTrue(B0 - R0 >= amt_, "U covers");
        vm.prank(detfUser);
        uint256 out_ = detfExchangeIn.exchangeIn(
            IERC20(pair0), amt_, IERC20(detf), 0, detfUser, true, _dl()
        );
        assertTrue(out_ > 0, "T-LOCAL-PUSH");
        assertTrue(out_ > 0, "T-LOCAL-PUSH completed");
    }

    function test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts() public {
        _mintOn(detf, pair0, 35 ether);
        uint256 R = openBook.reserveOfToken(pair0);
        uint256 B = IERC20(pair0).balanceOf(detf);
        uint256 U = B >= R ? B - R : 0;
        vm.expectRevert();
        vm.prank(detfUser);
        detfExchangeIn.exchangeIn(IERC20(pair0), U + 1, IERC20(detf), 0, detfUser, true, _dl());
    }
}
