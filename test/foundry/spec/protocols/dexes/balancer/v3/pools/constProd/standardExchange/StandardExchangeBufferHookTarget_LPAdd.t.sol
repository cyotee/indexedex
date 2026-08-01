// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AddLiquidityKind} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";

import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title HookLPAddTest
 * @notice Access-control coverage for StandardExchangeBufferHookTarget.onBeforeAddLiquidity
 *         and onAfterAddLiquidity that cannot be exercised through the Balancer V3 RouterMock.
 *
 * @dev Following Change 1 of the refactor plan, UNBALANCED and SINGLE_TOKEN_EXACT_OUT kinds are now
 *      permitted. The previous tests that verified AddLiquidityNotProportional reverts for those kinds
 *      have been retired.
 *
 *      Tests retained:
 *        1. rejectsWrongCaller  - onBeforeAddLiquidity returns false for non-Vault msg.sender.
 *        2. rejectsWrongPool    - onBeforeAddLiquidity returns false when pool arg ≠ address(this).
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

    /// @notice UNBALANCED add-liquidity is now permitted; onBeforeAddLiquidity must return true.
    function test_acceptsUnbalanced() public {
        uint256[] memory max = new uint256[](2);
        max[0] = 10e18;
        max[1] = 10e18;
        vm.prank(address(bv3Vault));
        bool ok = IHooks(bufferPool).onBeforeAddLiquidity(
            address(0), bufferPool, AddLiquidityKind.UNBALANCED,
            max, 0, new uint256[](2), ""
        );
        assertTrue(ok, "onBeforeAddLiquidity must return true for UNBALANCED kind");
    }

    /// @notice SINGLE_TOKEN_EXACT_OUT add-liquidity is now permitted; onBeforeAddLiquidity must return true.
    function test_acceptsSingleTokenExactOut() public {
        uint256[] memory max = new uint256[](2);
        max[0] = 10e18;
        max[1] = 0;
        vm.prank(address(bv3Vault));
        bool ok = IHooks(bufferPool).onBeforeAddLiquidity(
            address(0), bufferPool, AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT,
            max, 0, new uint256[](2), ""
        );
        assertTrue(ok, "onBeforeAddLiquidity must return true for SINGLE_TOKEN_EXACT_OUT kind");
    }
}
