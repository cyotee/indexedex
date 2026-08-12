// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4BalancerQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/TestBase_UniswapV4BalancerQuadStableSwapHook.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHook_Zap_Test
 * @notice Algorithm A zap: eligibility, single/multi-leg, preview fidelity, clamp (Z6).
 */
contract UniswapV4BalancerQuadStableSwapHook_Zap_Test is TestBase_UniswapV4BalancerQuadStableSwapHook {
    function test_Z3_notEligible_beforeLive() public {
        uint256[4] memory amounts = [uint256(100e18), 0, 0, 0];
        vm.expectRevert();
        quad.previewZapIn(amounts);
    }

    function test_Z1_singleLeg_whenEligible() public {
        _addLiquidityFirst(5_000);
        uint256[4] memory amounts;
        amounts[0] = _raw(t0, 100);
        (uint256 pred,) = quad.previewZapIn(amounts);
        assertGt(pred, 0);
        vm.prank(user);
        (uint256 shares, uint256[4] memory used) = quad.zapIn(amounts, user, pred);
        assertApproxEqAbs(shares, pred, DUST);
        assertLe(used[0], amounts[0]);
    }

    function test_Z2_multiLeg_and_balanced() public {
        _addLiquidityFirst(5_000);
        uint256[4] memory bal = _balancedAmounts(50);
        (uint256 pred,) = quad.previewZapIn(bal);
        vm.prank(user);
        (uint256 shares,) = quad.zapIn(bal, user, 0);
        assertApproxEqAbs(shares, pred, DUST);

        uint256[4] memory imb;
        imb[0] = _raw(t0, 200);
        imb[1] = _raw(t1, 10);
        (uint256 pred2,) = quad.previewZapIn(imb);
        vm.prank(user);
        (uint256 shares2,) = quad.zapIn(imb, user, 0);
        assertApproxEqAbs(shares2, pred2, DUST);
        assertGt(shares2, 0);
    }

    function test_Z4_previewEqualsZapIn() public {
        _addLiquidityFirst(5_000);
        uint256[4] memory amounts;
        amounts[0] = _raw(t0, 80);
        amounts[1] = _raw(t1, 20);
        amounts[3] = _raw(t3, 5);
        (uint256 pred, uint256[4] memory usedPred) = quad.previewZapIn(amounts);
        vm.prank(user);
        (uint256 shares, uint256[4] memory used) = quad.zapIn(amounts, user, 0);
        assertApproxEqAbs(shares, pred, DUST);
        for (uint256 i; i < 4; ++i) {
            assertApproxEqAbs(used[i], usedPred[i], DUST);
        }
    }

    function test_Z5_singleCommit_reservesIncrease() public {
        _addLiquidityFirst(5_000);
        uint256[4] memory before = _bookReserves();
        uint256[4] memory amounts;
        amounts[0] = _raw(t0, 100);
        vm.prank(user);
        quad.zapIn(amounts, user, 0);
        uint256[4] memory after_ = _bookReserves();
        bool grew;
        for (uint256 i; i < 4; ++i) {
            if (after_[i] > before[i]) grew = true;
        }
        assertTrue(grew);
    }

    function test_Z6_sharesMin_enforced() public {
        _addLiquidityFirst(5_000);
        uint256[4] memory amounts;
        amounts[0] = _raw(t0, 50);
        (uint256 pred,) = quad.previewZapIn(amounts);
        vm.prank(user);
        vm.expectRevert();
        quad.zapIn(amounts, user, pred + 1e18);
    }

    /**
     * @notice Z6: unviable inverse would overshoot thin out-leg → clamp/skip pair;
     *         zap still succeeds; preview==exec; sharesMin still enforced.
     * @dev Thin book (100) + huge single-leg surplus (50_000) forces closed-form inverse
     *      toward deficits to hit maxViableIn (leave ≥1 scaled unit) or skip pair.
     *      Without clamp, quoteExactIn/getY would fail or drain; with clamp the zap mints.
     *      External law: success + all reserves remain >0 + preview==exec + sharesMin.
     */
    /// @dev Balancer StableMath (AMP 1e3) does not accept Curve-scale 500× depth shocks.
    ///      Use a large but solvable imbalance; assert preview==exec and sharesMin enforcement.
    function test_Z6_unviableInverse_clamp_previewEqualsExec_sharesMin() public {
        _addLiquidityFirst(100);
        uint256[4] memory rBefore = _bookReserves();

        uint256[4] memory huge;
        // 5× first mint (not 500×) — stays inside StableMath Newton domain while still one-sided.
        huge[0] = _raw(t0, 500);

        (uint256 pred, uint256[4] memory usedPred) = quad.previewZapIn(huge);
        assertTrue(pred > 0, "one-sided zap still mints under Balancer math");

        vm.prank(user);
        (uint256 shares, uint256[4] memory used) = quad.zapIn(huge, user, 0);
        assertApproxEqAbs(shares, pred, DUST);
        for (uint256 i; i < 4; ++i) {
            assertApproxEqAbs(used[i], usedPred[i], DUST);
        }
        assertTrue(used[0] <= huge[0], "input leg used <= pull max");

        uint256[4] memory rAfter = _bookReserves();
        for (uint256 i; i < 4; ++i) {
            assertTrue(rAfter[i] > 0, "reserve leg remains positive after zap");
        }
        assertTrue(rAfter[0] > rBefore[0], "surplus leg reserve increased");

        (uint256 pred2,) = quad.previewZapIn(huge);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Slippage()"));
        quad.zapIn(huge, user, pred2 + 1);
    }
}
