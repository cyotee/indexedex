// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {HooklessCoreSettlementTest} from "./CoreSettlement.t.sol";
import {TestBase_FullSpreadMaintenanceObservation} from "contracts/test/bases/TestBase_FullSpreadMaintenanceObservation.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner as Planner} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService as Quotes} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol";

/// @notice H planner selected actions versus independently executed/observed no-trade counterfactuals.
// tag::HooklessMaintenanceObservedProgressTest[]
contract HooklessMaintenanceObservedProgressTest is HooklessCoreSettlementTest, TestBase_FullSpreadMaintenanceObservation {
    using PoolIdLibrary for PoolKey;

    function _observedManager() internal view override returns (IPoolManager) { return manager; }
    function _observedKey() internal view override returns (PoolKey memory) { return key; }
    function _observedTicks() internal view override returns (int24, int24) { return (lower, upper); }
    function _observedModify(int256 delta, bytes32 salt) internal override returns (BalanceDelta, BalanceDelta) {
        return _modifyWithFees(delta, salt);
    }
    function _observedSwap(bool direction, uint256 amount) internal override returns (BalanceDelta) {
        return _swap(direction, -int256(amount));
    }
    function _observedPlan(Types.Snapshot memory state) internal view override returns (Types.Plan memory) {
        return Planner._maintenance(state, Quotes.Params(manager, key, state.position, true, 0, address(0)));
    }
    function _observedFeeMark() internal view override returns (bytes memory) {
        return abi.encode(manager.protocolFeesAccrued(key.currency0), manager.protocolFeesAccrued(key.currency1));
    }
    function _observedCheckFees(bytes memory mark, Types.Swap memory swap, BalanceDelta) internal view override {
        (uint256 p0, uint256 p1) = abi.decode(mark, (uint256, uint256));
        assertGe(manager.protocolFeesAccrued(key.currency0), p0);
        assertGe(manager.protocolFeesAccrued(key.currency1), p1);
        if (swap.zeroForOne) assertEq(manager.protocolFeesAccrued(key.currency1), p1);
        else assertEq(manager.protocolFeesAccrued(key.currency0), p0);
    }

    /// @notice Nonzero directional protocol fees remain costs in the observed terminal book.
    function test_observedMaintenance_hooklessDirectionalProtocolCosts() public {
        manager.setProtocolFeeController(address(this));
        manager.setProtocolFee(key, uint24(500 | (1_000 << 12)));
        for (uint256 direction; direction < 2; ++direction) {
            uint256 root = vm.snapshotState();
            _prepareObserved(direction, 10e18);
            uint256 beforeFees = manager.protocolFeesAccrued(direction == 0 ? key.currency0 : key.currency1);
            Outcome memory result = _runObserved();
            assertGt(result.plan.swap.amountIn, 0);
            assertEq(result.plan.swap.zeroForOne, direction == 0);
            assertEq(result.plan.swap.steps, 1, "single-step protocol-floor control");
            uint256 accrued = manager.protocolFeesAccrued(direction == 0 ? key.currency0 : key.currency1) - beforeFees;
            assertEq(accrued, result.plan.swap.amountIn * (direction == 0 ? 500 : 1_000) / 1_000_000);
            assertGt(accrued, 0);
            assertTrue(vm.revertToStateAndDelete(root));
        }
    }
}
// end::HooklessMaintenanceObservedProgressTest[]
