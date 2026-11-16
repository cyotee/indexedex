// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {TestBase_UniswapV4DualSEBCPHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook_Decimals.sol";

/**
 * @title UniswapV4DualSEBCPHook_B6M3_Decimals
 * @notice Dual B6 SE-share LP + M3 exchangeOut on ERC-4626×ERC-4626 cells `D_U{left}_U{right}`.
 * @dev Left SE underlying `_leftDecimals()`, right `_rightDecimals()`. After PoolKey sort,
 *      pair amounts use `_humanFor`; SE shares are 18-dec metadata and scale with wrap.
 *      Hook LP stays 18. Do not compare a 6-dec transfer to `1 ether`.
 */
abstract contract UniswapV4DualSEBCPHook_B6M3_Decimals is TestBase_UniswapV4DualSEBCPHook_Decimals {
    function test_B6_depositSeSharesBothLegs_mintsLp() public {
        uint256 seAOut = _userAcquireSeShares(seA, tokenA, _uA(100));
        uint256 seBOut = _userAcquireSeShares(seB, tokenB, _uB(100));

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
        assertGt(IERC20(seA).balanceOf(hook), 0);
        assertGt(IERC20(seB).balanceOf(hook), 0);
    }

    function test_B6_depositMixed_seAndPair() public {
        _depositBoth(_uA(100), _uB(100));

        uint256 seAOut = _userAcquireSeShares(seA, tokenA, _uA(50));
        address c0 = dual.currency0();
        bool se0IsA = _seForCurrency(c0) == seA;

        uint256 amt0;
        uint256 amt1;
        bool isSe0;
        bool isSe1;
        if (se0IsA) {
            amt0 = seAOut;
            isSe0 = true;
            amt1 = _humanFor(dual.currency1(), 50);
            isSe1 = false;
            if (dual.currency1() == address(tokenA)) tokenA.mint(user, _uA(50));
            else tokenB.mint(user, _uB(50));
        } else {
            amt1 = seAOut;
            isSe1 = true;
            amt0 = _humanFor(dual.currency0(), 50);
            isSe0 = false;
            if (dual.currency0() == address(tokenA)) tokenA.mint(user, _uA(50));
            else tokenB.mint(user, _uB(50));
        }

        (uint256 predLp,,) = dual.previewDepositFlexible(amt0, isSe0, amt1, isSe1);
        vm.prank(user);
        (uint256 lp,,) = dual.depositFlexible(amt0, isSe0, amt1, isSe1, user, 0, block.timestamp + 1);
        assertGt(lp, 0);
        uint256 slack = predLp / 10_000 + 10;
        assertApproxEqAbs(lp, predLp, slack);
    }

    function test_B6_withdrawSeShares_paysSe() public {
        uint256 seAOut = _userAcquireSeShares(seA, tokenA, _uA(100));
        uint256 seBOut = _userAcquireSeShares(seB, tokenB, _uB(100));
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
        assertGt(a0, 0);
        assertGt(a1, 0);
    }

    function test_B6_withdrawMixed_seAndPair() public {
        _depositBoth(_uA(100), _uB(100));
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

    function test_M3_exchangeOut_previewEqualsExec() public {
        _depositBoth(_uA(200), _uB(200));
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        uint256 amountOut = _humanFor(c1, 3);

        uint256 predIn =
            IStandardExchangeOut(hook).previewExchangeOut(IERC20(c0), IERC20(c1), amountOut);
        assertGt(predIn, 0);

        if (c0 == address(tokenA)) tokenA.mint(user, predIn + _uA(1));
        else tokenB.mint(user, predIn + _uB(1));

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

    function _seForCurrency(address currency) internal view returns (address) {
        if (currency == dual.token0()) return dual.standardExchange0();
        if (currency == dual.token1()) return dual.standardExchange1();
        revert("unknown currency");
    }
}
