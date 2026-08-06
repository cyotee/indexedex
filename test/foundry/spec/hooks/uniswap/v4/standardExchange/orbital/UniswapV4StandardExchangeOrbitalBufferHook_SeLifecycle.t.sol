// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
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
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";

/**
 * @notice Strategist-required 1-SE full lifecycle: zap preview==exec, multipath add/remove, growth mint.
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_SeLifecycleTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    IUniswapV4StandardExchangeOrbitalBufferHook internal seHook;
    address internal seH;

    function setUp() public override {
        super.setUp();
        // Redeploy product with SE on token0 only
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, false, false);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        seH = PkgFactory.deployHook(hookPkg, args, mineNonce);
        seHook = IUniswapV4StandardExchangeOrbitalBufferHook(seH);

        token0.mint(user, 5_000_000 ether);
        token1.mint(user, 5_000_000 ether);
        token2.mint(user, 5_000_000 ether);
        vm.startPrank(user);
        token0.approve(seH, type(uint256).max);
        token1.approve(seH, type(uint256).max);
        token2.approve(seH, type(uint256).max);
        vm.stopPrank();
    }

    function _seed1SeFull(uint256 amt) internal returns (uint256 shares) {
        vm.prank(user);
        (shares,,,) =
            seHook.addLiquidity(amt, amt, amt, user, 0, block.timestamp + 1 hours, "");
        assertGt(seHook.seBalance(0), 0, "buffered SE shares");
        assertEq(seHook.rawReserve(0), 0, "raw book 0 on SE leg");
        assertGt(seHook.radius(), 0);
    }

    function test_1se_zap_previewEqualsExec_and_noLeftoverFreeFace() public {
        _seed1SeFull(300 ether);
        _setDexFeeOn(seH, 0.003e18);

        uint256 amountIn = 30 ether;
        uint256 preview = seHook.previewDepositSingle(address(token1), amountIn);
        assertGt(preview, 0, "preview shares");

        uint256 lpBefore = IERC20(seH).balanceOf(user);
        vm.prank(user);
        uint256 shares = seHook.depositSingle(
            address(token1), amountIn, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, preview, "1-SE zap preview==exec");
        assertEq(IERC20(seH).balanceOf(user) - lpBefore, shares);

        // Leftover free face on hook should be zero (unused refunded; buffered dust ≤ 10)
        assertLe(token0.balanceOf(seH), 10, "token0 free dust");
        // token1 residual free should be refunded (raw leg)
        assertEq(token1.balanceOf(seH), seHook.rawReserve(1), "token1 free==book");
        assertEq(token2.balanceOf(seH), seHook.rawReserve(2), "token2 free==book");
    }

    function test_1se_multipath_add_remove_previewEqualsExec() public {
        _seed1SeFull(200 ether);

        (uint256 pShares, uint256 p0, uint256 p1, uint256 p2) =
            seHook.previewAddLiquidity(40 ether, 40 ether, 40 ether);
        vm.prank(user);
        (uint256 eShares, uint256 e0, uint256 e1, uint256 e2) =
            seHook.addLiquidity(40 ether, 40 ether, 40 ether, user, 0, block.timestamp + 1 hours, "");
        assertEq(eShares, pShares);
        assertEq(e0, p0);
        assertEq(e1, p1);
        assertEq(e2, p2);

        uint256 half = eShares / 2;
        (uint256 r0, uint256 r1, uint256 r2) = seHook.previewRemoveLiquidity(half);
        vm.prank(user);
        (uint256 a0, uint256 a1, uint256 a2) =
            seHook.removeLiquidity(half, user, 0, 0, 0, block.timestamp + 1 hours);
        assertEq(a0, r0);
        assertEq(a1, r1);
        assertEq(a2, r2);
    }

    function test_1se_v4_swap_and_seExchange_on_buffered_leg() public {
        _seed1SeFull(400 ether);
        // SE In path: token1 → token0 (out is buffered)
        uint256 amountIn = 5 ether;
        uint256 prev = IStandardExchangeIn(seH).previewExchangeIn(
            IERC20(address(token1)), amountIn, IERC20(address(token0))
        );
        assertGt(prev, 0);
        uint256 before = token0.balanceOf(user);
        vm.prank(user);
        uint256 out = IStandardExchangeIn(seH).exchangeIn(
            IERC20(address(token1)),
            amountIn,
            IERC20(address(token0)),
            prev,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, prev);
        assertEq(token0.balanceOf(user) - before, out);
    }

    function _setDexFeeOn(address h, uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(h, feeWad);
    }

    function _setUsageFeeOn(address h, uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(h, feeWad);
    }

    function test_1se_protocolGrowth_assertGt() public {
        // Gold pattern: seed → usage fee → snapshot add → round-trip residual swaps → mint
        _seed1SeFull(200 ether);
        _setUsageFeeOn(seH, 0.05e18);
        _setDexFeeOn(seH, 0.01e18);
        vm.prank(user);
        seHook.addLiquidity(1 ether, 1 ether, 1 ether, user, 0, block.timestamp + 1 hours, "");
        assertGt(seHook.kLast(), 0, "kLast set");

        // Round-trip on raw legs 1↔2 via SE In/Out surface (same book as V4)
        for (uint256 i; i < 5; i++) {
            vm.startPrank(user);
            IStandardExchangeIn(seH).exchangeIn(
                IERC20(address(token1)),
                5 ether,
                IERC20(address(token2)),
                0,
                user,
                false,
                block.timestamp + 1 hours
            );
            IStandardExchangeIn(seH).exchangeIn(
                IERC20(address(token2)),
                5 ether,
                IERC20(address(token1)),
                0,
                user,
                false,
                block.timestamp + 1 hours
            );
            vm.stopPrank();
        }

        uint256 feeToBefore = IERC20(seH).balanceOf(feeRecipient);
        vm.prank(user);
        seHook.addLiquidity(2 ether, 2 ether, 2 ether, user, 0, block.timestamp + 1 hours, "");
        assertGt(IERC20(seH).balanceOf(feeRecipient), feeToBefore, "growth mint");
    }
}
