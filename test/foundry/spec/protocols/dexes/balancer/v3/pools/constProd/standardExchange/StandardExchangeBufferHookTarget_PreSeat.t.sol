// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    PoolSwapParams,
    SwapKind
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";

import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title HookPreSeatTest
 * @notice Error-path coverage for StandardExchangeBufferHookTarget.onBeforeSwap that cannot be
 *         exercised through the Balancer V3 RouterMock (which always calls hooks with the correct
 *         caller address).
 *
 * @dev All happy-path and state-update assertions were retired because they are fully covered by
 *      the integration spec runner:
 *        - call-ordering / state deferral → Behavior_Swap_SharesToTTA.behavior_swap_sharesToTTA_endToEnd
 *        - clamping reverts              → Behavior_Clamping.behavior_clamping_revertsWhen*
 *        - TTA→shares no-op path        → Behavior_Swap_TTAtoShares.behavior_swap_TTAtoShares_endToEnd
 *
 *      The single remaining test asserts that onBeforeSwap returns false (rather than reverting)
 *      when called by any address other than the registered Balancer V3 Vault, exercising the
 *      access-control guard that the router cannot trigger through its normal code path.
 */
contract HookPreSeatTest is TestBase_StandardExchangeBufferPool {

    function _sharesInParams() internal view returns (PoolSwapParams memory) {
        uint256[] memory bal = new uint256[](2);
        bal[0] = 0;
        bal[1] = 100e18;
        return PoolSwapParams({
            kind: SwapKind.EXACT_IN,
            amountGivenScaled18: 10e18,
            balancesScaled18: bal,
            indexIn: IStandardExchangeBufferPoolTestView(bufferPool).sharesIndex(),
            indexOut: IStandardExchangeBufferPoolTestView(bufferPool).ttaIndex(),
            router: address(0),
            userData: ""
        });
    }

    /// @notice onBeforeSwap must return false (not revert) when called by an address that is
    ///         not the registered Balancer V3 Vault.
    function test_preSeat_rejectsWrongCaller() public {
        vm.prank(address(0xDEAD));
        bool ok = IHooks(bufferPool).onBeforeSwap(_sharesInParams(), bufferPool);
        assertFalse(ok, "onBeforeSwap must return false for non-Vault caller");
    }
}

/// @dev Thin view shim so we can call ttaIndex()/sharesIndex() without a full import.
interface IStandardExchangeBufferPoolTestView {
    function ttaIndex() external view returns (uint256);
    function sharesIndex() external view returns (uint256);
}
