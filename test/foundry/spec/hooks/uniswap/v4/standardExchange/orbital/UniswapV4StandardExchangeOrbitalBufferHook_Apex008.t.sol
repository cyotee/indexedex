// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/// @notice APEX-2026-008 / R6: this-call surplus refund, capped unwrap, D15 SE pull.
contract UniswapV4StandardExchangeOrbitalBufferHook_Apex008Test is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    /// @dev Matches `Repo.MAX_DUST_WEI`; kept as a test boundary, not a production retain-dust gate.
    uint256 internal constant MAX_DUST_WEI = 10;

    address internal donor = address(0xD0D0);

    function setUp() public override {
        super.setUp();
        _seedThreeLeg(100 ether);
    }

    function _donate(IERC20 token, uint256 amount) internal {
        if (amount == 0) return;
        SimpleMintableERC20(address(token)).mint(donor, amount);
        vm.prank(donor);
        token.transfer(hook, amount);
    }

    function _fundAttacker(uint256 a0, uint256 a1, uint256 a2) internal {
        token0.mint(user, a0);
        token1.mint(user, a1);
        token2.mint(user, a2);
    }

    function _assertRestingUntouched(uint256 face0Before, uint256 feeTo0Before) internal view {
        assertEq(token0.balanceOf(hook), face0Before, "resting token0 remains");
        assertEq(token0.balanceOf(orbital.feeTo()), feeTo0Before, "feeTo got no residual");
    }

    /* ---------------------------------------------------------------------- */
    /* R6.1 / R6.2 / R6.3: 500 resting + 1 funded on all five refund sites   */
    /* ---------------------------------------------------------------------- */

    function test_R6_addLiquidity_resting500_notRefunded() public {
        _donate(token0, 500 ether);
        uint256 face0 = token0.balanceOf(hook);
        uint256 feeTo0 = token0.balanceOf(orbital.feeTo());
        uint256 user0 = token0.balanceOf(user);

        _fundAttacker(1 ether, 1 ether, 1 ether);
        vm.prank(user);
        orbital.addLiquidity(1 ether, 1 ether, 1 ether, user, 0, block.timestamp + 1 hours, "");

        assertLe(token0.balanceOf(user), user0 + 1 ether, "no 499-token profit");
        assertLt(token0.balanceOf(user), user0 + 500 ether, "did not pay resting");
        _assertRestingUntouched(face0, feeTo0);
    }

    function test_R6_depositSingle_resting500_notRefunded() public {
        _donate(token0, 500 ether);
        uint256 face0 = token0.balanceOf(hook);
        uint256 se0Before = IERC20(se0).balanceOf(hook);
        uint256 feeTo0 = token0.balanceOf(orbital.feeTo());
        uint256 user0 = token0.balanceOf(user);

        _fundAttacker(1 ether, 0, 0);
        vm.prank(user);
        orbital.depositSingle(address(token0), 1 ether, user, 0, block.timestamp + 1 hours, "");

        // Unused of this 1 may refund; resting 500 must not.
        assertLt(token0.balanceOf(user), user0 + 500 ether, "did not pay resting");
        assertEq(token0.balanceOf(hook), face0, "resting token0 remains");
        assertEq(token0.balanceOf(orbital.feeTo()), feeTo0, "feeTo got no residual");
        se0Before;
    }

    function test_R6_removeLiquidity_resting500_notRefunded() public {
        _donate(token0, 500 ether);
        uint256 face0 = token0.balanceOf(hook);
        uint256 feeTo0 = token0.balanceOf(orbital.feeTo());
        uint256 user0 = token0.balanceOf(user);
        uint256 lp = IERC20(hook).balanceOf(user) / 20;
        require(lp > 0, "lp");

        vm.prank(user);
        orbital.removeLiquidity(lp, user, 0, 0, 0, block.timestamp + 1 hours);

        // Pro-rata unwrap is legitimate; 500 extra is not.
        assertLt(token0.balanceOf(user) - user0, 500 ether, "did not pay resting");
        assertEq(token0.balanceOf(hook), face0, "resting token0 remains");
        assertEq(token0.balanceOf(orbital.feeTo()), feeTo0, "feeTo got no residual");
    }

    function test_R6_depositFlexible_resting500_notRefunded() public {
        _donate(token0, 500 ether);
        uint256 face0 = token0.balanceOf(hook);
        uint256 seAmt = _mintSeSharesToUser(se0, token0, 2 ether);
        uint256 user0 = token0.balanceOf(user);
        _fundAttacker(0, 2 ether, 2 ether);

        vm.prank(user);
        orbital.depositFlexible(
            seAmt, true, 2 ether, false, 2 ether, false, user, 0, block.timestamp + 1 hours
        );

        assertLt(token0.balanceOf(user), user0 + 500 ether, "did not pay resting");
        assertEq(token0.balanceOf(hook), face0, "resting token0 remains");
    }

    function test_R6_withdrawFlexible_resting500_notRefunded() public {
        _donate(token0, 500 ether);
        uint256 face0 = token0.balanceOf(hook);
        uint256 user0 = token0.balanceOf(user);
        uint256 lp = IERC20(hook).balanceOf(user) / 20;
        require(lp > 0, "lp");

        vm.prank(user);
        orbital.withdrawFlexible(lp, user, true, false, false, 0, 0, 0, block.timestamp + 1 hours);

        assertLt(token0.balanceOf(user) - user0, 500 ether, "did not pay resting");
        assertEq(token0.balanceOf(hook), face0, "resting token0 remains");
    }

    function test_R6_rawLeg_resting500_notRefunded() public {
        _donate(token1, 500 ether);
        uint256 face1 = token1.balanceOf(hook);
        _fundAttacker(1 ether, 1 ether, 1 ether);
        uint256 user1 = token1.balanceOf(user);

        vm.prank(user);
        orbital.addLiquidity(1 ether, 1 ether, 1 ether, user, 0, block.timestamp + 1 hours, "");

        assertLt(token1.balanceOf(user), user1, "paid used; did not collect resting");
        assertGe(token1.balanceOf(hook), face1, "raw resting remains");
    }

    function test_R6_allBuffered_resting500_notRefunded() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _argsWithSE(true, true, true);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h);

        token0.mint(user, 400 ether);
        token1.mint(user, 400 ether);
        token2.mint(user, 400 ether);
        vm.startPrank(user);
        token0.approve(h, type(uint256).max);
        token1.approve(h, type(uint256).max);
        token2.approve(h, type(uint256).max);
        orbital = IUniswapV4StandardExchangeOrbitalBufferHook(h);
        hook = h;
        orbital.addLiquidity(100 ether, 100 ether, 100 ether, user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();

        _donate(token0, 500 ether);
        uint256 face0 = token0.balanceOf(h);
        uint256 user0 = token0.balanceOf(user);

        vm.prank(user);
        orbital.addLiquidity(1 ether, 1 ether, 1 ether, user, 0, block.timestamp + 1 hours, "");

        assertLt(token0.balanceOf(user), user0 + 500 ether, "did not pay resting");
        assertEq(token0.balanceOf(h), face0, "resting remains on all-buffered");
    }

    /* ---------------------------------------------------------------------- */
    /* R6.4 / R6.6: PoolManager swaps, no leftover face, no callback refund    */
    /* ---------------------------------------------------------------------- */

    function test_R6_swapExactIn_noLeftoverFace() public {
        uint256 face0 = token0.balanceOf(hook);
        uint256 preview = orbital.previewSwapExactIn(address(token0), address(token1), 1 ether);
        uint256 outBefore = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), 1 ether);
        assertEq(token1.balanceOf(user) - outBefore, preview, "quoted out");
        assertEq(token0.balanceOf(hook), face0, "no new buffered face");
    }

    function test_R6_swapExactOut_noLeftoverFace() public {
        uint256 face0 = token0.balanceOf(hook);
        uint256 amountOut = 1 ether;
        uint256 amountIn = orbital.previewSwapExactOut(address(token0), address(token1), amountOut);
        uint256 outBefore = token1.balanceOf(user);
        _swapExactOut(address(token0), address(token1), amountOut, amountIn + 1 ether);
        assertEq(token1.balanceOf(user) - outBefore, amountOut, "exact out");
        assertEq(token0.balanceOf(hook), face0, "no new buffered face");
    }

    function test_R6_swapBothDirections_restingUnchanged() public {
        _donate(token0, 500 ether);
        uint256 face0 = token0.balanceOf(hook);
        uint256 pm0 = token0.balanceOf(address(pm));

        _swapExactIn(address(token1), address(token0), 1 ether);
        assertEq(token0.balanceOf(hook), face0, "exact-in 1->0 leaves resting");

        uint256 amountOut = 1 ether;
        uint256 amountIn = orbital.previewSwapExactOut(address(token1), address(token0), amountOut);
        _swapExactOut(address(token1), address(token0), amountOut, amountIn + 1 ether);
        assertEq(token0.balanceOf(hook), face0, "exact-out 1->0 leaves resting");

        assertEq(token0.balanceOf(address(pm)), pm0, "no raw callback refund to PoolManager");
    }

    function test_R6_cappedUnwrap_fundedSuccess() public {
        // Drain toward the 1-wei keep so invert can exceed spendable cap on a later swap.
        uint256 amountOut = 1 ether;
        uint256 amountIn = orbital.previewSwapExactOut(address(token1), address(token0), amountOut);
        uint256 outBefore = token0.balanceOf(user);
        uint256 seBefore = IERC20(se0).balanceOf(hook);
        _swapExactOut(address(token1), address(token0), amountOut, amountIn + 1 ether);
        assertEq(token0.balanceOf(user) - outBefore, amountOut, "funded exact-out");
        assertLt(IERC20(se0).balanceOf(hook), seBefore, "SE burned used shares");
        assertEq(token0.balanceOf(hook), 0, "no leftover buffered face");
    }

    function test_R6_cappedUnwrap_insufficient_rollsBack() public {
        uint256 hugeOut = 10_000 ether;
        uint256 user0 = token0.balanceOf(user);
        uint256 user1 = token1.balanceOf(user);
        uint256 seBefore = IERC20(se0).balanceOf(hook);
        uint256 face0 = token0.balanceOf(hook);

        // R2.4: the named condition is an oversized unwrap that would drain a leg. The direct
        // preview reverts the typed `Drain()` (0xd67a073f, OrbitalBufferHookMath); a bare
        // expectRevert() masked whether the drain guard, not some earlier error, fired.
        vm.expectRevert(abi.encodeWithSignature("Drain()"));
        orbital.previewSwapExactOut(address(token1), address(token0), hugeOut);

        PoolKey memory key = _poolKeyFor(address(token1), address(token0));
        bool zeroForOne = address(token1) == Currency.unwrap(key.currency0);
        vm.prank(user);
        // R2.4: through the PoolManager the same `Drain()` is wrapped by V4's beforeSwap hook path as
        // CustomRevert.WrappedError(address,bytes4,bytes,bytes) (selector 0x90bfb865, CustomRevert.sol).
        // Pin that wrapper selector (its inner Drain() reason is proven exactly by the preview pin above);
        // a partial match avoids the brittle nested-bytes encoding while still rejecting any other revert.
        vm.expectPartialRevert(bytes4(0x90bfb865));
        swapRouter.swapExactOut(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: int256(hugeOut),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
            }),
            1_000 ether,
            ""
        );

        assertEq(token0.balanceOf(user), user0, "rollback out");
        assertEq(token1.balanceOf(user), user1, "rollback in");
        assertEq(IERC20(se0).balanceOf(hook), seBefore, "SE shares rollback");
        assertEq(token0.balanceOf(hook), face0, "face rollback");
    }

    /* ---------------------------------------------------------------------- */
    /* R6.6 / R6.9: dust-boundary resting + unused exact-out                  */
    /* ---------------------------------------------------------------------- */

    function test_R6_dustBoundary_restingLeftInPlace() public {
        uint256[6] memory amounts = [uint256(0), 1, MAX_DUST_WEI - 1, MAX_DUST_WEI, MAX_DUST_WEI + 1, 500 ether];
        for (uint256 i; i < amounts.length; ++i) {
            uint256 rest = amounts[i];
            _donate(token0, rest);
            uint256 face0 = token0.balanceOf(hook);
            _fundAttacker(1 ether, 1 ether, 1 ether);
            vm.prank(user);
            orbital.addLiquidity(1 ether, 1 ether, 1 ether, user, 0, block.timestamp + 1 hours, "");
            assertEq(token0.balanceOf(hook), face0, "dust resting left in place");
        }
    }

    function test_R6_exactOut_falseFlag_pullsUsed_noRefund() public {
        uint256 amountOut = 1 ether;
        uint256 used = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token1)), IERC20(address(token2)), amountOut
        );
        uint256 user1 = token1.balanceOf(user);
        vm.prank(user);
        uint256 paid = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token1)),
            used + 5 ether,
            IERC20(address(token2)),
            amountOut,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(paid, used);
        assertEq(user1 - token1.balanceOf(user), used, "false-flag pulled used only");
    }

    function test_R6_exactOut_trueFlag_refundsCreditMinusUsed() public {
        uint256 amountOut = 1 ether;
        uint256 used = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token1)), IERC20(address(token2)), amountOut
        );
        uint256 maxIn = used + 40;
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        token1.mint(address(this), maxIn);
        token1.approve(address(caller), maxIn);

        uint256 caller1Before = token1.balanceOf(address(caller));
        uint256 outBefore = token2.balanceOf(address(caller));
        caller.consumePretransfer(
            IERC20(address(token1)),
            address(this),
            hook,
            maxIn,
            abi.encodeCall(
                IStandardExchangeOut.exchangeOut,
                (
                    IERC20(address(token1)),
                    maxIn,
                    IERC20(address(token2)),
                    amountOut,
                    address(caller),
                    true,
                    block.timestamp + 1 hours
                )
            )
        );
        assertEq(token2.balanceOf(address(caller)) - outBefore, amountOut, "got exact out");
        assertEq(token1.balanceOf(address(caller)) - caller1Before, maxIn - used, "refund credit-used");
    }

    function test_R6_eoaPretransfer_rejected() public {
        vm.prank(user);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token0)),
            1 ether,
            IERC20(address(token1)),
            0,
            user,
            true,
            block.timestamp + 1 hours
        );

        vm.prank(user);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token0)),
            1 ether,
            IERC20(address(token1)),
            1,
            user,
            true,
            block.timestamp + 1 hours
        );
    }

    function test_R6_previewAgreesAfterCorrection() public {
        uint256 amountIn = 3 ether;
        uint256 preview = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(token0)), amountIn, IERC20(address(token1))
        );
        vm.prank(user);
        uint256 out = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token0)),
            amountIn,
            IERC20(address(token1)),
            preview,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
    }
    /// @notice Buffered prepayment remains credit even when it equals the separate SE claim.
    function test_APEX008_bufferedPretransfer_equalRatedReserve_refundsAllUnused() public {
        _assertBufferedPretransferRefund(1);
    }

    /// @notice A large declared maximum cannot strand an amount equal to the SE claim.
    function test_APEX008_bufferedPretransfer_aboveRatedReserve_refundsAllUnused() public {
        _assertBufferedPretransferRefund(2);
    }

    function _assertBufferedPretransferRefund(uint256 multiple) internal {
        uint256 maxIn = orbital.effectiveReserve(0) * multiple;
        uint256 wantOut = 1 ether;
        uint256 used = IStandardExchangeOut(hook).previewExchangeOut(token0, token1, wantOut);
        assertGt(maxIn, used, "maximum exceeds quoted input");
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        token0.mint(address(this), maxIn);
        token0.approve(address(caller), maxIn);
        bytes memory returned = caller.consumePretransfer(
            token0, address(this), hook, maxIn,
            abi.encodeCall(IStandardExchangeOut.exchangeOut,
                (token0, maxIn, token1, wantOut, address(caller), true, block.timestamp + 1 hours))
        );
        assertEq(abi.decode(returned, (uint256)), used, "quoted input consumed");
        assertEq(token0.balanceOf(address(caller)), maxIn - used, "all unused credit refunded");
        assertEq(token1.balanceOf(address(caller)), wantOut, "exact output paid");
        assertEq(token0.balanceOf(hook), 0, "no prepayment stranded");
    }

}
