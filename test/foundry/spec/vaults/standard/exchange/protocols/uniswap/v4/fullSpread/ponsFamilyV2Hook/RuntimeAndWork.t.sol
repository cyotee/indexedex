// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Vm} from "forge-std/Vm.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {UniswapV4FullSpreadPonsFamilyHookCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";
import {UniswapV4FullSpreadPonsFamilyHookTransitionPlanner as Planner} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol";
import {UniswapV4FullSpreadPonsFamilyHookQuoteService as Quotes} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookQuoteService.sol";
import {IUniswapV4FullSpreadPonsFamilyHookInExecutionBinding as InBinding, IUniswapV4FullSpreadPonsFamilyHookOutExecutionBinding as OutBinding} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookComponentBindings.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookRuntimeAndWorkTest[]
contract UniswapV4FullSpreadPonsFamilyHookRuntimeAndWorkTest is Acceptance {
    using PoolIdLibrary for *;
    uint256 internal constant OPERATION_GAS_BUDGET = 28_000_000;

    function test_repairGasBothDirectionsRealisticAndExtreme() public {
        _bootstrap();
        uint256[3] memory sizes = [uint256(10), uint256(1_000), uint256(1_000_000)];
        for (uint256 i; i < sizes.length; ++i) {
            for (uint256 direction; direction < 2; ++direction) {
                uint256 snapshot = vm.snapshotState();
                (direction == 0 ? token0 : token1).transfer(address(vault), sizes[i] * 1e18);
                (uint160 beforePrice,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
                vm.recordLogs();
                uint256 gasBefore = gasleft();
                Reserve(address(vault)).rebalanceLiquidReserve{gas: OPERATION_GAS_BUDGET}();
                uint256 used = gasBefore - gasleft();
                _assertBudget(used);
                _assertOneRepairSwap();
                (uint160 afterPrice,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
                if (direction == 0) assertLt(afterPrice, beforePrice); else assertGt(afterPrice, beforePrice);
                emit log_named_uint("repair donation units", sizes[i]);
                emit log_named_uint("repair direction", direction);
                _assertBooked();
                assertTrue(vm.revertToStateAndDelete(snapshot));
            }
        }
    }

    function test_automaticMaintenanceGasBothDirectionsAndMoneyPaths() public {
        _bootstrap();
        for (uint256 route; route < 3; ++route) {
            for (uint256 direction; direction < 2; ++direction) {
                uint256 snapshot = vm.snapshotState();
                (direction == 0 ? token0 : token1).transfer(address(vault), 10e18);
                _automaticOperation(route, direction);
                _assertOneRepairSwap();
                _assertBooked();
                assertTrue(vm.revertToStateAndDelete(snapshot));
            }
        }
    }

    function _automaticOperation(uint256 route_, uint256 direction_) private {
        IERC20 input = direction_ == 0 ? token0 : token1;
        IERC20 output = direction_ == 0 ? token1 : token0;
        uint256 expected;
        uint256 result;
        uint256 gasBefore;
        if (route_ == 2) {
            uint256[] memory amounts = _amounts(1e18, 1e18);
            address[] memory tokens = _tokens();
            expected = IStandardExchangeInMulti(address(vault)).previewExchangeInManyToOne(tokens, amounts, IERC20(address(vault)));
            vm.recordLogs();
            gasBefore = gasleft();
            result = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne{gas: OPERATION_GAS_BUDGET}(
                tokens, amounts, IERC20(address(vault)), expected, address(this), false, block.timestamp);
        } else {
            if (route_ == 1) { input = IERC20(address(vault)); output = direction_ == 0 ? token0 : token1; }
            expected = vault.previewExchangeIn(input, 1e18, output);
            vm.recordLogs();
            gasBefore = gasleft();
            result = vault.exchangeIn{gas: OPERATION_GAS_BUDGET}(input, 1e18, output, expected, address(this), false, block.timestamp);
        }
        _assertBudget(gasBefore - gasleft());
        assertEq(result, expected);
        emit log_named_uint("automatic maintenance route", route_);
        emit log_named_uint("automatic maintenance direction", direction_);
    }

    function _assertBudget(uint256 used_) private {
        emit log_named_uint("operation gas", used_);
        assertLt(used_, OPERATION_GAS_BUDGET, "retain 4M execution headroom below 32M");
    }

    function _assertOneRepairSwap() private {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 swaps;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(vault) && logs[i].topics.length != 0
                && logs[i].topics[0] == Common.MaintenanceEvaluated.selector) {
                (, uint256 input,,) = abi.decode(logs[i].data, (uint8, uint256, int128, int128));
                if (input != 0) ++swaps;
            }
        }
        assertEq(swaps, 1, "a single real holder swap must execute, not a disabled repair");
    }

    function test_referenceCandidateSelectionAndWorkUnchanged() public {
        _bootstrap();
        for (uint256 direction; direction < 2; ++direction) {
            for (uint256 extreme; extreme < 2; ++extreme) {
                uint256 snapshot = vm.snapshotState();
                (direction == 0 ? token0 : token1).transfer(address(vault), extreme == 0 ? 10e18 : 1_000_000e18);
                Types.Snapshot memory state = _plannerState();
                Quotes.Params memory params = Quotes.Params(poolManager, poolKey, state.position, true, 0, address(weth));
                Types.Plan memory referencePlan = _referenceMaintenance(state, params);
                Types.Plan memory actual = Planner._maintenance(state, params);
                assertEq(keccak256(abi.encode(actual)), keccak256(abi.encode(referencePlan)), "complete selected plan and work counters");
                assertLe(actual.refinements, 64);
                assertLe(actual.evaluations, 72);
                assertTrue(vm.revertToStateAndDelete(snapshot));
            }
        }
    }

    function _plannerState() private view returns (Types.Snapshot memory state_) {
        (bytes memory raw,) = Transition(address(vault)).quoteState(address(token0), address(0));
        Common.InventoryQuote memory q = abi.decode(raw, (Common.InventoryQuote));
        state_.idle = q.idle; state_.sleeveWad = q.sleeveWad; state_.absoluteFloor = q.absoluteFloor;
        state_.book.free = [q.free0, q.free1]; state_.book.earned = [q.fees0, q.fees1]; state_.book.supply = q.supply;
        state_.position = Types.PositionState(q.pool.sqrtPriceX96, TickMath.getSqrtPriceAtTick(q.lower),
            TickMath.getSqrtPriceAtTick(q.upper), q.pool.tick, q.lower, q.upper, q.positionLiquidity,
            q.pool.liquidity, q.liquidityDelta, q.lowerLiquidityGross, q.upperLiquidityGross, q.maxLiquidityPerTick);
        state_.book.deployed = Inventory._amounts(state_.position, q.positionLiquidity, false);
    }

    // Frozen pre-optimization P selection loop. It calls the P fee/quote model,
    // not a Hookless dispatcher or an economic mock.
    function _referenceMaintenance(Types.Snapshot memory original_, Quotes.Params memory params_)
        private view returns (Types.Plan memory best_)
    {
        Types.Snapshot memory state = abi.decode(abi.encode(original_), (Types.Snapshot));
        Inventory._collect(state.book);
        best_.workflow = Types.Workflow.Maintenance;
        best_.placement = _referencePlacement(state);
        best_.valid = true;
        best_.maintenance = best_.placement.liquidityDelta == 0 ? Types.MaintenanceStatus.Unchanged : Types.MaintenanceStatus.Placed;
        if (best_.placement.certified) return best_;
        Types.Snapshot memory baseline = best_.placement.afterState;
        for (uint256 direction; direction < 2; ++direction) {
            params_.zeroForOne = direction == 0;
            for (uint256 funding; funding < 2; ++funding) {
                if (funding == 1 && state.position.liquidity == 0) continue;
                Types.Placement memory removal = Inventory._placement(state, funding == 0 ? state.position.liquidity : 0);
                if (!removal.funded) continue;
                uint256 high = removal.afterState.book.free[direction];
                uint256 low;
                for (uint32 probe; probe < 16 && low < high; ++probe) {
                    uint256 amount = probe == 0 ? high : low + (high - low) / 2;
                    (Types.Plan memory candidate, int256 sign) = _referenceTrial(removal, original_.position.sqrtPriceX96, params_, amount);
                    ++best_.evaluations;
                    if (probe != 0) ++best_.refinements;
                    best_ = _referenceSelect(best_, candidate, baseline);
                    if (sign > 0) low = amount + 1; else high = amount == 0 ? 0 : amount - 1;
                    if (candidate.valid && candidate.placement.certified) break;
                }
                for (uint256 endpoint; endpoint < 2; ++endpoint) {
                    (Types.Plan memory candidate,) = _referenceTrial(removal, original_.position.sqrtPriceX96, params_, endpoint == 0 ? low : high);
                    ++best_.evaluations;
                    best_ = _referenceSelect(best_, candidate, baseline);
                }
            }
        }
        if (best_.swap.amountIn == 0 && !best_.placement.certified) best_.maintenance = Types.MaintenanceStatus.Deferred;
    }

    function _referenceTrial(Types.Placement memory removal_, uint160 price_, Quotes.Params memory params_, uint256 amount_)
        private view returns (Types.Plan memory plan_, int256 sign_)
    {
        Types.Snapshot memory state = abi.decode(abi.encode(removal_.afterState), (Types.Snapshot));
        plan_.workflow = Types.Workflow.Maintenance; plan_.fundingRemoval = removal_;
        uint256 input = params_.zeroForOne ? 0 : 1;
        if (amount_ > state.book.free[input]) return (plan_, -1);
        params_.position = state.position; params_.amount = amount_;
        bool filled;
        (plan_.swap, filled) = Quotes._tryForward(params_);
        if (!filled || !Protection._priceWithin(price_, plan_.swap.sqrtPriceAfterX96, 25)) return (plan_, -1);
        state.book.free[input] -= plan_.swap.amountIn; state.book.free[1 - input] += plan_.swap.amountOut;
        Planner._afterSwap(state, plan_.swap);
        plan_.placement = _referencePlacement(state);
        sign_ = Inventory._compositionSign(plan_.placement.afterState);
        if (!params_.zeroForOne) sign_ = -sign_;
        plan_.valid = true; plan_.maintenance = Types.MaintenanceStatus.Improved;
    }

    function _referenceSelect(Types.Plan memory best_, Types.Plan memory candidate_, Types.Snapshot memory baseline_)
        private pure returns (Types.Plan memory)
    {
        if (!candidate_.valid || Inventory._compareProgress(candidate_.placement.afterState, baseline_) >= 0) return best_;
        int256 comparison = Inventory._compareProgress(candidate_.placement.afterState, best_.placement.afterState);
        bool wins = comparison < 0;
        if (comparison == 0) wins = candidate_.swap.amountIn < best_.swap.amountIn
            || (candidate_.swap.amountIn == best_.swap.amountIn && _turnover(candidate_) < _turnover(best_));
        if (!wins) return best_;
        candidate_.evaluations = best_.evaluations; candidate_.refinements = best_.refinements;
        return candidate_;
    }

    function _turnover(Types.Plan memory plan_) private pure returns (uint256) {
        int256 a = plan_.fundingRemoval.liquidityDelta; int256 b = plan_.placement.liquidityDelta;
        return uint256(a < 0 ? -a : a) + uint256(b < 0 ? -b : b);
    }

    function _referencePlacement(Types.Snapshot memory state_) private pure returns (Types.Placement memory best_) {
        best_ = Inventory._placement(state_, state_.position.liquidity);
        (bool fits, uint128 target) = Inventory._tryTargetLiquidity(state_);
        if (!fits) return best_;
        for (uint256 i; i < (target > state_.position.liquidity ? 2 : 1); ++i) {
            Types.Placement memory candidate = Inventory._placement(state_, target - uint128(i));
            if (!candidate.funded) continue;
            int256 comparison = Inventory._compareProgress(candidate.afterState, best_.afterState);
            int256 a = candidate.liquidityDelta; int256 b = best_.liquidityDelta;
            if (comparison < 0 || (comparison == 0 && (a < 0 ? -a : a) < (b < 0 ? -b : b))) best_ = candidate;
        }
    }
    function test_allDeployedFacetsDelegatesAndPackageFitEIP170() public {
        IDiamond.FacetCut[] memory cuts = uniswapV4StandardExchangeDFPkg.facetCuts();
        for (uint256 i; i < cuts.length; ++i) {
            emit log_named_uint(IFacet(cuts[i].facetAddress).facetName(), cuts[i].facetAddress.code.length);
            assertGt(cuts[i].facetAddress.code.length, 0);
            assertLe(cuts[i].facetAddress.code.length, 24_576);
        }
        address inDelegate = InBinding(address(vault)).UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE();
        address outDelegate = OutBinding(address(vault)).UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE();
        emit log_named_uint("InExecutionDelegate", inDelegate.code.length);
        emit log_named_uint("OutExecutionDelegate", outDelegate.code.length);
        emit log_named_uint("DFPkg", address(uniswapV4StandardExchangeDFPkg).code.length);
        assertGt(inDelegate.code.length, 0); assertGt(outDelegate.code.length, 0);
        assertLe(inDelegate.code.length, 24_576); assertLe(outDelegate.code.length, 24_576);
        assertLe(address(uniswapV4StandardExchangeDFPkg).code.length, 24_576);
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookRuntimeAndWorkTest[]

contract UniswapV4FullSpreadPonsFamilyHookHighFeeRuntimeAndWorkTest is UniswapV4FullSpreadPonsFamilyHookRuntimeAndWorkTest {
    function _creatorTaxBps() internal pure override returns (uint16) { return 1_900; }
}

contract UniswapV4FullSpreadPonsFamilyHookTightTickRuntimeAndWorkTest is UniswapV4FullSpreadPonsFamilyHookRuntimeAndWorkTest {
    function _tickSpacing() internal pure override returns (int24) { return 1; }
}

contract UniswapV4FullSpreadPonsFamilyHookHighFeeTightTickRuntimeAndWorkTest is UniswapV4FullSpreadPonsFamilyHookHighFeeRuntimeAndWorkTest {
    function _tickSpacing() internal pure override returns (int24) { return 1; }
}
