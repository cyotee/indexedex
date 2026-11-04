// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PairTokenTestBase} from "./harness/PairTokenTestBase.sol";
import {
    ScriptedERC20, ScriptedPoolManager, TraceRecorder
} from "./harness/ScriptedDependencies.sol";
import {PairToken} from "../../../../contracts/pairtoken-baseline/PairToken.sol";
import {
    PoolKey, ModifyLiquidityParams, SwapParams
} from "../../../../contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol";

contract EntryRefundReceiver {
    event RefundObserved(uint256 value, uint256 recipientShares);

    PairToken internal immutable pair;
    address internal immutable recipient;
    bool public reject;
    uint256 public calls;
    uint256 public received;
    uint256 public sharesAtRefund;
    uint256 public nativeBasketAtRefund;

    constructor(PairToken instance, address to) {
        pair = instance;
        recipient = to;
    }

    function setReject(bool value) external { reject = value; }

    receive() external payable {
        require(!reject, "refund rejected");
        ++calls;
        received += msg.value;
        sharesAtRefund = pair.balanceOf(recipient);
        (nativeBasketAtRefund,) = pair.basket();
        emit RefundObserved(msg.value, sharesAtRefund);
    }
}

contract PairTokenEntryTest is PairTokenTestBase {
    address internal constant RECIPIENT = address(0xBEEF);
    bytes32 internal constant DEPOSIT = keccak256("Deposit(address,address,uint256,uint256,uint256)");
    bytes32 internal constant TRANSFER = keccak256("Transfer(address,address,uint256)");
    bytes internal PANIC_ARITHMETIC = abi.encodeWithSignature("Panic(uint256)", 0x11);

    // All shares are obtained through a real public deposit. Subsequent exact basket
    // fixtures are dependency state, not PairToken storage or production-math oracles.
    // A scripted successful add need not change the manager's configured position.
    function _established(uint256 idle0, uint256 idle1) internal {
        _bootstrap(10000);
        _position(0);
        manager.setUpdatePosition(false);
        manager.setActiveLiquidity(pair.poolId(), 0);
        _idle(idle0, idle1);
        trace.clear();
    }

    function _quote(uint256 a0, uint256 a1, uint256 shares, uint256 used0, uint256 used1) internal view {
        (uint256 actual, uint256 actual0, uint256 actual1) = pair.previewDeposit(a0, a1);
        assertEq(actual, shares);
        assertEq(actual0, used0);
        assertEq(actual1, used1);
    }

    function _depositEvent(
        Vm.Log[] memory logs, address sender, address to, uint256 amount0, uint256 amount1, uint256 shares
    ) internal view {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(pair) || logs[i].topics[0] != DEPOSIT) continue;
            ++found;
            assertEq(logs[i].topics.length, 3);
            assertEq(logs[i].topics[1], bytes32(uint256(uint160(sender))));
            assertEq(logs[i].topics[2], bytes32(uint256(uint160(to))));
            assertEq(logs[i].data, abi.encode(amount0, amount1, shares));
            assertEq(i, logs.length - 1, "Deposit follows all refund and mint effects");
        }
        assertEq(found, 1);
    }

    function _mintEvent(Vm.Log memory entry, address to, uint256 amount) internal view {
        assertEq(entry.emitter, address(pair));
        assertEq(entry.topics.length, 3);
        assertEq(entry.topics[0], TRANSFER);
        assertEq(entry.topics[1], bytes32(0));
        assertEq(entry.topics[2], bytes32(uint256(uint160(to))));
        assertEq(entry.data, abi.encode(amount));
    }

    function _state() internal view returns (bytes32) {
        bytes32 shares = keccak256(abi.encode(
            pair.totalSupply(), pair.balanceOf(address(this)), pair.balanceOf(RECIPIENT),
            pair.balanceOf(pair.DEAD()), pair.allowance(address(this), RECIPIENT)
        ));
        bytes32 token0 = keccak256(abi.encode(
            currency0.balanceOf(address(this)), currency0.balanceOf(address(pair)),
            currency0.balanceOf(address(manager)), currency0.allowance(address(this), address(pair)),
            currency0.allowance(address(pair), address(feeManager))
        ));
        bytes32 token1 = keccak256(abi.encode(
            currency1.balanceOf(address(this)), currency1.balanceOf(address(pair)),
            currency1.balanceOf(address(manager)), currency1.allowance(address(this), address(pair)),
            currency1.allowance(address(pair), address(feeManager))
        ));
        bytes32 nativeBalances = keccak256(abi.encode(
            address(this).balance, address(pair).balance, address(manager).balance, address(feeManager).balance
        ));
        bytes32 dependencies = keccak256(abi.encode(
            pair.positionLiquidity(), manager.modifyCursor(), manager.swapCursor(), trace.length(),
            feeManager.notifications(), manager.words(manager.base(pair.poolId()))
        ));
        return keccak256(abi.encode(shares, token0, token1, nativeBalances, dependencies));
    }

    function _finiteAllowances() internal {
        currency0.approve(address(pair), 1000000);
        currency1.approve(address(pair), 1000000);
        pair.approve(RECIPIENT, 77);
        trace.clear();
    }

    function _revertDeposit(uint256 a0, uint256 a1, uint256 minimum, bytes memory reason) internal {
        bytes32 beforeState = _state();
        vm.expectRevert(reason);
        pair.deposit(a0, a1, minimum, RECIPIENT);
        assertEq(_state(), beforeState, "deposit rollback");
    }

    function _revertZap(uint256 amount, uint256 minimum, bytes memory reason) internal {
        bytes32 beforeState = _state();
        vm.expectRevert(reason);
        pair.zapDeposit(key.currency0, amount, minimum, RECIPIENT);
        assertEq(_state(), beforeState, "zap rollback");
    }

    function _successfulZap(uint256 amount, uint256 minimum, uint256 used0, uint256 used1, uint256 shares)
        internal
    {
        uint256 supply = pair.totalSupply();
        uint256 deadBalance = pair.balanceOf(pair.DEAD());
        vm.recordLogs();
        assertEq(pair.zapDeposit(key.currency0, amount, minimum, RECIPIENT), shares);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _mintEvent(logs[logs.length - 2], RECIPIENT, shares);
        _depositEvent(logs, address(this), RECIPIENT, used0, used1, shares);
        assertEq(pair.totalSupply(), supply + shares);
        assertEq(pair.balanceOf(RECIPIENT), shares);
        assertEq(pair.balanceOf(pair.DEAD()), deadBalance, "zap has no dead mint");
    }

    function _arguments(bytes memory data) internal pure returns (bytes memory result) {
        result = new bytes(data.length - 4);
        for (uint256 j; j < result.length; ++j) result[j] = data[j + 4];
    }

    function _swapRequest(uint256 index) internal view returns (PoolKey memory storedKey, SwapParams memory params) {
        uint256 seen;
        for (uint256 i; i < trace.length(); ++i) {
            TraceRecorder.Entry memory entry = trace.entryAt(i);
            if (entry.kind != bytes32("swap")) continue;
            if (seen++ == index) {
                bytes memory hookData;
                (storedKey, params, hookData) = abi.decode(_arguments(entry.data), (PoolKey, SwapParams, bytes));
                assertEq(hookData.length, 0);
                return (storedKey, params);
            }
        }
        revert("missing swap");
    }

    // PT-AC-08: the minimum applies to gross shares, not recipient shares.
    function test_PT_AC_08() public {
        _quote(2000, 2000, 2000, 2000, 2000);
        vm.recordLogs();
        assertEq(pair.deposit(2000, 2000, 2000, RECIPIENT), 1000);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 3);
        _mintEvent(logs[0], pair.DEAD(), 1000);
        _mintEvent(logs[1], RECIPIENT, 1000);
        _depositEvent(logs, address(this), RECIPIENT, 2000, 2000, 1000);
        assertEq(pair.totalSupply(), 2000);
        assertEq(pair.balanceOf(RECIPIENT), 1000);
        assertEq(pair.balanceOf(pair.DEAD()), 1000);
        assertGt(pair.positionLiquidity(), 0);
    }

    function test_PT_AC_08_minimum_above_gross() public {
        _finiteAllowances();
        _revertDeposit(2000, 2000, 2001, abi.encodeWithSignature("MinShares()"));
        assertEq(trace.count("transferFrom"), 0);
    }

    function test_PT_AC_09() public {
        vm.expectRevert(abi.encodeWithSignature("BadGenesis()"));
        pair.previewDeposit(1000, 1000);
        vm.expectRevert(abi.encodeWithSignature("BadGenesis()"));
        pair.previewDeposit(999, 1000);
        _revertDeposit(1000, 1000, type(uint256).max, abi.encodeWithSignature("BadGenesis()"));
    }

    function test_PT_AC_09_zero_fundable_addition() public {
        currency0.setTransferFromMode(ScriptedERC20.ReturnMode.NoMovement);
        manager.setSlot0(pair.poolId(), 4295128739, -887272);
        _finiteAllowances();
        _revertDeposit(2000, 2000, 0, abi.encodeWithSignature("BadGenesis()"));
    }

    function test_PT_AC_09_just_above_boundary() public {
        _quote(1001, 1001, 1001, 1001, 1001);
        assertEq(pair.deposit(1001, 1001, 1001, RECIPIENT), 1);
        assertEq(pair.balanceOf(pair.DEAD()), 1000);
        assertEq(pair.balanceOf(RECIPIENT), 1);
    }

    function test_PT_AC_10() public {
        _established(0, 0);
        _quote(9, 16, 12, 9, 16);
        vm.recordLogs();
        assertEq(pair.deposit(9, 16, 12, RECIPIENT), 12);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _mintEvent(logs[0], RECIPIENT, 12);
        _depositEvent(logs, address(this), RECIPIENT, 9, 16, 12);
        assertEq(pair.balanceOf(pair.DEAD()), 1000);
        assertEq(pair.totalSupply(), 10012);
    }

    function test_PT_AC_10_zero_quote() public {
        _established(0, 0);
        _finiteAllowances();
        _quote(0, 16, 0, 0, 16);
        _revertDeposit(0, 16, 0, abi.encodeWithSignature("MinShares()"));
    }

    function test_PT_AC_11() public {
        _established(0, 5000);
        _quote(100, 250, 500, 0, 250);
        uint256 before0 = currency0.balanceOf(address(this));
        assertEq(pair.deposit(100, 250, 500, RECIPIENT), 500);
        assertEq(currency0.balanceOf(address(this)), before0);
        assertEq(trace.count("transferFrom"), 1);
        assertEq(pair.balanceOf(RECIPIENT), 500);
    }

    function test_PT_AC_11_other_empty_reserve() public {
        _established(5000, 0);
        _quote(250, 0, 500, 250, 0);
        uint256 before1 = currency1.balanceOf(address(this));
        assertEq(pair.deposit(250, 0, 500, RECIPIENT), 500);
        assertEq(currency1.balanceOf(address(this)), before1);
        assertEq(trace.count("transferFrom"), 1);
    }

    function test_PT_AC_12() public {
        _established(3000, 7000);
        _quote(100, 500, 333, 100, 234);
        uint256 before0 = currency0.balanceOf(address(this));
        uint256 before1 = currency1.balanceOf(address(this));
        vm.recordLogs();
        assertEq(pair.deposit(100, 500, 333, RECIPIENT), 333);
        _depositEvent(vm.getRecordedLogs(), address(this), RECIPIENT, 100, 234, 333);
        assertEq(before0 - currency0.balanceOf(address(this)), 100);
        assertEq(before1 - currency1.balanceOf(address(this)), 234);
    }

    function test_PT_AC_13() public {
        _established(1000, 1000);
        currency0.setTransferFromMode(ScriptedERC20.ReturnMode.FeeOnTransfer);
        currency0.setFeeBps(1000);
        vm.recordLogs();
        assertEq(pair.deposit(100, 100, 1000, RECIPIENT), 1000);
        _depositEvent(vm.getRecordedLogs(), address(this), RECIPIENT, 90, 100, 1000);
        assertEq(currency0.balanceOf(address(pair)), 1090);
        assertEq(pair.balanceOf(RECIPIENT), 1000);
    }

    function test_PT_AC_13_downstream_failure() public {
        _established(1000, 1000);
        currency0.setTransferFromMode(ScriptedERC20.ReturnMode.FeeOnTransfer);
        _finiteAllowances();
        manager.setFailure(ScriptedPoolManager.modifyLiquidity.selector, true);
        _revertDeposit(100, 100, 1000, abi.encodeWithSelector(
            ScriptedPoolManager.ManagerFailure.selector, ScriptedPoolManager.modifyLiquidity.selector
        ));
    }

    function _nativeSender(bool reject) internal returns (EntryRefundReceiver sender) {
        _deploy(true);
        _established(1000, 1000);
        sender = new EntryRefundReceiver(pair, RECIPIENT);
        sender.setReject(reject);
        vm.deal(address(sender), 10000);
        currency1.mint(address(sender), 10000);
        vm.prank(address(sender));
        currency1.approve(address(pair), 10000);
        trace.clear();
    }

    function _nativeRefund() internal {
        EntryRefundReceiver sender = _nativeSender(false);
        uint256 callerBefore = address(sender).balance;
        uint256 recipientBefore = RECIPIENT.balance;
        // 1000 old native and token1 are at DUST: the reserved incoming 500
        // must not trigger a compound Deploy or enter the quote's basket.
        vm.recordLogs();
        vm.prank(address(sender));
        assertEq(pair.deposit{value: 500}(500, 100, 1000, RECIPIENT), 1000);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(trace.count("unlock"), 1, "only paired Add, no reserved-principal Deploy");
        assertEq(sender.calls(), 1);
        assertEq(sender.received(), 400);
        assertEq(sender.sharesAtRefund(), 1000, "mint precedes refund");
        assertEq(sender.nativeBasketAtRefund(), 1100, "reservation cleared before refund callback");
        assertEq(callerBefore - address(sender).balance, 100);
        assertEq(RECIPIENT.balance, recipientBefore);
        assertEq(address(pair).balance, 1100);
        assertEq(logs.length, 3);
        _mintEvent(logs[0], RECIPIENT, 1000);
        assertEq(logs[1].emitter, address(sender));
        assertEq(logs[1].topics[0], keccak256("RefundObserved(uint256,uint256)"));
        assertEq(logs[1].data, abi.encode(uint256(400), uint256(1000)));
        _depositEvent(logs, address(sender), RECIPIENT, 100, 100, 1000);
    }

    function test_PT_AC_14() public { _nativeRefund(); }
    function test_PT_AC_59() public { _nativeRefund(); }
    function test_PT_GAS_forwarding() public { _nativeRefund(); }

    function test_PT_AC_14_refund_failure() public {
        EntryRefundReceiver sender = _nativeSender(true);
        // Collection and deployment before the late refund must also revert.
        _position(100);
        manager.queueModify(_delta(10, 10), 0);
        uint256 callerBalance = address(sender).balance;
        uint256 callerTokens = currency1.balanceOf(address(sender));
        uint256 allowed = currency1.allowance(address(sender), address(pair));
        bytes32 beforeState = _state();
        vm.expectRevert(abi.encodeWithSignature("TransferFailed()"));
        vm.prank(address(sender));
        pair.deposit{value: 500}(500, 100, 0, RECIPIENT);
        assertEq(_state(), beforeState);
        assertEq(address(sender).balance, callerBalance);
        assertEq(currency1.balanceOf(address(sender)), callerTokens);
        assertEq(currency1.allowance(address(sender), address(pair)), allowed);
        assertEq(sender.calls(), 0);
    }

    function test_PT_AC_59_zero_refund_skips_receiver() public {
        EntryRefundReceiver sender = _nativeSender(true);
        vm.recordLogs();
        vm.prank(address(sender));
        assertEq(pair.deposit{value: 100}(100, 100, 1000, RECIPIENT), 1000);
        assertEq(sender.calls(), 0);
        _depositEvent(vm.getRecordedLogs(), address(sender), RECIPIENT, 100, 100, 1000);
    }

    function test_PT_AC_15() public {
        _deploy(true);
        manager.setFailure(ScriptedPoolManager.extsload.selector, true);
        vm.expectRevert(abi.encodeWithSignature("NativeMismatch()"));
        pair.deposit{value: 99}(100, 100, 0, RECIPIENT);
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        pair.deposit{value: 99}(100, 100, 0, address(0));
        assertEq(trace.length(), 0);
    }

    function test_PT_AC_15_nonnative_and_nonpayable_value() public {
        manager.setFailure(ScriptedPoolManager.extsload.selector, true);
        vm.expectRevert(abi.encodeWithSignature("NativeMismatch()"));
        pair.deposit{value: 1}(100, 100, 0, RECIPIENT);
        (bool ok, bytes memory reason) = address(pair).call{value: 1}(abi.encodeWithSignature("compound()"));
        assertFalse(ok);
        assertEq(reason.length, 0, "nonpayable dispatch");
        assertEq(trace.length(), 0);
    }

    function test_PT_AC_16() public {
        _established(1000, 1000);
        // Add settles only 50 of each leg: the remaining pulled tokens stay idle.
        manager.queueModify(_delta(-50, -50), 0);
        assertEq(pair.deposit(100, 100, 1000, RECIPIENT), 1000);
        assertEq(currency0.balanceOf(address(pair)), 1050);
        assertEq(currency1.balanceOf(address(pair)), 1050);
        assertEq(trace.count("transferFrom"), 2);
        assertEq(trace.count("transfer"), 2, "manager payments only");
        for (uint256 i; i < trace.length(); ++i) {
            TraceRecorder.Entry memory entry = trace.entryAt(i);
            if (entry.kind != bytes32("modify")) continue;
            (, ModifyLiquidityParams memory params,) =
                abi.decode(_arguments(entry.data), (PoolKey, ModifyLiquidityParams, bytes));
            assertEq(params.liquidityDelta, 1100, "all held idle funds the requested add");
        }
    }

    function test_PT_AC_16_established_zero_addition() public {
        _established(1000, 0);
        manager.setSlot0(pair.poolId(), 1461446703485210103287273052203988822378723970342, 887272);
        vm.recordLogs();
        assertEq(pair.deposit(100, 0, 1000, RECIPIENT), 1000);
        assertEq(trace.count("unlock"), 0);
        assertEq(currency0.balanceOf(address(pair)), 1100);
        _depositEvent(vm.getRecordedLogs(), address(this), RECIPIENT, 100, 0, 1000);
    }

    function test_PT_AC_17() public {
        _finiteAllowances();
        _revertZap(100, 0, abi.encodeWithSignature("BadGenesis()"));
    }

    function test_PT_AC_17_missing_reserve() public {
        _established(1000, 0);
        _finiteAllowances();
        _revertZap(100, 0, abi.encodeWithSignature("BadGenesis()"));
    }

    function test_PT_AC_17_other_missing_reserve() public {
        _established(0, 1000);
        _revertZap(100, 0, abi.encodeWithSignature("BadGenesis()"));
    }

    function test_PT_AC_17_compound_precedes_genesis_check() public {
        _idle(2000, 2000);
        manager.setFailure(ScriptedPoolManager.unlock.selector, true);
        _revertZap(100, 0, abi.encodeWithSelector(
            ScriptedPoolManager.ManagerFailure.selector, ScriptedPoolManager.unlock.selector
        ));
    }

    function test_PT_AC_18() public {
        _established(100000, 100000);
        factory.configure(address(feeManager), 0, 100, 100);
        _finiteAllowances();
        _revertZap(1001, 0, abi.encodeWithSignature("ZapTooLarge()"));
        _revertZap(0, 0, abi.encodeWithSignature("ZapTooLarge()"));
    }

    function test_PT_AC_18_cap_equality() public {
        _established(100000, 100000);
        factory.configure(address(feeManager), 0, 100, 100);
        // The automatic compound has its own add before the user-zap add.
        manager.queueModify(0, 0);
        manager.queueModify(_delta(-1000, -1000), 0);
        _successfulZap(1000, 100, 1000, 1000, 100);
        assertEq(trace.count("swap"), 1);
    }

    function test_PT_AC_18_zero_short_circuits_cap_getter() public {
        _established(1000, 1000);
        factory.setFailure(bytes4(keccak256("maxZapBps()")), true);
        _revertZap(0, 0, abi.encodeWithSignature("ZapTooLarge()"));
    }

    function test_PT_AC_19() public {
        _established(1000, 1000);
        currency0.setTransferFromMode(ScriptedERC20.ReturnMode.FeeOnTransfer);
        currency0.setFeeBps(10);
        manager.queueSwap(_delta(-499, 499), Q96, 0);
        manager.queueModify(_delta(-400, -450), 0);
        _successfulZap(1000, 4000, 400, 450, 4000);
        (, SwapParams memory params) = _swapRequest(0);
        assertTrue(params.zeroForOne);
        assertEq(params.amountSpecified, -499);
        assertEq(params.sqrtPriceLimitX96, 4295128740);
        assertEq(currency0.balanceOf(address(pair)), 1100);
        assertEq(currency1.balanceOf(address(pair)), 1049);
        assertEq(pair.balanceOf(pair.DEAD()), 1000);
    }

    function test_PT_AC_19_minimum_rolls_back() public {
        _established(1000, 1000);
        _finiteAllowances();
        currency0.setTransferFromMode(ScriptedERC20.ReturnMode.FeeOnTransfer);
        currency0.setFeeBps(10);
        manager.queueSwap(_delta(-499, 499), Q96, 0);
        manager.queueModify(_delta(-400, -450), 0);
        _revertZap(1000, 4001, abi.encodeWithSignature("MinShares()"));
    }

    function _tickFixture(int24 limit, int24 beforeTick, int24 afterTick) internal {
        _established(1000, 1000);
        _finiteAllowances();
        factory.configure(address(feeManager), 0, 10000, limit);
        manager.setSlot0(pair.poolId(), Q96, beforeTick);
        manager.queueSwap(_delta(-50, 50), Q96, afterTick);
        manager.queueModify(_delta(-100, -100), 0);
    }

    function test_PT_AC_20() public {
        _tickFixture(10, 0, 10);
        _successfulZap(100, 1000, 100, 100, 1000);
    }

    function test_PT_AC_20_above_limit_rolls_back() public {
        _tickFixture(10, 0, 11);
        _revertZap(100, 0, abi.encodeWithSignature("ZapMovesPrice()"));
    }

    function test_PT_AC_20_negative_limit_rolls_back() public {
        _tickFixture(-1, 0, 0);
        _revertZap(100, 0, abi.encodeWithSignature("ZapMovesPrice()"));
    }

    function test_PT_AC_20_negative_tick_direction() public {
        _tickFixture(10, 0, -10);
        _successfulZap(100, 1000, 100, 100, 1000);
    }

    function test_PT_AC_20_checked_signed_tick_subtraction() public {
        _tickFixture(type(int24).max, type(int24).min, type(int24).max);
        _revertZap(100, 0, PANIC_ARITHMETIC);
    }

    function test_PT_AC_21() public {
        _established(1000, 1000);
        // Only 100 new units arrive, but Deploy uses 800 of collective token0
        // and 700 of collective token1. min(800*10,700*10) = 7000.
        manager.queueSwap(_delta(-50, 50), Q96, 0);
        manager.queueModify(_delta(-800, -700), 0);
        _successfulZap(100, 7000, 800, 700, 7000);
        assertEq(currency0.balanceOf(address(pair)), 250);
        assertEq(currency1.balanceOf(address(pair)), 350);
    }

    function test_PT_AC_22() public {
        vm.expectRevert(PANIC_ARITHMETIC);
        pair.previewDeposit(uint256(1) << 128, uint256(1) << 128);
        _finiteAllowances();
        _revertDeposit(uint256(1) << 128, uint256(1) << 128, 0, PANIC_ARITHMETIC);
    }

    function test_PT_AC_60() public {
        _established(1000, 1000);
        currency0.setTransferFromMode(ScriptedERC20.ReturnMode.NoMovement);
        vm.recordLogs();
        assertEq(pair.deposit(100, 100, 1000, RECIPIENT), 1000);
        _depositEvent(vm.getRecordedLogs(), address(this), RECIPIENT, 0, 100, 1000);
        assertEq(currency0.balanceOf(address(pair)), 1000);
        assertEq(currency1.balanceOf(address(pair)), 1100);
    }

    function test_PT_AC_61() public {
        _established(1000, 1000);
        _position(100);
        manager.queueModify(_delta(10, 10), 0);
        currency0.setTransferFromMode(ScriptedERC20.ReturnMode.BalanceDecrease);
        _finiteAllowances();
        _revertDeposit(100, 100, 0, PANIC_ARITHMETIC);
    }

    function test_PT_AC_63() public {
        _established(1000, 1000);
        _position(100);
        // Compound collects, then deploys with zero caller deltas. The zap
        // swap exhausts token1, so its in-range Fit is zero and no add occurs.
        manager.queueModify(_delta(10, 10), 0);
        manager.queueModify(0, 0);
        manager.queueSwap(_delta(-50, -1010), Q96, 0);
        _finiteAllowances();
        _revertZap(100, 0, abi.encodeWithSignature("MinShares()"));
        assertEq(pair.balanceOf(pair.DEAD()), 1000);
    }

    function test_PT_ZAP_equal_currencies() public {
        // Initialization is intentionally permissive. Both idle reads observe
        // the same token, but input matching must still choose currency0.
        key.currency1 = key.currency0;
        pair = new PairToken();
        factory.initialize(address(pair), address(manager), key);
        manager.configurePool(pair.poolId(), Q96, 0);
        currency0.approve(address(pair), type(uint256).max);
        _bootstrap(10000);
        _position(0);
        manager.setUpdatePosition(false);
        manager.setActiveLiquidity(pair.poolId(), 0);
        currency0.setBalance(address(pair), 1000);
        manager.queueSwap(0, Q96, 0);
        manager.queueModify(_delta(-100, -100), 0);
        _successfulZap(100, 1000, 100, 100, 1000);
        (PoolKey memory passedKey, SwapParams memory params) = _swapRequest(0);
        assertEq(passedKey.currency0, passedKey.currency1);
        assertTrue(params.zeroForOne);
        assertEq(params.amountSpecified, -50);
    }
}
