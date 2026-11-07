// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHook_B6Firm
 * @notice B6 SE-share LP deposit/withdraw + firm pair join/exit matrix smoke.
 */
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_B6Firm is TestBase {
    function test_B6_fourBufferedLegs_allOutputMasksPayOnlyRequestedTokens() public {
        _deployHookWithArgs(_argsSeCount(4));
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
        uint256 minted = _firstMintEqual(500 ether);
        uint256 burn = minted / 8;
        address[] memory pairs = quad.tokens();
        for (uint256 mask; mask < 16; ++mask) {
            uint256 checkpoint = vm.snapshotState();
            bool[] memory flags = new bool[](4);
            uint256[4] memory pairBefore;
            uint256[4] memory shareBefore;
            for (uint256 i; i < 4; ++i) {
                flags[i] = (mask & (1 << i)) != 0;
                pairBefore[i] = IERC20(pairs[i]).balanceOf(user);
                shareBefore[i] = IERC20(quad.standardExchange(i)).balanceOf(user);
            }
            uint256[] memory predicted = quad.previewExitProportionalFlexible(burn, flags);
            vm.prank(user);
            uint256[] memory actual = quad.exitProportionalFlexible(burn, user, flags, predicted, block.timestamp);
            assertEq(actual, predicted);
            for (uint256 i; i < 4; ++i) {
                assertGt(actual[i], 0);
                assertEq(IERC20(pairs[i]).balanceOf(user) - pairBefore[i], flags[i] ? 0 : actual[i]);
                assertEq(IERC20(quad.standardExchange(i)).balanceOf(user) - shareBefore[i], flags[i] ? actual[i] : 0);
            }
            assertTrue(vm.revertToState(checkpoint));
        }
    }

    function test_B6_zeroRefundSwapDoesNotInventLocalCredit() public {
        _firstMintEqual(500 ether);
        uint256 localBefore = token0.balanceOf(hook);
        uint256 sharesBefore = quad.seBalance(0);
        (uint256 minted, uint256 refund) = IStandardExchangeIn(se0).previewExchangeIn(
            IERC20(address(token0)), 1 ether, IERC20(se0)
        );
        assertEq(refund, 0);
        _swapExactIn(address(token0), address(token1), 1 ether);
        assertEq(token0.balanceOf(hook), localBefore);
        assertEq(quad.seBalance(0), sharesBefore + minted);
    }

    function test_B6_joinProportionalFlexible_seShareFirstMint_previewEqualsExec() public {
        uint256 seAmt = _userAcquireSeShares(se0, token0, 100 ether);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = seAmt;
        amounts[1] = 100 ether;
        amounts[2] = 100 ether;
        amounts[3] = 100 ether;
        bool[] memory isSe = new bool[](4);
        isSe[0] = true;

        (uint256 predShares, uint256[] memory predUsed) =
            quad.previewJoinProportionalFlexible(amounts, isSe);

        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            quad.joinProportionalFlexible(amounts, isSe, user, 0, block.timestamp + 1 hours);

        assertGt(shares, 0, "lp");
        assertEq(shares, predShares, "preview shares");
        assertEq(used[0], predUsed[0], "used se");
        assertEq(used[1], predUsed[1], "used raw1");
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(quad.nativeReserve(0), quad.seBalance(0), "live SE book");
        assertGt(IERC20(se0).balanceOf(hook), 0, "SE inventory on hook");
        assertEq(IERC20(se0).balanceOf(user), seAmt - used[0], "unused se not pulled");
    }

    function test_B6_joinProportionalFlexible_subsequent_mixed() public {
        _firstMintEqual(100 ether);

        uint256 seAmt = _userAcquireSeShares(se0, token0, 40 ether);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = seAmt;
        amounts[1] = 40 ether;
        amounts[2] = 40 ether;
        amounts[3] = 40 ether;
        bool[] memory isSe = new bool[](4);
        isSe[0] = true;

        (uint256 predShares,) = quad.previewJoinProportionalFlexible(amounts, isSe);
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        (uint256 shares,) =
            quad.joinProportionalFlexible(amounts, isSe, user, 0, block.timestamp + 1 hours);

        assertGt(shares, 0);
        assertEq(shares, predShares);
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, shares);
    }

    function test_B6_exitProportionalFlexible_paysSeShares() public {
        (uint256 mintShares,) = _firstMintSeShareBuffered(100 ether, 100 ether);
        uint256 burn = mintShares / 2;

        bool[] memory recvSe = new bool[](4);
        recvSe[0] = true;
        uint256[] memory mins = new uint256[](4);

        uint256[] memory pred = quad.previewExitProportionalFlexible(burn, recvSe);
        uint256 seBefore = IERC20(se0).balanceOf(user);
        uint256 rawBefore = token1.balanceOf(user);

        vm.prank(user);
        uint256[] memory got =
            quad.exitProportionalFlexible(burn, user, recvSe, mins, block.timestamp + 1 hours);

        assertEq(got[0], pred[0], "se out preview");
        assertEq(got[1], pred[1], "raw out preview");
        assertEq(IERC20(se0).balanceOf(user) - seBefore, got[0], "user got SE shares");
        assertEq(token1.balanceOf(user) - rawBefore, got[1], "user got raw face");
        assertGt(got[0], 0);
        assertGt(got[1], 0);
    }

    function test_B6_exitProportionalFlexible_pairOnly_matchesExit() public {
        uint256 mintShares = _firstMintEqual(80 ether);
        uint256 burn = mintShares / 3;

        bool[] memory recvSe = new bool[](4);
        uint256[] memory predPair = quad.previewExitProportional(burn);
        uint256[] memory predFlex = quad.previewExitProportionalFlexible(burn, recvSe);
        for (uint256 i; i < 4; ++i) {
            assertEq(predFlex[i], predPair[i]);
        }

        uint256[] memory mins = new uint256[](4);
        vm.prank(user);
        uint256[] memory got =
            quad.exitProportionalFlexible(burn, user, recvSe, mins, block.timestamp + 1 hours);
        for (uint256 i; i < 4; ++i) {
            assertEq(got[i], predPair[i]);
        }
    }

    function test_B6_joinProportionalFlexible_pairOnly_matchesJoin() public {
        _firstMintEqual(50 ether);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 10 ether;
        bool[] memory isSe = new bool[](4);

        (uint256 predPair,) = quad.previewJoinProportional(amounts);
        (uint256 predFlex,) = quad.previewJoinProportionalFlexible(amounts, isSe);
        assertEq(predFlex, predPair);

        vm.prank(user);
        (uint256 shares,) =
            quad.joinProportionalFlexible(amounts, isSe, user, 0, block.timestamp + 1 hours);
        assertEq(shares, predPair);
    }

    function test_B6_depositSingleFlexible_seShare_previewEqualsExec() public {
        _firstMintEqual(100 ether);
        uint256 seAmt = _userAcquireSeShares(se0, token0, 15 ether);

        uint256 pred = quad.previewDepositSingleFlexible(address(token0), seAmt, true);
        assertGt(pred, 0);
        assertEq(pred, quad.previewJoinSingleAssetExactInFlexible(address(token0), seAmt, true));

        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 seBefore = IERC20(se0).balanceOf(user);
        vm.prank(user);
        uint256 added = quad.depositSingleFlexible(
            address(token0), seAmt, true, user, pred, block.timestamp + 1 hours
        );
        assertEq(added, pred);
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, added);
        assertLt(IERC20(se0).balanceOf(user), seBefore);
        assertGt(quad.seBalance(0), 0);
    }

    function test_B6_withdrawSingleFlexible_paysSeShares() public {
        _firstMintEqual(100 ether);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 20 ether;
        vm.prank(user);
        (uint256 added,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(added, 0);

        uint256 burn = IERC20(hook).balanceOf(user) / 20;
        uint256 pred = quad.previewWithdrawSingleFlexible(address(token0), burn, true);
        uint256 seBefore = IERC20(se0).balanceOf(user);

        vm.prank(user);
        uint256 out = quad.withdrawSingleFlexible(
            address(token0), burn, true, user, 0, block.timestamp + 1 hours
        );
        assertEq(out, pred);
        assertEq(IERC20(se0).balanceOf(user) - seBefore, out);
        assertGt(out, 0);
    }

    function test_B6_seShareFlag_onRawLeg_reverts() public {
        _firstMintEqual(50 ether);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 1 ether;
        bool[] memory isSe = new bool[](4);
        isSe[1] = true; // raw leg

        vm.expectRevert(abi.encodeWithSignature("SeShareNotBuffered()"));
        quad.previewJoinProportionalFlexible(amounts, isSe);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("SeShareNotBuffered()"));
        quad.joinProportionalFlexible(amounts, isSe, user, 0, block.timestamp + 1 hours);

        vm.expectRevert(abi.encodeWithSignature("SeShareNotBuffered()"));
        quad.previewDepositSingleFlexible(address(token1), 1 ether, true);

        bool[] memory recvSe = new bool[](4);
        recvSe[1] = true;
        vm.expectRevert(abi.encodeWithSignature("SeShareNotBuffered()"));
        quad.previewExitProportionalFlexible(1 ether, recvSe);
    }

    function test_B6_pairPathsStillWork_afterFlexible() public {
        (uint256 s0,) = _firstMintSeShareBuffered(60 ether, 60 ether);
        assertGt(s0, 0);

        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 5 ether;
        vm.prank(user);
        (uint256 s1,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(s1, 0);

        uint256 burn = s1 / 2;
        uint256[] memory mins = new uint256[](4);
        vm.prank(user);
        uint256[] memory out = quad.exitProportional(burn, user, mins, block.timestamp + 1 hours);
        for (uint256 i; i < 4; ++i) {
            assertGt(out[i], 0);
        }
    }

    function test_firm_multiAssetLiquidity_supportsInterface() public view {
        assertTrue(
            IERC165(hook).supportsInterface(type(IStandardExchangeMultiAssetLiquidity).interfaceId),
            "MAL interface"
        );
    }

    function test_firm_unbalancedAndExactOut_stillLive() public {
        _firstMintEqual(200 ether);

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 8 ether;
        amounts[1] = 25 ether;
        amounts[2] = 4 ether;
        amounts[3] = 12 ether;
        uint256 predU = quad.previewJoinUnbalanced(amounts);
        vm.prank(user);
        uint256 sU = quad.joinUnbalanced(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(sU, predU);

        uint256 amountOut = 3 ether;
        uint256 predBurn = quad.previewExitSingleAssetExactTokenOut(address(token1), amountOut);
        vm.prank(user);
        uint256 burned = quad.exitSingleAssetExactTokenOut(
            address(token1), amountOut, user, type(uint256).max, block.timestamp + 1 hours
        );
        assertEq(burned, predBurn);
    }
}
