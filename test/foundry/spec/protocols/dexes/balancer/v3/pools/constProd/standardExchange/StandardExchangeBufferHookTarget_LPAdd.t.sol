// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AddLiquidityKind} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";

import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title HookLPAddTest
 * @notice Error-path and access-control coverage for StandardExchangeBufferHookTarget.onBeforeAddLiquidity
 *         and onAfterAddLiquidity that cannot be exercised through the Balancer V3 RouterMock.
 *
 * @dev Tests retired as integration-redundant:
 *        - customIsNoOp      → behavior_errors_customAddFromNonHookReverts (spec runner)
 *        - donationIsNoOp    → behavior_adversarial_donationGriefing (spec runner)
 *        - proportionalWithoutTTA_skipsConversion → behavior_lpAdd_proportional_sharesOnlyContribution
 *        - proportionalWithTTA_isPassThroughNoOp  → behavior_lpAdd_proportional_sharesOnlyContribution
 *
 *      Tests retained:
 *        1. revertsForUnbalanced / revertsForSingleTokenExactOut — validates the hook's typed-revert
 *           guard on disallowed kinds.  These cannot be reached via the router because
 *           disableUnbalancedLiquidity=true at the Vault level blocks those call-kinds upstream;
 *           the only way to exercise the hook guard is a direct call.  (Note: Change 1 of the
 *           refactor plan will relax this guard — at that point these two tests will be updated
 *           or deleted in the same PR that lands Change 1.)
 *        2. rejectsWrongCaller  — onBeforeAddLiquidity returns false for non-Vault msg.sender.
 *        3. rejectsWrongPool    — onBeforeAddLiquidity returns false when pool arg ≠ address(this).
 */
contract HookLPAddTest is TestBase_StandardExchangeBufferPool {

    /* ---------------------------------------------------------------------- */
    /*                              Shared Helpers                             */
    /* ---------------------------------------------------------------------- */

    function _maxAmounts() internal pure returns (uint256[] memory max) {
        max = new uint256[](2);
        max[0] = 5e18;
        max[1] = 5e18;
    }

    /* ---------------------------------------------------------------------- */
    /*                         Disallowed-Kind Tests                           */
    /* ---------------------------------------------------------------------- */

    /// @notice UNBALANCED add-liquidity must revert with AddLiquidityNotProportional.
    /// @dev Direct call as the real Vault (bv3Vault) to bypass the Vault-level
    ///      disableUnbalancedLiquidity guard, exercising the hook's own kind check.
    function test_revertsForUnbalanced() public {
        uint256[] memory max = new uint256[](2);
        max[0] = 10e18;
        max[1] = 10e18;
        vm.expectRevert(IStandardExchangeBufferPool.AddLiquidityNotProportional.selector);
        vm.prank(address(bv3Vault));
        IHooks(bufferPool).onBeforeAddLiquidity(
            address(0), bufferPool, AddLiquidityKind.UNBALANCED,
            max, 0, new uint256[](2), ""
        );
    }

    /// @notice SINGLE_TOKEN_EXACT_OUT add-liquidity must revert with AddLiquidityNotProportional.
    function test_revertsForSingleTokenExactOut() public {
        uint256[] memory max = new uint256[](2);
        max[0] = 10e18;
        max[1] = 0;
        vm.expectRevert(IStandardExchangeBufferPool.AddLiquidityNotProportional.selector);
        vm.prank(address(bv3Vault));
        IHooks(bufferPool).onBeforeAddLiquidity(
            address(0), bufferPool, AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT,
            max, 0, new uint256[](2), ""
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                         Access-Control Tests                            */
    /* ---------------------------------------------------------------------- */

    /// @notice onBeforeAddLiquidity must return false for any caller that is not the Vault.
    function test_rejectsWrongCaller() public {
        vm.prank(address(0xDEAD));
        bool ok = IHooks(bufferPool).onBeforeAddLiquidity(
            address(0), bufferPool, AddLiquidityKind.PROPORTIONAL,
            _maxAmounts(), 0, new uint256[](2), ""
        );
        assertFalse(ok, "onBeforeAddLiquidity must return false for non-Vault caller");
    }

    /// @notice onBeforeAddLiquidity must return false when the pool argument does not match
    ///         the hook's own address (address(this) inside the Diamond).
    function test_rejectsWrongPool() public {
        vm.prank(address(bv3Vault));
        bool ok = IHooks(bufferPool).onBeforeAddLiquidity(
            address(0), address(0xBAD), AddLiquidityKind.PROPORTIONAL,
            _maxAmounts(), 0, new uint256[](2), ""
        );
        assertFalse(ok, "onBeforeAddLiquidity must return false when pool arg is wrong");
    }
}
