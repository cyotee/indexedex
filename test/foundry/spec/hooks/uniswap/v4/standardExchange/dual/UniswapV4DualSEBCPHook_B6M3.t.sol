// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {TestBase_UniswapV4DualSEBCPHook} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";

/**
 * @title UniswapV4DualSEBCPHook_B6M3_Test
 * @notice B6 SE-share LP deposit/withdraw + M3 IStandardExchangeIn/Out surface.
 */
contract UniswapV4DualSEBCPHook_B6M3_Test is TestBase_UniswapV4DualSEBCPHook {
    function test_B6_depositSeSharesBothLegs_mintsLp() public {
        uint256 seAOut = _userAcquireSeShares(seA, tokenA, 100 ether);
        uint256 seBOut = _userAcquireSeShares(seB, tokenB, 100 ether);

        address c0 = dual.currency0();
        bool se0IsA = _seForCurrency(c0) == seA;
        uint256 seAmt0 = se0IsA ? seAOut : seBOut;
        uint256 seAmt1 = se0IsA ? seBOut : seAOut;

        (uint256 predLp, uint256 predU0, uint256 predU1) =
            dual.previewDepositFlexible(seAmt0, true, seAmt1, true);

        vm.prank(user);
        (uint256 lp, uint256 u0, uint256 u1) =
            dual.depositFlexible(seAmt0, true, seAmt1, true, user, 0, block.timestamp + 1);

        assertGt(lp, 0, "lp");
        assertApproxEqAbs(lp, predLp, DUST);
        assertEq(u0, predU0);
        assertEq(u1, predU1);
        assertGt(dual.claimSupplyCurrency0(), 0);
        assertGt(dual.claimSupplyCurrency1(), 0);
        // SE shares sit as inventory on the hook (not unwrapped free pair).
        assertGt(IERC20(seA).balanceOf(hook), 0);
        assertGt(IERC20(seB).balanceOf(hook), 0);
    }

    function test_B6_depositMixed_seAndPair() public {
        _depositBoth(100 ether, 100 ether); // seed book

        uint256 seAOut = _userAcquireSeShares(seA, tokenA, 50 ether);
        address c0 = dual.currency0();
        bool se0IsA = _seForCurrency(c0) == seA;

        uint256 amt0;
        uint256 amt1;
        bool isSe0;
        bool isSe1;
        if (se0IsA) {
            amt0 = seAOut;
            isSe0 = true;
            amt1 = 50 ether;
            isSe1 = false;
            // ensure pair for currency1
            if (dual.currency1() == address(tokenA)) tokenA.mint(user, 50 ether);
            else tokenB.mint(user, 50 ether);
        } else {
            amt1 = seAOut;
            isSe1 = true;
            amt0 = 50 ether;
            isSe0 = false;
            if (dual.currency0() == address(tokenA)) tokenA.mint(user, 50 ether);
            else tokenB.mint(user, 50 ether);
        }

        (uint256 predLp,,) = dual.previewDepositFlexible(amt0, isSe0, amt1, isSe1);
        vm.prank(user);
        (uint256 lp,,) = dual.depositFlexible(amt0, isSe0, amt1, isSe1, user, 0, block.timestamp + 1);
        assertGt(lp, 0);
        assertApproxEqAbs(lp, predLp, DUST);
    }

    function test_B6_withdrawSeShares_paysSe() public {
        uint256 seAOut = _userAcquireSeShares(seA, tokenA, 100 ether);
        uint256 seBOut = _userAcquireSeShares(seB, tokenB, 100 ether);
        address c0 = dual.currency0();
        bool se0IsA = _seForCurrency(c0) == seA;
        uint256 seAmt0 = se0IsA ? seAOut : seBOut;
        uint256 seAmt1 = se0IsA ? seBOut : seAOut;

        vm.prank(user);
        (uint256 lp,,) =
            dual.depositFlexible(seAmt0, true, seAmt1, true, user, 0, block.timestamp + 1);

        address se0 = _seForCurrency(dual.currency0());
        address se1 = _seForCurrency(dual.currency1());
        uint256 se0Before = IERC20(se0).balanceOf(user);
        uint256 se1Before = IERC20(se1).balanceOf(user);

        (uint256 pred0, uint256 pred1) = dual.previewWithdrawFlexible(lp / 2, true, true);
        vm.prank(user);
        (uint256 a0, uint256 a1) =
            dual.withdrawFlexible(lp / 2, user, true, true, 0, 0, block.timestamp + 1);

        assertApproxEqAbs(a0, pred0, DUST);
        assertApproxEqAbs(a1, pred1, DUST);
        assertEq(IERC20(se0).balanceOf(user) - se0Before, a0);
        assertEq(IERC20(se1).balanceOf(user) - se1Before, a1);
        // User received SE shares, not pair tokens as the exit unit.
        assertGt(a0, 0);
        assertGt(a1, 0);
    }

    function test_B6_withdrawMixed_seAndPair() public {
        _depositBoth(100 ether, 100 ether);
        uint256 lp = IERC20(hook).balanceOf(user);
        address se0 = _seForCurrency(dual.currency0());
        address pair1 = dual.currency1();

        uint256 se0Before = IERC20(se0).balanceOf(user);
        uint256 pair1Before = IERC20(pair1).balanceOf(user);

        vm.prank(user);
        (uint256 a0, uint256 a1) =
            dual.withdrawFlexible(lp / 2, user, true, false, 0, 0, block.timestamp + 1);

        assertEq(IERC20(se0).balanceOf(user) - se0Before, a0);
        assertEq(IERC20(pair1).balanceOf(user) - pair1Before, a1);
        assertGt(a0, 0);
        assertGt(a1, 0);
    }

    function test_B6_pairPathsStillWork() public {
        uint256 lp = _depositBoth(80 ether, 80 ether);
        assertGt(lp, 0);
        vm.prank(user);
        (uint256 a0, uint256 a1) = dual.withdraw(lp / 2, user, 0, 0, block.timestamp + 1);
        assertGt(a0, 0);
        assertGt(a1, 0);
    }

    function test_B6_depositFlexible_pairOnly_matchesDeposit() public {
        uint256 a0 = _amountForCurrency(dual.currency0(), 40 ether, 40 ether);
        uint256 a1 = _amountForCurrency(dual.currency1(), 40 ether, 40 ether);
        (uint256 predLp,,) = dual.previewDeposit(a0, a1);
        (uint256 predFlex,,) = dual.previewDepositFlexible(a0, false, a1, false);
        assertEq(predLp, predFlex);

        vm.prank(user);
        (uint256 lp,,) = dual.depositFlexible(a0, false, a1, false, user, 0, block.timestamp + 1);
        assertApproxEqAbs(lp, predLp, DUST);
    }

    function test_M3_supportsSeInterfaces() public view {
        assertTrue(IERC165(hook).supportsInterface(type(IStandardExchangeIn).interfaceId));
        assertTrue(IERC165(hook).supportsInterface(type(IStandardExchangeOut).interfaceId));
    }

    function test_M3_exchangeIn_pair0ToPair1_previewEqualsExec() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        uint256 amountIn = 5 ether;

        uint256 pred = IStandardExchangeIn(hook).previewExchangeIn(IERC20(c0), amountIn, IERC20(c1));
        assertGt(pred, 0);

        // fund caller
        if (c0 == address(tokenA)) tokenA.mint(user, amountIn);
        else tokenB.mint(user, amountIn);

        uint256 balBefore = IERC20(c1).balanceOf(user);
        vm.startPrank(user);
        IERC20(c0).approve(hook, amountIn);
        uint256 got = IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), amountIn, IERC20(c1), 0, user, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertApproxEqAbs(got, pred, DUST);
        assertEq(IERC20(c1).balanceOf(user) - balBefore, got);
    }

    function test_M3_exchangeOut_previewEqualsExec() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        uint256 amountOut = 3 ether;

        uint256 predIn =
            IStandardExchangeOut(hook).previewExchangeOut(IERC20(c0), IERC20(c1), amountOut);
        assertGt(predIn, 0);

        if (c0 == address(tokenA)) tokenA.mint(user, predIn + 1 ether);
        else tokenB.mint(user, predIn + 1 ether);

        uint256 balOutBefore = IERC20(c1).balanceOf(user);
        vm.startPrank(user);
        IERC20(c0).approve(hook, type(uint256).max);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(c0), predIn, IERC20(c1), amountOut, user, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertApproxEqAbs(spent, predIn, DUST);
        assertEq(IERC20(c1).balanceOf(user) - balOutBefore, amountOut);
    }

    function test_M3_unsupportedRoute_reverts() public {
        _depositBoth(50 ether, 50 ether);
        vm.expectRevert();
        IStandardExchangeIn(hook).previewExchangeIn(IERC20(seA), 1 ether, IERC20(address(tokenA)));
    }

    function _seForCurrency(address currency) internal view returns (address) {
        if (currency == dual.token0()) return dual.standardExchange0();
        if (currency == dual.token1()) return dual.standardExchange1();
        revert("unknown currency");
    }
}
