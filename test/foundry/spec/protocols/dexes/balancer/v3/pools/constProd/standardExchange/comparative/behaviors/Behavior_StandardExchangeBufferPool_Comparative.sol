// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_StandardExchangeBufferPool_Comparative
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_Comparative
 * @notice Reusable A/B assertions comparing buffer-pool swaps to the reference const-prod pool.
 * @dev Each comparison runs the SAME swap on each pool from an identical pre-state via
 *      vm.snapshotState()/vm.revertToState(), so neither swap perturbs the other's comparison.
 *      The swap actor is `getAlice()` - the pool initializer, guaranteed to hold DAI + shares
 *      permit2/router approvals set during setUp (mirrors the existing passing swap behaviors).
 */
abstract contract Behavior_StandardExchangeBufferPool_Comparative is Test {
    function _base() internal view virtual returns (TestBase_StandardExchangeBufferPool_Comparative);

    function behavior_compare_swap_TTAtoShares_exactIn(uint256 amountIn) public {
        TestBase_StandardExchangeBufferPool_Comparative tb = _base();
        address user = tb.getAlice();

        // Fund once; both branches start from the same snapshot so funding is shared.
        tb.mintTTA(user, amountIn);

        uint256 snap = vm.snapshotState();
        uint256 outBuffer = tb.swapTTAforShares(user, amountIn);
        vm.revertToState(snap);
        uint256 outRef = tb.swapReferenceExactIn(user, tb.tta(), tb.shares(), amountIn);

        _assertClose(outRef, outBuffer, "TTA->shares output mismatch");
    }

    function behavior_compare_swap_sharesToTTA_exactIn(uint256 sharesIn) public {
        TestBase_StandardExchangeBufferPool_Comparative tb = _base();
        address user = tb.getAlice();

        // Acquire comfortably more than sharesIn (mintShares input is a DAI amount, not a share
        // amount, so the share output ratio is not 1:1) and assert sufficiency before swapping.
        uint256 acquired = tb.mintShares(user, sharesIn * 3);
        require(acquired >= sharesIn, "compare: insufficient shares for swap");

        uint256 snap = vm.snapshotState();
        uint256 outBuffer = tb.swapSharesForTTA(user, sharesIn);
        vm.revertToState(snap);
        uint256 outRef = tb.swapReferenceExactIn(user, tb.shares(), tb.tta(), sharesIn);

        _assertClose(outRef, outBuffer, "shares->TTA output mismatch");
    }

    function _assertClose(uint256 a, uint256 b, string memory label) internal {
        // Tolerances are read from the base via public getters (ABS_TOL/REL_TOL are internal const).
        // For small values (<= ABS_TOL) use the absolute bound (relative comparison is meaningless
        // near zero). For larger values use the relative bound only - asserting BOTH unconditionally
        // was incorrect: outputs routinely exceed ABS_TOL (e.g. decimal-offset SE vault shares scale
        // into the billions/trillions of raw units) well before the relative divergence is a problem.
        if (b <= _base().ABS_TOL_()) {
            assertApproxEqAbs(a, b, _base().ABS_TOL_(), label);
        } else {
            assertApproxEqRel(a, b, _base().REL_TOL_(), label);
        }
    }
}
