// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_B6_Test
 * @notice Min-SE + B6 SE-share multipath LP deposit/withdraw.
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_B6_Test is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    uint256 internal constant DUST = 2;

    function test_B6_depositSeShareLeg0_mintsLp() public {
        // Default hook: se0 on leg0. Seed book with pair, then deposit SE shares on leg0 + pair on 1/2.
        _seedThreeLeg(100 ether);

        uint256 seAmt = _mintSeSharesToUser(se0, token0, 50 ether);
        token1.mint(user, 50 ether);
        token2.mint(user, 50 ether);

        (uint256 predShares, uint256 predU0, uint256 predU1, uint256 predU2) =
            orbital.previewDepositFlexible(seAmt, true, 50 ether, false, 50 ether, false);

        uint256 seBalBefore = IERC20(se0).balanceOf(hook);
        vm.prank(user);
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) = orbital.depositFlexible(
            seAmt, true, 50 ether, false, 50 ether, false, user, 0, block.timestamp + 1 hours
        );

        assertGt(shares, 0, "lp");
        assertApproxEqAbs(shares, predShares, DUST);
        assertEq(u0, predU0);
        assertEq(u1, predU1);
        assertEq(u2, predU2);
        assertGt(IERC20(se0).balanceOf(hook), seBalBefore, "SE inventory grew");
        assertEq(orbital.rawReserve(0), 0, "buffered leg raw book 0");
    }

    function test_B6_depositAllSeShares_threeLegs() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, true, true);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h);
        hook = h;
        orbital = IUniswapV4StandardExchangeOrbitalBufferHook(h);

        uint256 s0 = _mintSeSharesToUser(se0, token0, 100 ether);
        uint256 s1 = _mintSeSharesToUser(se1, token1, 100 ether);
        uint256 s2 = _mintSeSharesToUser(se2, token2, 100 ether);
        vm.startPrank(user);
        IERC20(se0).approve(h, type(uint256).max);
        IERC20(se1).approve(h, type(uint256).max);
        IERC20(se2).approve(h, type(uint256).max);

        (uint256 predShares,,,) = orbital.previewDepositFlexible(s0, true, s1, true, s2, true);
        (uint256 shares,,,) = orbital.depositFlexible(
            s0, true, s1, true, s2, true, user, 0, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(shares, 0);
        assertApproxEqAbs(shares, predShares, DUST);
        assertGt(IERC20(se0).balanceOf(h), 0);
        assertGt(IERC20(se1).balanceOf(h), 0);
        assertGt(IERC20(se2).balanceOf(h), 0);
        assertGt(orbital.radius(), 0);
    }

    function test_B6_withdrawSeShares_paysSe() public {
        _seedThreeLeg(100 ether);
        uint256 lp = IERC20(hook).balanceOf(user);
        uint256 half = lp / 2;

        uint256 se0Before = IERC20(se0).balanceOf(user);
        uint256 t1Before = token1.balanceOf(user);
        uint256 t2Before = token2.balanceOf(user);

        (uint256 pred0, uint256 pred1, uint256 pred2) =
            orbital.previewWithdrawFlexible(half, true, false, false);

        vm.prank(user);
        (uint256 a0, uint256 a1, uint256 a2) = orbital.withdrawFlexible(
            half, user, true, false, false, 0, 0, 0, block.timestamp + 1 hours
        );

        assertApproxEqAbs(a0, pred0, DUST);
        assertApproxEqAbs(a1, pred1, DUST);
        assertApproxEqAbs(a2, pred2, DUST);
        assertEq(IERC20(se0).balanceOf(user) - se0Before, a0, "SE paid");
        assertEq(token1.balanceOf(user) - t1Before, a1, "pair1 paid");
        assertEq(token2.balanceOf(user) - t2Before, a2, "pair2 paid");
        assertGt(a0, 0);
        assertGt(a1, 0);
        assertGt(a2, 0);
    }

    function test_B6_pairPathsStillWork() public {
        uint256 shares = _seedThreeLeg(80 ether);
        assertGt(shares, 0);
        (uint256 predFlex,,,) =
            orbital.previewDepositFlexible(20 ether, false, 20 ether, false, 20 ether, false);
        (uint256 predAdd,,,) = orbital.previewAddLiquidity(20 ether, 20 ether, 20 ether);
        assertEq(predFlex, predAdd);

        vm.prank(user);
        (uint256 lp,,,) = orbital.depositFlexible(
            20 ether, false, 20 ether, false, 20 ether, false, user, 0, block.timestamp + 1 hours
        );
        assertApproxEqAbs(lp, predAdd, DUST);

        vm.prank(user);
        (uint256 a0, uint256 a1, uint256 a2) =
            orbital.removeLiquidity(lp / 2, user, 0, 0, 0, block.timestamp + 1 hours);
        assertGt(a0, 0);
        assertGt(a1, 0);
        assertGt(a2, 0);
    }

    function test_B6_seShareFlagOnRawLeg_reverts() public {
        _seedThreeLeg(50 ether);
        vm.prank(user);
        vm.expectRevert();
        orbital.depositFlexible(
            10 ether, false, 10 ether, true, 10 ether, false, user, 0, block.timestamp + 1 hours
        );
    }

    function test_B6_firstMint_withSeShares() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, true, true);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook);
        orbital = IUniswapV4StandardExchangeOrbitalBufferHook(hook);

        uint256 s0 = _mintSeSharesToUser(se0, token0, 80 ether);
        uint256 s1 = _mintSeSharesToUser(se1, token1, 80 ether);
        uint256 s2 = _mintSeSharesToUser(se2, token2, 80 ether);
        vm.startPrank(user);
        IERC20(se0).approve(hook, type(uint256).max);
        IERC20(se1).approve(hook, type(uint256).max);
        IERC20(se2).approve(hook, type(uint256).max);
        (uint256 shares,,,) = orbital.depositFlexible(
            s0, true, s1, true, s2, true, user, 0, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(shares, 0);
        assertGt(orbital.radius(), 0);
    }
}
