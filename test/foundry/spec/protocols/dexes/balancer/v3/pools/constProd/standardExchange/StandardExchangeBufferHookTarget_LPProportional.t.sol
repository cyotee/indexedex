// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AddLiquidityKind, RemoveLiquidityKind} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";

import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title HookLPProportionalTest
 * @notice Access-control coverage for StandardExchangeBufferHookTarget.onAfterAddLiquidity and
 *         onAfterRemoveLiquidity that cannot be exercised through the Balancer V3 RouterMock.
 *
 * @dev Tests retired as integration-redundant:
 *        - onAfterAddLiquidity_scalesProportionally   → behavior_lpAdd_proportional_sharesOnlyContribution
 *        - onAfterRemoveLiquidity_scalesProportionallyDown → behavior_lpRemove_proportional
 *        - onAfterRemoveLiquidity_clampsVirtualTTAAtZero   → _assertVirtualTTAScaledDown in
 *              Behavior_LP_RemoveProportional already asserts the clamp formula, and the normal
 *              test case exercises the non-exhaustion path. True exhaustion (bptIn ≥ tPre) cannot
 *              occur in a live pool (you cannot burn more BPT than exists).
 *
 *      Tests retained:
 *        1. rejectsWrongCaller - onAfterAddLiquidity returns false for non-Vault msg.sender.
 *        2. rejectsWrongPool   - onAfterRemoveLiquidity returns false when pool arg ≠ address(this).
 *           These access-control guards are never triggered by the RouterMock (which always passes
 *           the correct values), so they are only reachable via direct calls.
 */
contract HookLPProportionalTest is TestBase_StandardExchangeBufferPool {

    /* ---------------------------------------------------------------------- */
    /*                         Access-Control Tests                            */
    /* ---------------------------------------------------------------------- */

    /// @notice onAfterAddLiquidity must return false for any caller that is not the Vault.
    function test_onAfterAddLiquidity_rejectsWrongCaller() public {
        vm.prank(address(0xDEAD));
        (bool ok,) = IHooks(bufferPool).onAfterAddLiquidity(
            address(0), bufferPool, AddLiquidityKind.PROPORTIONAL,
            new uint256[](2), new uint256[](2), 25e18, new uint256[](2), ""
        );
        assertFalse(ok, "onAfterAddLiquidity must return false for non-Vault caller");
    }

    /// @notice onAfterRemoveLiquidity must return false when the pool argument does not match
    ///         the hook's own address (address(this) inside the Diamond).
    function test_onAfterRemoveLiquidity_rejectsWrongPool() public {
        vm.prank(address(bv3Vault));
        (bool ok,) = IHooks(bufferPool).onAfterRemoveLiquidity(
            address(0), address(0xBAD), RemoveLiquidityKind.PROPORTIONAL,
            25e18, new uint256[](2), new uint256[](2), new uint256[](2), ""
        );
        assertFalse(ok, "onAfterRemoveLiquidity must return false when pool arg is wrong");
    }
}
