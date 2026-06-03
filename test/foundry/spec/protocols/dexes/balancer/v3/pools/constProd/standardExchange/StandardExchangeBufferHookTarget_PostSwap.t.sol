// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AfterSwapParams, SwapKind} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title HookPostSwapTest
 * @notice Error-path coverage for StandardExchangeBufferHookTarget.onAfterSwap that cannot be
 *         exercised through the Balancer V3 RouterMock (which always calls hooks with the correct
 *         caller address).
 *
 * @dev All happy-path and state-update assertions were retired because they are fully covered by
 *      the integration spec runner:
 *        - call-ordering / state updates → Behavior_Swap_TTAtoShares.behavior_swap_TTAtoShares_endToEnd
 *        - shares→TTA no-op path        → Behavior_Swap_SharesToTTA.behavior_swap_sharesToTTA_endToEnd
 *
 *      The single remaining test asserts that onAfterSwap returns false (rather than reverting)
 *      when called by any address other than the registered Balancer V3 Vault, exercising the
 *      access-control guard that the router cannot trigger through its normal code path.
 */
contract HookPostSwapTest is TestBase_StandardExchangeBufferPool {

    function _afterParams() internal view returns (AfterSwapParams memory) {
        return AfterSwapParams({
            kind: SwapKind.EXACT_IN,
            tokenIn: tta,
            tokenOut: shares,
            amountInScaled18: 10e18,
            amountOutScaled18: 9e18,
            tokenInBalanceScaled18: 10e18,
            tokenOutBalanceScaled18: 91e18,
            amountCalculatedScaled18: 9e18,
            amountCalculatedRaw: 9e18,
            router: address(0),
            pool: bufferPool,
            userData: ""
        });
    }

    /// @notice onAfterSwap must return false (not revert) when called by an address that is
    ///         not the registered Balancer V3 Vault.
    function test_postSwap_rejectsWrongCaller() public {
        vm.prank(address(0xDEAD));
        (bool ok,) = IHooks(bufferPool).onAfterSwap(_afterParams());
        assertFalse(ok, "onAfterSwap must return false for non-Vault caller");
    }
}
