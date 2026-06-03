// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolLiquidityTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityTarget.sol";

/**
 * @title LiquidityTargetExposed
 * @notice Concrete harness exposing the abstract StandardExchangeBufferPoolLiquidityTarget for
 *         isolated unit testing.
 *
 * @dev WHY THIS IS A DIRECT-CALL HARNESS (no Vault / SE-vault stack needed):
 *
 *      onAddLiquidityCustom and onRemoveLiquidityCustom are both pure-passthrough functions
 *      whose only real guard is:
 *
 *          if (router != address(this)) revert NotHookCaller(router);
 *
 *      They do not read virtualTTA, hookSharesDelta, or any Repo storage.  They do not call the
 *      Balancer Vault or the Standard Exchange Vault.  Their correctness can therefore be verified
 *      without deploying the full integration stack.
 *
 *      The test calls t.callOnAdd(address(t), amts) so that `router == address(t)` which is
 *      `address(this)` inside the target's execution context — satisfying the guard.
 *      For the negative path the test passes an arbitrary address that is NOT `address(t)` and
 *      asserts that the NotHookCaller error is emitted.
 *
 *      If the guard logic or passthrough semantics change in the future (e.g. the hook starts
 *      reading Repo state), migrate this test to inherit TestBase_StandardExchangeBufferPool so
 *      the full stack is available.
 */
contract LiquidityTargetExposed is StandardExchangeBufferPoolLiquidityTarget {
    function callOnAdd(address router, uint256[] memory amts)
        external returns (uint256[] memory, uint256, uint256[] memory, bytes memory)
    {
        return this.onAddLiquidityCustom(router, amts, 0, new uint256[](2), "");
    }
    function callOnRemove(address router, uint256[] memory amts)
        external returns (uint256, uint256[] memory, uint256[] memory, bytes memory)
    {
        return this.onRemoveLiquidityCustom(router, 0, amts, new uint256[](2), "");
    }
}

/**
 * @title StandardExchangeBufferPoolLiquidityTargetTest
 * @notice Unit tests for the CUSTOM add/remove liquidity passthrough guard in
 *         StandardExchangeBufferPoolLiquidityTarget.
 *
 * @dev No Vault or SE-vault deployment required — see LiquidityTargetExposed NatSpec for
 *      the rationale.  Tests use address(0xBEEF) and address(0xDEAD) purely as sentinel
 *      values for the "wrong router" negative paths; they do not represent real contracts.
 */
contract StandardExchangeBufferPoolLiquidityTargetTest is Test {
    LiquidityTargetExposed t;
    function setUp() public { t = new LiquidityTargetExposed(); }

    /// @notice CUSTOM add-liquidity passes through when the caller is the hook itself.
    function test_addCustom_acceptsFromSelf() public {
        uint256[] memory amts = new uint256[](2); amts[0] = 5e18; amts[1] = 0;
        (uint256[] memory inScaled18, uint256 bptOut, uint256[] memory fees,) = t.callOnAdd(address(t), amts);
        assertEq(inScaled18[0], 5e18); assertEq(inScaled18[1], 0);
        assertEq(bptOut, 0);
        assertEq(fees.length, 2); assertEq(fees[0], 0); assertEq(fees[1], 0);
    }

    /// @notice CUSTOM add-liquidity reverts with NotHookCaller when called from a non-hook address.
    function test_addCustom_revertsForNonHookCaller() public {
        uint256[] memory amts = new uint256[](2); amts[0] = 5e18; amts[1] = 0;
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeBufferPool.NotHookCaller.selector, address(0xBEEF)));
        t.callOnAdd(address(0xBEEF), amts);
    }

    /// @notice CUSTOM remove-liquidity passes through when the caller is the hook itself.
    function test_removeCustom_acceptsFromSelf() public {
        uint256[] memory amts = new uint256[](2); amts[0] = 0; amts[1] = 7e18;
        (uint256 bptIn, uint256[] memory out, uint256[] memory fees,) = t.callOnRemove(address(t), amts);
        assertEq(bptIn, 0);
        assertEq(out[0], 0); assertEq(out[1], 7e18);
        assertEq(fees.length, 2);
    }

    /// @notice CUSTOM remove-liquidity reverts with NotHookCaller when called from a non-hook address.
    function test_removeCustom_revertsForNonHookCaller() public {
        uint256[] memory amts = new uint256[](2); amts[0] = 0; amts[1] = 7e18;
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeBufferPool.NotHookCaller.selector, address(0xDEAD)));
        t.callOnRemove(address(0xDEAD), amts);
    }
}
