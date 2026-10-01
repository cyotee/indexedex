// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4FullSpreadPonsFamilyHookCoreSettlementTest} from "./CoreSettlement.t.sol";
import {TestBase_FullSpreadMaintenanceObservation} from "contracts/test/bases/TestBase_FullSpreadMaintenanceObservation.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {PonsV2MemeHook} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadPonsFamilyHookTransitionPlanner as Planner} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol";
import {UniswapV4FullSpreadPonsFamilyHookQuoteService as Quotes} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookQuoteService.sol";

/// @notice Real registered Pons hook costs included in independently observed terminal maintenance.
// tag::PonsFamilyMaintenanceObservedProgressTest[]
contract PonsFamilyMaintenanceObservedProgressTest is UniswapV4FullSpreadPonsFamilyHookCoreSettlementTest, TestBase_FullSpreadMaintenanceObservation {
    using PoolIdLibrary for PoolKey;
    using BalanceDeltaLibrary for BalanceDelta;

    struct FeeMark { uint256[2] fee; uint256[2] tax; uint256[2] custody; uint256[2] protocol; }

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
        return Planner._maintenance(state, Quotes.Params(manager, key, state.position, true, 0, address(weth)));
    }
    function _observedHasLpFee() internal pure override returns (bool) { return false; }

    function _feeMark() private view returns (FeeMark memory mark) {
        address[2] memory currencies = [Currency.unwrap(key.currency0), Currency.unwrap(key.currency1)];
        for (uint256 i; i < 2; ++i) {
            mark.fee[i] = ponsHook.pendingFees(key.toId(), currencies[i]);
            mark.tax[i] = ponsHook.pendingCreatorTax(key.toId(), currencies[i]);
            mark.custody[i] = IERC20(currencies[i]).balanceOf(address(ponsHook));
            mark.protocol[i] = manager.protocolFeesAccrued(Currency.wrap(currencies[i]));
        }
    }
    function _observedFeeMark() internal view override returns (bytes memory) { return abi.encode(_feeMark()); }

    function _registeredTerms() private view returns (PonsV2MemeHook.LaunchInfo memory terms) {
        (bool ok, bytes memory data) = address(ponsHook).staticcall(abi.encodeWithSelector(ponsHook.launches.selector, key.toId()));
        assertTrue(ok);
        terms = abi.decode(data, (PonsV2MemeHook.LaunchInfo));
        assertTrue(terms.registered); assertFalse(terms.buybackEnabled);
    }

    function _observedCheckFees(bytes memory raw, Types.Swap memory swap, BalanceDelta actual) internal view override {
        FeeMark memory beforeFees = abi.decode(raw, (FeeMark));
        FeeMark memory afterFees = _feeMark();
        PonsV2MemeHook.LaunchInfo memory terms = _registeredTerms();
        uint256 output = swap.zeroForOne ? 1 : 0;
        uint256 fee = afterFees.fee[output] - beforeFees.fee[output];
        uint256 tax = afterFees.tax[output] - beforeFees.tax[output];
        int128 received = output == 0 ? actual.amount0() : actual.amount1();
        assertGe(int256(received), 0);
        uint256 gross = uint256(int256(received)) + fee + tax;
        assertEq(fee, gross * terms.hookFeeBps / 10_000, "independent hook floor");
        assertEq(tax, gross * terms.creatorTaxBps / 10_000, "independent creator floor");
        assertEq(afterFees.custody[output] - beforeFees.custody[output], fee + tax);
        assertEq(afterFees.fee[1-output], beforeFees.fee[1-output]);
        assertEq(afterFees.tax[1-output], beforeFees.tax[1-output]);
        assertEq(afterFees.custody[1-output], beforeFees.custody[1-output]);
        assertEq(afterFees.protocol[output], beforeFees.protocol[output]);
        assertGe(afterFees.protocol[1-output], beforeFees.protocol[1-output]);
    }

    /// @notice Pons output charges and directional core protocol fees coexist without own LP fee recovery.
    function test_observedMaintenance_ponsDirectionalProtocolCosts() public {
        manager.setProtocolFeeController(address(this));
        manager.setProtocolFee(key, uint24(500 | (1_000 << 12)));
        for (uint256 direction; direction < 2; ++direction) {
            uint256 root = vm.snapshotState();
            _prepareObserved(direction, 10e18);
            FeeMark memory beforeHook = _feeMark();
            uint256 beforeFees = manager.protocolFeesAccrued(direction == 0 ? key.currency0 : key.currency1);
            Outcome memory result = _runObserved();
            assertGt(result.plan.swap.amountIn, 0);
            assertEq(result.plan.swap.zeroForOne, direction == 0);
            assertEq(result.plan.swap.steps, 1, "single-step protocol-floor control");
            uint256 accrued = manager.protocolFeesAccrued(direction == 0 ? key.currency0 : key.currency1) - beforeFees;
            // At tick 120 / spacing 60 the first word targets are 0 and 15300.
            // This control consumes one full exact-input step strictly before its target.
            if (direction == 0) assertGt(result.actual.price, TickMath.getSqrtPriceAtTick(0));
            else assertLt(result.actual.price, TickMath.getSqrtPriceAtTick(15_300));
            uint256 gross = result.plan.swap.amountIn;
            uint256 pips = direction == 0 ? 500 : 1_000;
            // Pool.sol assigns the entire fee to protocol when LP fee is zero.
            // SwapMath first floors the input after fees, then charges the remainder.
            assertEq(accrued, gross - gross * (1_000_000 - pips) / 1_000_000);
            assertGt(accrued, 0);
            FeeMark memory afterHook = _feeMark();
            uint256 output = 1 - direction;
            assertGt(afterHook.fee[output] - beforeHook.fee[output], 0, "nonzero hook-charge witness");
            assertGt(afterHook.tax[output] - beforeHook.tax[output], 0, "nonzero creator-charge witness");
            assertTrue(vm.revertToStateAndDelete(root));
        }
    }
}
// end::PonsFamilyMaintenanceObservedProgressTest[]
