// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {PairTokenTestBase} from "./harness/PairTokenTestBase.sol";
import {
    TraceRecorder, ScriptedERC20, ScriptedFeeManager, ScriptedFactory, ScriptedPoolManager
} from "./harness/ScriptedDependencies.sol";
import {
    PoolKey, ModifyLiquidityParams, SwapParams, IPoolManager
} from "../../../../contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol";

contract PairTokenCallbacksTest is PairTokenTestBase {
    bytes32 internal constant COMPOUNDED = keccak256("Compounded(uint256,uint256,uint256,uint256,uint128)");
    bytes4 internal constant NOT_MANAGER = bytes4(keccak256("NotPoolManager()"));
    bytes4 internal constant REENTRANCY = bytes4(keccak256("Reentrancy()"));

    struct CompoundEvent {
        uint256 fees0;
        uint256 fees1;
        uint256 protocol0;
        uint256 protocol1;
        uint128 added;
    }
    struct DeployResult {
        uint256 used0;
        uint256 used1;
        uint256 output;
        int24 beforeTick;
        int24 afterTick;
        uint128 added;
    }

    function _event(Vm.Log[] memory logs) internal view returns (CompoundEvent memory result, uint256 count) {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(pair) && logs[i].topics[0] == COMPOUNDED) {
                assertEq(logs[i].topics.length, 1);
                result = abi.decode(logs[i].data, (CompoundEvent));
                ++count;
            }
        }
    }

    function _staticCount(Vm.AccountAccess[] memory calls, address target, bytes4 selector)
        internal pure returns (uint256 count)
    {
        for (uint256 i; i < calls.length; ++i) {
            if (calls[i].kind == VmSafe.AccountAccessKind.StaticCall && calls[i].account == target
                && calls[i].data.length >= 4 && bytes4(calls[i].data) == selector) ++count;
        }
    }

    function _modify(uint256 occurrence) internal view returns (ModifyLiquidityParams memory params) {
        uint256 seen;
        for (uint256 i; i < trace.length(); ++i) {
            TraceRecorder.Entry memory entry = trace.entryAt(i);
            if (entry.kind == "modify" && seen++ == occurrence) {
                bytes memory arguments = _arguments(entry.data);
                PoolKey memory requested;
                bytes memory hookData;
                (requested, params, hookData) = abi.decode(arguments, (PoolKey, ModifyLiquidityParams, bytes));
                assertEq(abi.encode(requested), abi.encode(key));
                assertEq(params.tickLower, pair.tickLower());
                assertEq(params.tickUpper, pair.tickUpper());
                assertEq(params.salt, bytes32(0));
                assertEq(hookData.length, 0);
                return params;
            }
        }
        revert("missing modification");
    }

    function _swap() internal view returns (SwapParams memory params) {
        for (uint256 i; i < trace.length(); ++i) {
            TraceRecorder.Entry memory entry = trace.entryAt(i);
            if (entry.kind == "swap") {
                PoolKey memory requested;
                bytes memory hookData;
                (requested, params, hookData) = abi.decode(_arguments(entry.data), (PoolKey, SwapParams, bytes));
                assertEq(abi.encode(requested), abi.encode(key));
                assertEq(hookData.length, 0);
                return params;
            }
        }
        revert("missing swap");
    }

    function _arguments(bytes memory data) internal pure returns (bytes memory result) {
        result = new bytes(data.length - 4);
        for (uint256 i; i < result.length; ++i) result[i] = data[i + 4];
    }

    function _collect(int128 caller0, int128 caller1, int128 fees0, int128 fees1) internal {
        _position(1);
        manager.queueModify(_delta(caller0, caller1), _delta(fees0, fees1));
    }

    function _assertNoShares() internal view {
        assertEq(pair.totalSupply(), 0);
        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.balanceOf(pair.DEAD()), 0);
    }

    function _assertUnlockOperations(uint8 finalOperation) internal view {
        uint256 count;
        for (uint256 i; i < trace.length(); ++i) {
            TraceRecorder.Entry memory entry = trace.entryAt(i);
            if (entry.kind != "unlock") continue;
            bytes memory raw = abi.decode(_arguments(entry.data), (bytes));
            (uint8 operation,) = abi.decode(raw, (uint8, bytes));
            assertEq(operation, count == 0 ? 3 : count == 1 ? 4 : finalOperation);
            ++count;
        }
        assertEq(count, 3);
    }

    function test_PT_AC_34_zeroPositionCanDeployWithoutMint() public {
        _idle(2000, 2000);
        vm.recordLogs();
        (uint256 fees0, uint256 fees1) = pair.compound();
        assertEq(fees0, 0);
        assertEq(fees1, 0);
        assertEq(trace.count("unlock"), 1);
        assertGt(_modify(0).liquidityDelta, 0);
        (CompoundEvent memory eventData, uint256 count) = _event(vm.getRecordedLogs());
        assertEq(count, 1);
        assertGt(eventData.added, 0);
        _assertNoShares();
    }

    function test_PT_AC_34_positivePositionReportsCallerNotFeeDelta() public {
        _collect(17, 23, 701, 909);
        (uint256 fees0, uint256 fees1) = pair.compound();
        assertEq(fees0, 17);
        assertEq(fees1, 23);
        assertEq(_modify(0).liquidityDelta, 0);
        assertEq(trace.count("unlock"), 1);
        _assertNoShares();
    }

    function test_PT_AC_35_grossCollectionAndProtocolAmounts() public {
        _collect(10000, 5000, 1, 2);
        factory.configure(address(feeManager), 250, 10000, 0);
        vm.recordLogs();
        (uint256 fees0, uint256 fees1) = pair.compound();
        assertEq(fees0, 10000);
        assertEq(fees1, 5000);
        assertEq(currency0.balanceOf(address(feeManager)), 250);
        assertEq(currency1.balanceOf(address(feeManager)), 125);
        (CompoundEvent memory eventData, uint256 count) = _event(vm.getRecordedLogs());
        assertEq(count, 1);
        assertEq(eventData.fees0, 10000);
        assertEq(eventData.fees1, 5000);
        assertEq(eventData.protocol0, 250);
        assertEq(eventData.protocol1, 125);
        assertEq(trace.count("notify"), 2);
        uint256 notifications;
        for (uint256 i; i < trace.length(); ++i) {
            TraceRecorder.Entry memory entry = trace.entryAt(i);
            if (entry.kind != "notify") continue;
            (address token, uint256 amount, bytes32 id) = abi.decode(
                _arguments(entry.data), (address, uint256, bytes32)
            );
            assertEq(token, notifications == 0 ? address(currency0) : address(currency1));
            assertEq(amount, notifications == 0 ? 250 : 125);
            assertEq(id, pair.poolId());
            assertEq(entry.target, address(feeManager));
            assertEq(entry.value, 0);
            ++notifications;
        }
        _assertNoShares();
    }

    function test_PT_AC_36_zeroManagerStillReadsBothRoutingGettersInOrder() public {
        _collect(1, 0, 0, 0);
        factory.configure(address(0), 100, 100, 0);
        vm.startStateDiffRecording();
        pair.compound();
        Vm.AccountAccess[] memory calls = vm.stopAndReturnStateDiff();
        uint256 managerIndex = type(uint256).max;
        uint256 rateIndex = type(uint256).max;
        for (uint256 i; i < calls.length; ++i) {
            if (calls[i].account != address(factory) || calls[i].data.length < 4) continue;
            if (bytes4(calls[i].data) == ScriptedFactory.feeManager.selector) managerIndex = i;
            if (bytes4(calls[i].data) == ScriptedFactory.protocolFeeBps.selector) rateIndex = i;
        }
        assertLt(managerIndex, rateIndex);
        assertLt(rateIndex, calls.length);
        assertEq(trace.count("notify"), 0);
    }

    function test_PT_AC_36_zeroCollectionSkipsRoutingGetters() public {
        _position(1);
        factory.setFailure(ScriptedFactory.feeManager.selector, true);
        factory.setFailure(ScriptedFactory.protocolFeeBps.selector, true);
        vm.startStateDiffRecording();
        pair.compound();
        Vm.AccountAccess[] memory calls = vm.stopAndReturnStateDiff();
        assertEq(_staticCount(calls, address(factory), ScriptedFactory.feeManager.selector), 0);
        assertEq(_staticCount(calls, address(factory), ScriptedFactory.protocolFeeBps.selector), 0);
        assertEq(trace.count("notify"), 0);
    }

    function test_PT_AC_37_successfulNoPullKeepsAllowanceAndReportsAttempt() public {
        _collect(100, 0, 0, 0);
        factory.configure(address(feeManager), 250, 0, 0);
        feeManager.setMode(ScriptedFeeManager.Mode.NoPull);
        vm.recordLogs();
        pair.compound();
        (CompoundEvent memory eventData,) = _event(vm.getRecordedLogs());
        assertEq(eventData.protocol0, 2);
        assertEq(currency0.allowance(address(pair), address(feeManager)), 2);
        assertEq(currency0.balanceOf(address(pair)), 100);
        assertEq(currency0.balanceOf(address(feeManager)), 0);
        assertEq(trace.count("approve"), 1);
    }

    function test_PT_AC_38_nativeNotifyCatchesCustomEmptyAndPanic() public {
        for (uint256 mode = 2; mode <= 4; ++mode) {
            _deploy(true);
            _collect(100, 0, 0, 0);
            factory.configure(address(feeManager), 10000, 0, 0);
            feeManager.setMode(ScriptedFeeManager.Mode(mode));
            vm.recordLogs();
            (uint256 fees0,) = pair.compound();
            (CompoundEvent memory eventData,) = _event(vm.getRecordedLogs());
            assertEq(fees0, 100);
            assertEq(eventData.protocol0, 0);
            assertEq(address(pair).balance, 100);
            assertEq(address(feeManager).balance, 0);
            assertEq(feeManager.notifications(), 0);
        }
    }

    function test_PT_AC_38_erc20NotifyFailureCleansAllowance() public {
        for (uint256 mode = 2; mode <= 4; ++mode) {
            _deploy(false);
            _collect(100, 0, 0, 0);
            factory.configure(address(feeManager), 10000, 0, 0);
            feeManager.setMode(ScriptedFeeManager.Mode(mode));
            vm.recordLogs();
            pair.compound();
            (CompoundEvent memory eventData,) = _event(vm.getRecordedLogs());
            assertEq(eventData.protocol0, 0);
            assertEq(currency0.allowance(address(pair), address(feeManager)), 0);
            assertEq(trace.count("approve"), 2);
            assertEq(currency0.balanceOf(address(pair)), 100);
        }
    }

    function test_PT_AC_38_cleanupFalseIgnoredButMalformedAborts() public {
        _collect(100, 0, 0, 0);
        factory.configure(address(feeManager), 10000, 0, 0);
        feeManager.setMode(ScriptedFeeManager.Mode.RevertCustom);
        currency0.setCleanupApproveMode(ScriptedERC20.ReturnMode.False);
        pair.compound();
        assertEq(currency0.balanceOf(address(pair)), 100);
        _deploy(false);
        _collect(100, 0, 0, 0);
        factory.configure(address(feeManager), 10000, 0, 0);
        feeManager.setMode(ScriptedFeeManager.Mode.RevertCustom);
        currency0.setCleanupApproveMode(ScriptedERC20.ReturnMode.Malformed);
        vm.expectRevert(bytes(""));
        pair.compound();
        assertEq(currency0.balanceOf(address(pair)), 0);
        assertEq(currency0.allowance(address(pair), address(feeManager)), 0);
        assertEq(manager.modifyCursor(), 0);
        assertEq(trace.length(), 0);
    }

    function test_PT_AC_39_falseOrRevertingApprovalSkipsNotify() public {
        for (uint256 i; i < 2; ++i) {
            _deploy(false);
            _collect(100, 0, 0, 0);
            factory.configure(address(feeManager), 10000, 0, 0);
            currency0.setApproveMode(i == 0 ? ScriptedERC20.ReturnMode.False : ScriptedERC20.ReturnMode.RevertCall);
            vm.recordLogs();
            pair.compound();
            (CompoundEvent memory eventData,) = _event(vm.getRecordedLogs());
            assertEq(eventData.protocol0, 0);
            assertEq(feeManager.notifications(), 0);
            assertEq(currency0.balanceOf(address(pair)), 100);
        }
    }

    function test_PT_AC_39_malformedApprovalAborts() public {
        _collect(100, 0, 0, 0);
        factory.configure(address(feeManager), 10000, 0, 0);
        currency0.setApproveMode(ScriptedERC20.ReturnMode.Malformed);
        vm.expectRevert(bytes(""));
        pair.compound();
        assertEq(manager.modifyCursor(), 0);
        assertEq(currency0.balanceOf(address(pair)), 0);
        assertEq(feeManager.notifications(), 0);
    }

    function test_PT_AC_39_routingGetterFailuresPropagate() public {
        bytes4[2] memory getters = [ScriptedFactory.feeManager.selector, ScriptedFactory.protocolFeeBps.selector];
        for (uint256 i; i < getters.length; ++i) {
            _deploy(false);
            _collect(100, 0, 0, 0);
            factory.setFailure(getters[i], true);
            vm.expectRevert(abi.encodeWithSelector(ScriptedFactory.FactoryFailure.selector, getters[i]));
            pair.compound();
            assertEq(currency0.balanceOf(address(pair)), 0);
            assertEq(manager.modifyCursor(), 0);
            assertEq(trace.length(), 0);
        }
    }

    function test_PT_AC_40_dustBoundaryIsStrict() public {
        _idle(1000, 1000);
        pair.compound();
        assertEq(trace.count("unlock"), 0);
        _idle(1001, 1000);
        pair.compound();
        assertEq(trace.count("unlock"), 1);
        assertEq(trace.count("swap"), 0);
        assertGt(_modify(0).liquidityDelta, 0);
    }

    function test_PT_AC_41_smallChosenLeftoverStillDeploys() public {
        _idle(2000, 1500);
        factory.setFailure(ScriptedFactory.maxZapBps.selector, true);
        pair.compound();
        assertEq(trace.count("swap"), 0);
        assertEq(trace.count("unlock"), 1);
        assertGt(_modify(0).liquidityDelta, 0);
    }

    function test_PT_AC_41_zeroActiveLiquidityStillDeploys() public {
        _idle(10000, 2000);
        manager.setActiveLiquidity(pair.poolId(), 0);
        factory.setFailure(ScriptedFactory.maxZapBps.selector, true);
        pair.compound();
        assertEq(trace.count("swap"), 0);
        assertEq(trace.count("unlock"), 1);
        assertGt(_modify(0).liquidityDelta, 0);
    }

    function test_PT_AC_42_activeReserveQuarterCapAndNoTickGuard() public {
        _idle(100000, 0);
        // At Q96 the full-range amount0 floor for Lpool=10001 is exactly 10000.
        manager.setActiveLiquidity(pair.poolId(), 10001);
        factory.configure(address(0), 0, 100, -1);
        factory.setFailure(ScriptedFactory.maxZapTickMove.selector, true);
        manager.queueSwap(0, Q96, 500000);
        pair.compound();
        SwapParams memory params = _swap();
        assertTrue(params.zeroForOne);
        assertEq(params.amountSpecified, -25);
        assertEq(params.sqrtPriceLimitX96, 4295128740);
    }

    function test_PT_AC_42_convertedLeftoverTieChoosesToken0() public {
        // Below range, 2000 token0 converts to zero value after both sequential floors.
        // Fit is zero at these full-range bounds. j1 is also zero: the tie must choose token0.
        manager.setSlot0(pair.poolId(), 1, -887272);
        _idle(2000, 0);
        manager.setActiveLiquidity(pair.poolId(), 1);
        factory.configure(address(0), 0, 10000, 0);
        manager.queueSwap(0, 1, -887272);
        pair.compound();
        assertTrue(_swap().zeroForOne);
        assertEq(_swap().amountSpecified, -1000);
    }

    function test_PT_AC_43_swapAloneDoesNotEmitCompounded() public {
        _idle(5000, 0);
        manager.queueSwap(0, Q96, 0);
        vm.recordLogs();
        pair.compound();
        (, uint256 count) = _event(vm.getRecordedLogs());
        assertEq(trace.count("swap"), 1);
        assertEq(trace.count("modify"), 0);
        assertEq(count, 0);
        _assertNoShares();
    }

    function test_PT_AC_44_laterAddFeesDoNotStartSecondProtocolCut() public {
        _collect(100, 0, 0, 0);
        _idle(2000, 2000);
        factory.configure(address(feeManager), 100, 100, 0);
        manager.queueModify(_delta(-7, 5), _delta(11, 2));
        vm.startStateDiffRecording();
        pair.compound();
        Vm.AccountAccess[] memory calls = vm.stopAndReturnStateDiff();
        assertEq(_staticCount(calls, address(factory), ScriptedFactory.protocolFeeBps.selector), 1);
        assertEq(trace.count("notify"), 1);
        assertGt(_modify(1).liquidityDelta, 0);
        assertEq(trace.count("settle"), 1);
        // Direct Add additionally exposes the widened subtraction result, including its zero clamp.
        trace.clear();
        manager.queueModify(_delta(-7, 5), _delta(11, 2));
        (uint256 used0, uint256 used1) = abi.decode(_callback(1, abi.encode(uint128(1))), (uint256, uint256));
        assertEq(used0, 18);
        assertEq(used1, 0);
    }

    function test_PT_AC_44_widensBeforeSubtractingInt128Extremes() public {
        _idle(uint128(type(int128).max), 0);
        manager.queueModify(_delta(-type(int128).max, 0), _delta(type(int128).max, 0));
        (uint256 used0,) = abi.decode(_callback(1, abi.encode(uint128(0))), (uint256, uint256));
        assertEq(used0, uint256(type(uint128).max) - 1);
    }

    function test_PT_AC_45_senderCheckedBeforeDecodeAndNoArmedFlag() public {
        vm.expectRevert(NOT_MANAGER);
        pair.unlockCallback(hex"ff");
        vm.expectRevert(NOT_MANAGER);
        pair.unlockCallback(abi.encode(uint8(1), abi.encode(uint128(0))));
        (uint256 amount0, uint256 amount1) = abi.decode(
            _callback(1, abi.encode(uint128(0))), (uint256, uint256)
        );
        assertEq(amount0, 0);
        assertEq(amount1, 0);
        assertEq(_modify(0).liquidityDelta, 0);
    }

    function test_PT_AC_46_noneAndMalformedOuterInnerEnum() public {
        vm.expectRevert(NOT_MANAGER);
        _callback(0, "");
        vm.expectRevert(bytes(""));
        manager.callback(address(pair), hex"ff");
        vm.expectRevert(bytes(""));
        _callback(5, "");
        vm.expectRevert(bytes(""));
        _callback(1, hex"01");
        vm.expectRevert(bytes(""));
        _callback(2, abi.encode(type(uint256).max));
        vm.expectRevert(bytes(""));
        _callback(4, abi.encode(uint256(2), uint256(0)));
        vm.expectRevert(bytes(""));
        _callback(4, hex"00");
        assertEq(trace.count("modify"), 0);
    }

    function test_PT_AC_46_allValidOperationsAndCollectGarbage() public {
        _position(100);
        _callback(1, abi.encode(uint128(0)));
        assertEq(_modify(0).liquidityDelta, 0);
        _callback(1, abi.encode(uint128(7)));
        assertEq(_modify(1).liquidityDelta, 7);
        manager.queueModify(_delta(3, 4), _delta(99, 88));
        (uint256 amount0, uint256 amount1) = abi.decode(_callback(2, abi.encode(uint128(5))), (uint256, uint256));
        assertEq(amount0, 3);
        assertEq(amount1, 4);
        assertEq(_modify(2).liquidityDelta, -5);
        manager.queueModify(_delta(6, 8), 0);
        (amount0, amount1) = abi.decode(_callback(3, hex"deadbeef"), (uint256, uint256));
        assertEq(amount0, 6);
        assertEq(amount1, 8);
        assertEq(_modify(3).liquidityDelta, 0);
        _idle(0, 0);
        DeployResult memory result = abi.decode(_callback(4, abi.encode(true, uint256(0))), (DeployResult));
        assertEq(result.output, 0);
        assertEq(result.added, 0);
        assertEq(result.beforeTick, 0);
        assertEq(result.afterTick, 0);
        assertEq(trace.count("swap"), 0);
    }

    function test_PT_AC_46_trailingDataAccepted() public {
        bytes memory payload = bytes.concat(abi.encode(uint128(0)), hex"cafe");
        bytes memory raw = bytes.concat(abi.encode(uint8(1), payload), hex"beef");
        bytes memory returned = manager.callback(address(pair), raw);
        assertEq(returned, abi.encode(uint256(0), uint256(0)));
        assertEq(trace.count("modify"), 1);
    }

    function test_PT_AC_46_deployReportsPositiveOutputAndTickCheckpoints() public {
        manager.queueSwap(_delta(0, 9), Q96, 7);
        DeployResult memory result = abi.decode(
            _callback(4, abi.encode(true, uint256(1))), (DeployResult)
        );
        assertEq(result.output, 9);
        assertEq(result.used0, 0);
        assertEq(result.used1, 0);
        assertEq(result.added, 0);
        assertEq(result.beforeTick, 0);
        assertEq(result.afterTick, 7);
        assertEq(trace.count("take"), 1);
        assertEq(currency1.balanceOf(address(pair)), 9);
    }

    function test_PT_AC_47_negativeCallerReinterpretedAfterSettlement() public {
        _idle(1, 0);
        manager.queueModify(_delta(-1, 0), 0);
        (uint256 amount0, uint256 amount1) = abi.decode(_callback(3, ""), (uint256, uint256));
        assertEq(amount0, type(uint128).max);
        assertEq(amount1, 0);
        assertEq(trace.count("sync"), 1);
        assertEq(trace.count("settle"), 1);
        _idle(1, 0);
        manager.queueModify(_delta(-1, 0), 0);
        (amount0,) = abi.decode(_callback(2, abi.encode(uint128(0))), (uint256, uint256));
        assertEq(amount0, type(uint128).max);
    }

    function test_PT_AC_47_int128MinimumNegationPanics() public {
        manager.queueModify(_delta(type(int128).min, 0), 0);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        _callback(3, "");
        assertEq(manager.modifyCursor(), 0);
        assertEq(trace.length(), 0);
    }

    function test_PT_AC_48_nonpositiveOppositeDeltaReportsZeroAndSettles() public {
        for (uint256 direction; direction < 2; ++direction) {
            for (uint256 negative; negative < 2; ++negative) {
                _deploy(false);
                _idle(10, 10);
                bool zeroForOne = direction == 0;
                int128 opposite = negative == 0 ? int128(0) : int128(-3);
                manager.queueSwap(zeroForOne ? _delta(-2, opposite) : _delta(opposite, -2), Q96, 9);
                DeployResult memory result = abi.decode(
                    _callback(4, abi.encode(zeroForOne, uint256(2))), (DeployResult)
                );
                assertEq(result.output, 0);
                assertEq(trace.count("settle"), negative == 0 ? 1 : 2);
                assertEq(result.beforeTick, 0);
                assertEq(result.afterTick, 9);
                assertEq(_swap().sqrtPriceLimitX96, zeroForOne
                    ? 4295128740 : 1461446703485210103287273052203988822378723970341);
            }
        }
    }

    function test_PT_AC_49_erc20NegativeSyncTransferSettleThenPositiveTake() public {
        _idle(7, 0);
        manager.setPaidAmount(999999);
        manager.queueModify(_delta(-7, 9), 0);
        _callback(1, abi.encode(uint128(0)));
        assertEq(trace.length(), 6);
        assertEq(trace.entryAt(0).kind, bytes32("modify"));
        assertEq(trace.entryAt(1).kind, bytes32("sync"));
        assertEq(trace.entryAt(2).kind, bytes32("transfer"));
        assertEq(trace.entryAt(3).kind, bytes32("settle"));
        assertEq(trace.entryAt(4).kind, bytes32("take"));
        assertEq(trace.entryAt(5).kind, bytes32("transfer"));
        assertEq(trace.entryAt(2).target, address(currency0));
        (address recipient, uint256 amount) = abi.decode(_arguments(trace.entryAt(2).data), (address, uint256));
        assertEq(recipient, address(manager));
        assertEq(amount, 7);
        (address currency, address to, uint256 taken) = abi.decode(
            _arguments(trace.entryAt(4).data), (address, address, uint256)
        );
        assertEq(currency, address(currency1));
        assertEq(to, address(pair));
        assertEq(taken, 9);
        assertEq(currency1.balanceOf(address(pair)), 9);
        _modify(0);
    }

    function test_PT_AC_49_nativeNegativeSettlesValueWithoutSyncAndZeroSkips() public {
        _deploy(true);
        _idle(7, 0);
        manager.queueModify(_delta(-7, 0), 0);
        _callback(1, abi.encode(uint128(0)));
        assertEq(trace.length(), 2);
        assertEq(trace.entryAt(0).kind, bytes32("modify"));
        assertEq(trace.entryAt(1).kind, bytes32("settle"));
        assertEq(trace.entryAt(1).value, 7);
        assertEq(trace.count("sync"), 0);
        assertEq(trace.count("take"), 0);
        assertEq(address(pair).balance, 0);
    }

    function test_PT_AC_49_managerFailurePropagatesDistinctiveData() public {
        manager.setFailure(IPoolManager.modifyLiquidity.selector, true);
        vm.expectRevert(abi.encodeWithSelector(
            ScriptedPoolManager.ManagerFailure.selector, IPoolManager.modifyLiquidity.selector
        ));
        _callback(1, abi.encode(uint128(1)));
    }

    function test_PT_AC_50_depositCollectDeployAddSeparateUnlocksBeforeMint() public {
        _bootstrap(10000);
        uint256 supply = pair.totalSupply();
        uint256 firstUnlock = 1; // Bootstrap Add is retained in manager's supply observations.
        pair.deposit(2000, 2000, 0, address(this));
        assertEq(trace.count("unlock"), 3);
        _assertUnlockOperations(1);
        assertEq(_modify(0).liquidityDelta, 0);
        assertGt(_modify(1).liquidityDelta, 0);
        assertGt(_modify(2).liquidityDelta, 0);
        for (uint256 i; i < 3; ++i) assertEq(manager.unlockSupply(firstUnlock + i), supply);
        for (uint256 i; i < trace.length(); ++i) {
            TraceRecorder.Entry memory entry = trace.entryAt(i);
            if (entry.kind == "transferFrom") assertEq(entry.depth, 0);
            if (entry.kind == "modify") assertEq(entry.depth, 1);
        }
        assertGt(pair.totalSupply(), supply);
    }

    function test_PT_AC_50_redeemCollectDeployRemoveBurnBeforeLastUnlock() public {
        _bootstrap(10000);
        uint256 supply = pair.totalSupply();
        pair.redeem(1000, 0, 0, address(this));
        assertEq(trace.count("unlock"), 3);
        _assertUnlockOperations(2);
        assertEq(_modify(0).liquidityDelta, 0);
        assertGt(_modify(1).liquidityDelta, 0);
        assertLt(_modify(2).liquidityDelta, 0);
        assertEq(manager.unlockSupply(1), supply);
        assertEq(manager.unlockSupply(2), supply);
        assertEq(manager.unlockSupply(3), supply - 1000);
        assertEq(pair.totalSupply(), supply - 1000);
        for (uint256 i; i < trace.length(); ++i) {
            TraceRecorder.Entry memory entry = trace.entryAt(i);
            if (entry.kind == "transfer" && entry.target == address(currency0)
                && entry.caller == address(pair)) assertEq(entry.depth, 0);
        }
    }

    function test_PT_AC_51_allGuardedMethodsRejectBeforeBodyChecks() public {
        _bootstrap(10000);
        _idle(0, 0);
        bytes[] memory attempts = new bytes[](5);
        attempts[0] = abi.encodeWithSignature("deposit(uint256,uint256,uint256,address)", 0, 0, 0, address(0));
        attempts[1] = abi.encodeWithSignature("zapDeposit(address,uint256,uint256,address)", address(9), 0, 0, address(0));
        attempts[2] = abi.encodeWithSignature("redeem(uint256,uint256,uint256,address)", 0, 0, 0, address(0));
        attempts[3] = abi.encodeWithSignature("redeemZap(uint256,address,uint256,address)", 0, address(9), 0, address(0));
        attempts[4] = abi.encodeWithSignature("compound()");
        for (uint256 i; i < attempts.length; ++i) {
            manager.setDuringUnlock(address(pair), attempts[i]);
            pair.compound();
            assertFalse(manager.duringUnlockSuccess());
            assertEq(manager.duringUnlockResult(), abi.encodeWithSelector(REENTRANCY));
        }
    }

    function test_PT_AC_51_shareTransferAndApprovalRemainUnguarded() public {
        _bootstrap(10000);
        _idle(0, 0);
        pair.transfer(address(manager), 5);
        manager.setDuringUnlock(address(pair), abi.encodeWithSignature("transfer(address,uint256)", address(0xBEEF), 3));
        pair.compound();
        assertTrue(manager.duringUnlockSuccess());
        assertEq(pair.balanceOf(address(0xBEEF)), 3);
        assertEq(pair.balanceOf(address(manager)), 2);
        manager.setDuringUnlock(address(pair), abi.encodeWithSignature("approve(address,uint256)", address(0xBEEF), 7));
        pair.compound();
        assertTrue(manager.duringUnlockSuccess());
        assertEq(pair.allowance(address(manager), address(0xBEEF)), 7);
    }

    function test_PT_AC_66_zeroPositionDeployAdditionEventAndNoRoutingReads() public {
        _idle(2000, 2000);
        factory.setFailure(ScriptedFactory.feeManager.selector, true);
        factory.setFailure(ScriptedFactory.protocolFeeBps.selector, true);
        vm.startStateDiffRecording();
        vm.recordLogs();
        (uint256 fees0, uint256 fees1) = pair.compound();
        Vm.AccountAccess[] memory calls = vm.stopAndReturnStateDiff();
        (CompoundEvent memory eventData, uint256 count) = _event(vm.getRecordedLogs());
        assertEq(fees0, 0);
        assertEq(fees1, 0);
        assertEq(count, 1);
        assertEq(eventData.fees0, 0);
        assertEq(eventData.fees1, 0);
        assertEq(eventData.protocol0, 0);
        assertEq(eventData.protocol1, 0);
        assertEq(uint256(eventData.added), uint256(_modify(0).liquidityDelta));
        assertGt(eventData.added, 0);
        assertEq(trace.count("unlock"), 1);
        assertEq(_staticCount(calls, address(factory), ScriptedFactory.feeManager.selector), 0);
        assertEq(_staticCount(calls, address(factory), ScriptedFactory.protocolFeeBps.selector), 0);
        _assertNoShares();
    }

    function test_PT_AC_67_zeroPositionZeroAdditionStillDeploysNoEvent() public {
        _idle(2000, 0);
        manager.setActiveLiquidity(pair.poolId(), 0);
        vm.recordLogs();
        (uint256 fees0, uint256 fees1) = pair.compound();
        (, uint256 count) = _event(vm.getRecordedLogs());
        assertEq(fees0, 0);
        assertEq(fees1, 0);
        assertEq(trace.count("unlock"), 1);
        assertEq(trace.count("modify"), 0);
        assertEq(count, 0);
        _assertNoShares();
    }

    function test_PT_AC_68_uncappedNativeProtocolSpendsReservationThenRollsBack() public {
        _deploy(true);
        _bootstrap(2000);
        _idle(0, 0);
        factory.configure(address(feeManager), 20000, 0, 0);
        _collect(100, 0, 0, 0);
        uint256 supply = pair.totalSupply();
        uint256 shares = pair.balanceOf(address(this));
        uint256 payerBalance = address(this).balance;
        uint256 managerBalance = address(manager).balance;
        uint256 tokenBalance = currency1.balanceOf(address(this));
        uint256 allowanceBefore = currency1.allowance(address(this), address(pair));
        vm.expectCall(address(feeManager), 200, abi.encodeWithSelector(
            ScriptedFeeManager.notify.selector, address(0), uint256(200), pair.poolId()
        ));
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        pair.deposit{value: 100}(100, 100, 0, address(this));
        assertEq(address(pair).balance, 0);
        assertEq(address(feeManager).balance, 0);
        assertEq(address(manager).balance, managerBalance);
        assertEq(address(this).balance, payerBalance);
        assertEq(currency1.balanceOf(address(this)), tokenBalance);
        assertEq(currency1.balanceOf(address(pair)), 0);
        assertEq(currency1.allowance(address(this), address(pair)), allowanceBefore);
        assertEq(pair.totalSupply(), supply);
        assertEq(pair.balanceOf(address(this)), shares);
        assertEq(feeManager.notifications(), 0);
        assertEq(manager.modifyCursor(), 0);
        assertEq(trace.length(), 0);
        // A succeeding later guarded call demonstrates that the reverted entered flag did not persist.
        factory.configure(address(feeManager), 0, 0, 0);
        pair.compound();
    }
}
