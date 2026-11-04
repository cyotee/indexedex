// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {PairTokenTestBase} from "./harness/PairTokenTestBase.sol";
import {
    TraceRecorder, ScriptedERC20, ScriptedFactory, ScriptedFeeManager, NativeRecipient
} from "./harness/ScriptedDependencies.sol";
import {PairToken} from "../../../../contracts/pairtoken-baseline/PairToken.sol";
import {
    PoolKey, ModifyLiquidityParams, SwapParams, IPoolManager
} from "../../../../contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol";

contract PairTokenExitTest is PairTokenTestBase {
    address internal constant RECIPIENT = address(0xCAFE);
    address internal constant SPENDER = address(0xBEEF);
    bytes32 internal constant TRANSFER = keccak256("Transfer(address,address,uint256)");
    bytes32 internal constant DEPOSIT = keccak256("Deposit(address,address,uint256,uint256,uint256)");
    bytes32 internal constant REDEEM = keccak256("Redeem(address,address,uint256,uint256,uint256)");
    bytes32 internal constant COMPOUNDED = keccak256("Compounded(uint256,uint256,uint256,uint256,uint128)");
    bytes4 internal constant TOKEN_TRANSFER = bytes4(keccak256("transfer(address,uint256)"));

    event PayoutObserved(uint256 supply, uint256 holderBalance);

    function payoutMarker() external {
        emit PayoutObserved(pair.totalSupply(), pair.balanceOf(address(this)));
    }

    function _funded(bool native0) internal {
        _deploy(native0);
        assertEq(_bootstrap(10000), 9000);
        _position(50000);
        _idle(101, 99);
        pair.approve(SPENDER, 777);
        trace.clear();
    }

    function _collectAndRemove(int128 amount0, int128 amount1) internal {
        manager.queueModify(0, 0);
        manager.queueModify(_delta(amount0, amount1), 0);
    }

    function _tail(bytes memory data) internal pure returns (bytes memory result) {
        result = new bytes(data.length - 4);
        for (uint256 i; i < result.length; ++i) result[i] = data[i + 4];
    }

    function _entry(bytes32 kind, uint256 occurrence) internal view returns (TraceRecorder.Entry memory) {
        for (uint256 i; i < trace.length(); ++i) {
            TraceRecorder.Entry memory item = trace.entryAt(i);
            if (item.kind == kind) {
                if (occurrence == 0) return item;
                --occurrence;
            }
        }
        revert("missing dependency call");
    }

    function _assertModification(uint256 occurrence, int256 amount) internal view {
        TraceRecorder.Entry memory item = _entry("modify", occurrence);
        (PoolKey memory observed, ModifyLiquidityParams memory params, bytes memory hookData) =
            abi.decode(_tail(item.data), (PoolKey, ModifyLiquidityParams, bytes));
        assertEq(item.target, address(manager));
        assertEq(item.caller, address(pair));
        assertEq(item.depth, 1);
        assertEq(abi.encode(observed), abi.encode(key));
        assertEq(params.tickLower, pair.tickLower());
        assertEq(params.tickUpper, pair.tickUpper());
        assertEq(params.salt, bytes32(0));
        assertEq(params.liquidityDelta, amount);
        assertEq(hookData, "");
    }

    function _assertSwap(bool zeroForOne, uint256 amount) internal view {
        TraceRecorder.Entry memory item = _entry("swap", 0);
        (PoolKey memory observed, SwapParams memory params, bytes memory hookData) =
            abi.decode(_tail(item.data), (PoolKey, SwapParams, bytes));
        assertEq(abi.encode(observed), abi.encode(key));
        assertEq(params.zeroForOne, zeroForOne);
        assertEq(params.amountSpecified, -int256(amount));
        assertEq(
            params.sqrtPriceLimitX96,
            zeroForOne ? uint160(4295128740) : uint160(1461446703485210103287273052203988822378723970341)
        );
        assertEq(hookData, "");
        assertEq(item.depth, 1);
    }

    function _instanceLogs(Vm.Log[] memory all) internal view returns (Vm.Log[] memory result) {
        uint256 count;
        for (uint256 i; i < all.length; ++i) if (all[i].emitter == address(pair)) ++count;
        result = new Vm.Log[](count);
        uint256 next;
        for (uint256 i; i < all.length; ++i) {
            if (all[i].emitter == address(pair)) result[next++] = all[i];
        }
    }

    function _assertTransfer(Vm.Log memory item, address from, address to, uint256 value) internal view {
        assertEq(item.emitter, address(pair));
        assertEq(item.topics.length, 3);
        assertEq(item.topics[0], TRANSFER);
        assertEq(item.topics[1], bytes32(uint256(uint160(from))));
        assertEq(item.topics[2], bytes32(uint256(uint160(to))));
        assertEq(item.data, abi.encode(value));
    }

    function _assertFlow(
        Vm.Log memory item, bytes32 signature, address sender, address to,
        uint256 amount0, uint256 amount1, uint256 shares
    ) internal view {
        assertEq(item.emitter, address(pair));
        assertEq(item.topics.length, 3);
        assertEq(item.topics[0], signature);
        assertEq(item.topics[1], bytes32(uint256(uint160(sender))));
        assertEq(item.topics[2], bytes32(uint256(uint160(to))));
        assertEq(item.data, abi.encode(amount0, amount1, shares));
    }

    /// @dev Covers all actors affected by these scripts, including finite underlying
    /// allowances, protocol allowances, native funds and manager script/storage state.
    function _state(address recipient) internal view returns (bytes32 digest) {
        address[6] memory actors =
            [address(this), address(pair), address(manager), address(feeManager), recipient, RECIPIENT];
        digest = keccak256(abi.encode(
            pair.totalSupply(), pair.allowance(address(this), SPENDER),
            manager.modifyCursor(), manager.swapCursor(), feeManager.notifications(),
            trace.length(), trace.depth(), pair.balanceOf(pair.DEAD())
        ));
        for (uint256 i; i < actors.length; ++i) {
            address actor = actors[i];
            digest = keccak256(abi.encode(
                digest, actor.balance, pair.balanceOf(actor),
                currency0.balanceOf(actor), currency1.balanceOf(actor),
                currency0.allowance(actor, address(pair)), currency1.allowance(actor, address(pair)),
                currency0.allowance(actor, address(feeManager)), currency1.allowance(actor, address(feeManager))
            ));
        }
        digest = keccak256(abi.encode(
            digest, manager.words(manager.base(pair.poolId())),
            manager.words(manager.positionSlot(pair.poolId(), address(pair), pair.tickLower(), pair.tickUpper())),
            manager.words(bytes32(uint256(manager.base(pair.poolId())) + 3))
        ));
    }

    function _fails(bytes memory callData, bytes memory expected, address recipient) internal {
        bytes32 beforeState = _state(recipient);
        vm.startStateDiffRecording();
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(pair).call(callData);
        Vm.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();
        Vm.Log[] memory attemptedLogs = vm.getRecordedLogs();
        assertFalse(ok);
        assertEq(reason, expected);
        _assertRevertedFrame(accesses, attemptedLogs);
        assertEq(_state(recipient), beforeState, "uncaught failure must restore every affected actor");
    }

    function _assertRevertedFrame(Vm.AccountAccess[] memory accesses, Vm.Log[] memory attemptedLogs) internal view {
        bool instanceReverted;
        for (uint256 i; i < accesses.length; ++i) {
            if (accesses[i].account == address(pair) && accesses[i].kind == VmSafe.AccountAccessKind.Call) {
                assertTrue(accesses[i].reverted);
                instanceReverted = true;
            }
            for (uint256 j; j < accesses[i].storageAccesses.length; ++j) {
                if (accesses[i].storageAccesses[j].isWrite) {
                    assertTrue(accesses[i].storageAccesses[j].reverted, "dependency write escaped rollback");
                }
            }
        }
        assertTrue(instanceReverted, "instance frame, including its logs, must revert");
        // recordLogs is a debug recorder, not a transaction receipt. It can
        // expose attempted logs from a reverted frame. The reverted account
        // context above establishes their discard; neither success log is reached.
        for (uint256 i; i < attemptedLogs.length; ++i) {
            if (attemptedLogs[i].emitter == address(pair)) {
                assertTrue(attemptedLogs[i].topics[0] != REDEEM);
                assertTrue(attemptedLogs[i].topics[0] != DEPOSIT);
            }
        }
    }

    function _wrapped(address target, bytes4 selector, bytes memory reason, string memory context)
        internal pure returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "WrappedError(address,bytes4,bytes,bytes)",
            target, selector, reason, abi.encodePacked(bytes4(keccak256(bytes(context))))
        );
    }

    function test_PT_AC_23() public {
        _funded(false);
        _collectAndRemove(70, 80);
        vm.recordLogs();
        (uint256 amount0, uint256 amount1) = pair.redeem(1000, 80, 89, RECIPIENT);
        assertEq(amount0, 80);
        assertEq(amount1, 89);
        assertEq(pair.totalSupply(), 9000);
        assertEq(pair.balanceOf(address(this)), 8000);
        assertEq(pair.allowance(address(this), SPENDER), 777);
        assertEq(pair.positionLiquidity(), 45005);
        assertEq(currency0.balanceOf(RECIPIENT), 80);
        assertEq(currency1.balanceOf(RECIPIENT), 89);
        assertEq(currency0.balanceOf(address(pair)), 91);
        assertEq(currency1.balanceOf(address(pair)), 90);
        assertEq(trace.count("unlock"), 2);
        assertEq(trace.count("modify"), 2);
        _assertModification(0, 0);
        _assertModification(1, -4995);
        Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
        assertEq(logs.length, 2);
        _assertTransfer(logs[0], address(this), address(0), 1000);
        _assertFlow(logs[1], REDEEM, address(this), RECIPIENT, 80, 89, 1000);
    }

    function _zeroExit(bool zap, bool choose0) internal {
        _funded(false);
        manager.queueModify(0, 0);
        vm.recordLogs();
        if (zap) {
            assertEq(pair.redeemZap(1, choose0 ? address(currency0) : address(currency1), 0, RECIPIENT), 0);
        } else {
            (uint256 amount0, uint256 amount1) = pair.redeem(1, 0, 0, RECIPIENT);
            assertEq(amount0, 0);
            assertEq(amount1, 0);
        }
        assertEq(pair.totalSupply(), 9999);
        assertEq(pair.balanceOf(address(this)), 8999);
        assertEq(pair.positionLiquidity(), 50000);
        assertEq(trace.count("modify"), 1, "collect only, never remove a zero slice");
        assertEq(trace.count("swap"), 0);
        assertEq(trace.count("transfer"), zap ? 1 : 0);
        if (zap) {
            TraceRecorder.Entry memory payout = _entry("transfer", 0);
            assertEq(payout.target, choose0 ? address(currency0) : address(currency1));
            assertEq(payout.caller, address(pair));
            assertEq(payout.depth, 0);
            assertEq(payout.data, abi.encodeWithSelector(TOKEN_TRANSFER, RECIPIENT, 0));
        }
        Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
        assertEq(logs.length, 2);
        _assertTransfer(logs[0], address(this), address(0), 1);
        _assertFlow(logs[1], REDEEM, address(this), RECIPIENT, 0, 0, 1);
    }

    function test_PT_AC_24() public {
        _zeroExit(false, false);
        _zeroExit(true, true);
        _zeroExit(true, false);
    }

    function test_PT_AC_25() public {
        for (uint256 scenario; scenario < 4; ++scenario) {
            _funded(false);
            // Collection is a real earlier state change, but stays below the Deploy threshold.
            manager.queueModify(_delta(100, 100), 0);
            bytes memory data;
            if (scenario < 2) {
                data = abi.encodeCall(pair.redeem, (1, scenario == 0 ? 1 : 0, scenario == 1 ? 1 : 0, RECIPIENT));
            } else {
                data = abi.encodeCall(pair.redeemZap, (1, scenario == 2 ? address(currency0) : address(currency1), 1, RECIPIENT));
            }
            _fails(data, abi.encodeWithSignature("MinOut()"), RECIPIENT);
        }
    }

    function test_PT_AC_26() public {
        for (uint256 route; route < 2; ++route) {
            _funded(false);
            pair.approve(SPENDER, 1000);
            manager.queueModify(_delta(100, 100), 0);
            bytes32 beforeState = _state(SPENDER);
            vm.prank(SPENDER);
            (bool ok, bytes memory reason) = address(pair).call(
                route == 0
                    ? abi.encodeCall(pair.redeem, (1000, 0, 0, RECIPIENT))
                    : abi.encodeCall(pair.redeemZap, (1000, address(currency0), 0, RECIPIENT))
            );
            assertFalse(ok);
            assertEq(reason, abi.encodeWithSignature("Panic(uint256)", 0x11));
            assertEq(_state(SPENDER), beforeState);
            assertEq(pair.allowance(address(this), SPENDER), 1000);
            assertEq(pair.balanceOf(SPENDER), 0);
            assertEq(pair.balanceOf(address(this)), 9000);
        }
    }

    function _partialExit(bool choose0) internal returns (uint256 output) {
        _funded(false);
        _collectAndRemove(70, 80);
        manager.queueSwap(choose0 ? _delta(20, -30) : _delta(-30, 20), Q96, 50000);
        // These getters would fail if redemption acquired a zap-entry cap/tick guard.
        factory.setFailure(ScriptedFactory.maxZapBps.selector, true);
        factory.setFailure(ScriptedFactory.maxZapTickMove.selector, true);
        // Two operation idle samples plus the one explicit postcondition below.
        // Any skip-add balanceOf call introduces an unexpected fourth call.
        vm.expectCall(address(currency0), abi.encodeWithSelector(ScriptedERC20.balanceOf.selector, address(pair)), uint64(3));
        vm.expectCall(address(currency1), abi.encodeWithSelector(ScriptedERC20.balanceOf.selector, address(pair)), uint64(3));
        vm.recordLogs();
        output = pair.redeemZap(1000, choose0 ? address(currency0) : address(currency1), choose0 ? 100 : 109, RECIPIENT);
        assertEq(output, choose0 ? 100 : 109);
        assertEq(currency0.balanceOf(address(pair)), choose0 ? 91 : 141);
        assertEq(currency1.balanceOf(address(pair)), choose0 ? 149 : 90);
        assertEq(currency0.balanceOf(RECIPIENT), choose0 ? 100 : 0);
        assertEq(currency1.balanceOf(RECIPIENT), choose0 ? 0 : 109);
        assertEq(trace.count("modify"), 2, "skip-add must suppress all sale-time additions");
        assertEq(trace.count("unlock"), 3);
        assertEq(trace.count("swap"), 1);
        _assertModification(0, 0);
        _assertModification(1, -4995);
        _assertSwap(!choose0, choose0 ? 89 : 80);
        Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
        assertEq(logs.length, 2);
        _assertTransfer(logs[0], address(this), address(0), 1000);
        _assertFlow(logs[1], REDEEM, address(this), RECIPIENT, 80, 89, 1000);
    }

    function test_PT_AC_27() public { _partialExit(true); }

    function test_PT_AC_28_token0() public { _partialExit(true); }
    function test_PT_AC_28_token1() public { _partialExit(false); }

    function test_PT_AC_28_bad_token_before_compound() public {
        _funded(false);
        manager.setFailure(IPoolManager.extsload.selector, true);
        vm.recordLogs();
        _fails(
            abi.encodeCall(pair.redeemZap, (1000, address(0xBAD), 0, RECIPIENT)),
            abi.encodeWithSignature("BadToken()"), RECIPIENT
        );
        assertEq(trace.length(), 0);
        assertEq(_instanceLogs(vm.getRecordedLogs()).length, 0);
    }

    function test_PT_AC_29_zero_supply() public {
        manager.setFailure(IPoolManager.extsload.selector, true);
        (uint256 amount0, uint256 amount1) = pair.previewRedeem(100);
        assertEq(amount0, 0);
        assertEq(amount1, 0);
        (amount0, amount1) = pair.previewRedeem(0);
        assertEq(amount0, 0);
        assertEq(amount1, 0);
        assertEq(trace.length(), 0);
    }

    function test_PT_AC_29_zero_shares_and_oversize() public {
        _funded(false);
        _position(0);
        _idle(101, 99);
        manager.setFailure(IPoolManager.extsload.selector, true);
        (uint256 amount0, uint256 amount1) = pair.previewRedeem(0);
        assertEq(amount0, 0);
        assertEq(amount1, 0);
        manager.setFailure(IPoolManager.extsload.selector, false);
        vm.prank(SPENDER);
        (amount0, amount1) = pair.previewRedeem(20000);
        assertEq(amount0, 201); // floor(101 * 19980 / 10000)
        assertEq(amount1, 197);
        assertEq(pair.totalSupply(), 10000);
        assertEq(pair.balanceOf(SPENDER), 0);
        assertEq(trace.length(), 0);
    }

    function test_PT_AC_30() public {
        _funded(false);
        _idle(100, 100);
        (uint256 preview0, uint256 preview1) = pair.previewRedeem(1000);
        assertEq(preview0, 5004);
        assertEq(preview1, 5004);
        manager.queueModify(_delta(2000, 2000), 0);
        manager.queueModify(_delta(-2100, -2100), 0);
        pair.compound();
        assertEq(pair.positionLiquidity(), 52100);
        _collectAndRemove(7000, 8000);
        (uint256 amount0, uint256 amount1) = pair.redeem(1000, 0, 0, RECIPIENT);
        assertEq(amount0, 7000);
        assertEq(amount1, 8000);
        assertTrue(preview0 != amount0 && preview1 != amount1);
    }

    function test_PT_AC_31() public {
        _funded(false);
        _position(0);
        _idle(100, 100);
        ScriptedERC20 third = new ScriptedERC20(trace);
        third.mint(address(this), 777);
        vm.recordLogs();
        currency0.transfer(address(pair), 200);
        third.transfer(address(pair), 777);
        assertEq(_instanceLogs(vm.getRecordedLogs()).length, 0);
        assertEq(pair.totalSupply(), 10000);
        assertEq(pair.balanceOf(address(this)), 9000);
        (uint256 reserve0, uint256 reserve1) = pair.basket();
        assertEq(reserve0, 300);
        assertEq(reserve1, 100);
        (uint256 amount0, uint256 amount1) = pair.redeem(1000, 29, 9, RECIPIENT);
        assertEq(amount0, 29);
        assertEq(amount1, 9);
        assertEq(third.balanceOf(address(pair)), 777);
        (bool ok, bytes memory reason) = address(pair).call(
            abi.encodeWithSignature("rescue(address,address,uint256)", address(third), RECIPIENT, 777)
        );
        assertFalse(ok);
        assertEq(reason, "");
        assertEq(third.balanceOf(address(pair)), 777);
    }

    function test_PT_AC_32() public {
        _funded(false);
        _position(0);
        _idle(1000, 1000);
        pair.transfer(SPENDER, 4000);
        (uint256 amount0, uint256 amount1) = pair.redeem(5000, 0, 0, RECIPIENT);
        assertEq(amount0, 499);
        assertEq(amount1, 499);
        vm.prank(SPENDER);
        (amount0, amount1) = pair.redeem(4000, 0, 0, RECIPIENT);
        assertEq(amount0, 400);
        assertEq(amount1, 400);
        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.balanceOf(SPENDER), 0);
        assertEq(pair.balanceOf(pair.DEAD()), 1000);
        assertEq(pair.totalSupply(), 1000);
        assertEq(currency0.balanceOf(address(pair)), 101);
        assertEq(currency1.balanceOf(address(pair)), 101);
        assertEq(trace.count("modify"), 0);
    }

    function test_PT_AC_33() public {
        for (uint256 side; side < 2; ++side) {
            _deploy(false);
            // Extrema are PRD constants, so this independent fixture needs no
            // production tick helper. Endpoints remain within the int24 ABI.
            pair = new PairToken();
            key.tickSpacing = 887272;
            factory.initialize(address(pair), address(manager), key);
            manager.configurePool(pair.poolId(), Q96, 0);
            _position(1000000000000000000000000000000);
            _idle(7, 11);
            manager.setSlot0(
                pair.poolId(), side == 0 ? uint160(2147564369) : type(uint160).max, side == 0 ? -887272 : int24(887272)
            );
            (uint256 amount0, uint256 amount1) = pair.basket();
            if (side == 0) {
                assertEq(amount0, 36892101423323780984906045596624442785157596329179);
                assertEq(amount1, 27106073178);
            } else {
                assertEq(amount0, 2037693);
                assertEq(amount1, 18446744073709551615999999999999999999945787853676);
            }
            assertEq(pair.totalSupply(), 0);
        }
    }

    function test_PT_AC_52_payout_raw_returndata() public {
        for (uint256 scenario; scenario < 4; ++scenario) {
            _funded(false);
            manager.queueModify(_delta(0, 100), 0);
            manager.queueModify(0, 0);
            bytes memory raw;
            if (scenario == 0) {
                currency0.setTransferMode(ScriptedERC20.ReturnMode.OneByte);
                raw = hex"01";
            } else if (scenario == 1) {
                currency0.setTransferMode(ScriptedERC20.ReturnMode.False);
                raw = abi.encode(false);
            } else if (scenario == 2) {
                currency0.setTransferMode(ScriptedERC20.ReturnMode.Malformed);
                raw = abi.encode(uint256(2));
            } else {
                currency0.setTransferMode(ScriptedERC20.ReturnMode.RevertCall);
                raw = abi.encodeWithSelector(ScriptedERC20.TokenFailure.selector);
            }
            _fails(
                abi.encodeCall(pair.redeem, (1000, 0, 0, RECIPIENT)),
                _wrapped(address(currency0), TOKEN_TRANSFER, raw, "ERC20TransferFailed()"), RECIPIENT
            );
        }
    }

    function test_PT_AC_52_pull_decode_and_false() public {
        for (uint256 scenario; scenario < 3; ++scenario) {
            _funded(false);
            _position(0);
            _idle(100, 100);
            currency0.approve(address(pair), 500);
            currency1.approve(address(pair), 500);
            currency1.setTransferFromMode(
                scenario == 0 ? ScriptedERC20.ReturnMode.OneByte
                    : scenario == 1 ? ScriptedERC20.ReturnMode.Malformed : ScriptedERC20.ReturnMode.False
            );
            trace.clear();
            _fails(
                abi.encodeCall(pair.deposit, (100, 100, 0, RECIPIENT)),
                scenario == 2 ? abi.encodeWithSignature("TransferFailed()") : bytes(""), RECIPIENT
            );
        }
    }

    function test_PT_AC_52_payout_empty_and_extra_true() public {
        for (uint256 scenario; scenario < 2; ++scenario) {
            _funded(false);
            _position(0);
            _idle(100, 100);
            currency0.setTransferMode(
                scenario == 0 ? ScriptedERC20.ReturnMode.Empty : ScriptedERC20.ReturnMode.TrueExtra
            );
            (uint256 amount0,) = pair.redeem(1000, 9, 9, RECIPIENT);
            assertEq(amount0, 9);
            assertEq(currency0.balanceOf(RECIPIENT), 9);
        }
    }

    function test_PT_AC_53() public {
        _funded(false);
        _position(0);
        _idle(1000, 1000);
        currency0.setTransferMode(ScriptedERC20.ReturnMode.FeeOnTransfer);
        currency0.setFeeBps(1000);
        vm.recordLogs();
        (uint256 amount0, uint256 amount1) = pair.redeem(1000, 99, 99, RECIPIENT);
        assertEq(amount0, 99);
        assertEq(amount1, 99);
        assertEq(currency0.balanceOf(RECIPIENT), 90);
        assertEq(currency1.balanceOf(RECIPIENT), 99);
        Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
        assertEq(logs.length, 2);
        _assertFlow(logs[1], REDEEM, address(this), RECIPIENT, 99, 99, 1000);
    }

    function test_PT_AC_54_minimum_after_sale_rolls_back() public {
        _funded(false);
        manager.queueModify(_delta(100, 100), 0);
        manager.queueModify(_delta(70, 80), 0);
        manager.queueSwap(_delta(20, -30), Q96 + 1, 1000);
        _fails(
            abi.encodeCall(pair.redeemZap, (1000, address(currency0), 1000, RECIPIENT)),
            abi.encodeWithSignature("MinOut()"), RECIPIENT
        );
        // A successful retry proves the entered/skip-add operation state also rolled back.
        assertEq(pair.redeemZap(1000, address(currency0), 0, RECIPIENT), 110);
        assertEq(trace.count("modify"), 2);
        assertEq(trace.count("swap"), 1);
    }

    function test_PT_AC_54_second_payout_rolls_back_first() public {
        _funded(false);
        manager.queueModify(_delta(100, 0), 0);
        manager.queueModify(0, 0);
        currency1.setTransferMode(ScriptedERC20.ReturnMode.False);
        _fails(
            abi.encodeCall(pair.redeem, (1000, 0, 0, RECIPIENT)),
            _wrapped(address(currency1), TOKEN_TRANSFER, abi.encode(false), "ERC20TransferFailed()"), RECIPIENT
        );
    }

    function test_PT_AC_54_refund_after_mint_rolls_back() public {
        _funded(true);
        _idle(100, 100);
        NativeRecipient sender = new NativeRecipient(trace);
        currency1.mint(address(sender), 500);
        sender.execute(address(currency1), abi.encodeWithSelector(ScriptedERC20.approve.selector, address(pair), 500));
        sender.setReject(true);
        manager.queueModify(_delta(100, 100), 0);
        manager.queueModify(0, 0);
        trace.clear();
        bytes32 beforeState = _state(address(sender));
        vm.startStateDiffRecording();
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(sender).call{value: 1000}(
            abi.encodeCall(sender.execute, (address(pair), abi.encodeCall(pair.deposit, (1000, 100, 0, RECIPIENT))))
        );
        Vm.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();
        Vm.Log[] memory attemptedLogs = vm.getRecordedLogs();
        assertFalse(ok);
        assertEq(reason, abi.encodeWithSignature("TransferFailed()"));
        _assertRevertedFrame(accesses, attemptedLogs);
        assertEq(_state(address(sender)), beforeState);
        assertEq(sender.receivedCalls(), 0);
        assertEq(sender.receivedValue(), 0);
    }

    function test_PT_AC_54_caught_notify_allows_exit() public {
        for (uint256 scenario; scenario < 6; ++scenario) {
            bool native0 = scenario >= 3;
            _funded(native0);
            factory.configure(address(feeManager), 10000, 10000, 100);
            feeManager.setMode(
                scenario % 3 == 0 ? ScriptedFeeManager.Mode.RevertCustom
                    : scenario % 3 == 1 ? ScriptedFeeManager.Mode.RevertEmpty : ScriptedFeeManager.Mode.RevertPanic
            );
            manager.queueModify(_delta(100, 0), 0);
            manager.queueModify(0, 0);
            vm.recordLogs();
            (uint256 amount0, uint256 amount1) = pair.redeem(1000, 20, 9, RECIPIENT);
            assertEq(amount0, 20);
            assertEq(amount1, 9);
            assertEq(pair.totalSupply(), 9000);
            assertEq(currency0.allowance(address(pair), address(feeManager)), 0);
            assertEq(feeManager.notifications(), 0);
            assertEq(trace.count("notify"), 0, "reverted notification has no persistent trace");
            assertEq(trace.count("approve"), native0 ? 0 : 2);
            Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
            assertEq(logs.length, 3);
            assertEq(logs[0].topics.length, 1);
            assertEq(logs[0].topics[0], COMPOUNDED);
            assertEq(logs[0].data, abi.encode(uint256(100), uint256(0), uint256(0), uint256(0), uint128(0)));
            _assertTransfer(logs[1], address(this), address(0), 1000);
            _assertFlow(logs[2], REDEEM, address(this), RECIPIENT, 20, 9, 1000);
        }
    }

    function test_PT_AC_57_genesis() public {
        vm.recordLogs();
        assertEq(_bootstrap(10000), 9000);
        Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
        assertEq(logs.length, 3);
        _assertTransfer(logs[0], address(0), pair.DEAD(), 1000);
        _assertTransfer(logs[1], address(0), address(this), 9000);
        _assertFlow(logs[2], DEPOSIT, address(this), address(this), 10000, 10000, 9000);
    }

    function test_PT_AC_57_genesis_after_automatic_compound() public {
        _idle(2000, 2000);
        vm.recordLogs();
        assertEq(_bootstrap(10000), 9000);
        Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
        assertEq(logs.length, 4);
        assertEq(logs[0].topics.length, 1);
        assertEq(logs[0].topics[0], COMPOUNDED);
        assertEq(logs[0].data, abi.encode(uint256(0), uint256(0), uint256(0), uint256(0), uint128(2000)));
        _assertTransfer(logs[1], address(0), pair.DEAD(), 1000);
        _assertTransfer(logs[2], address(0), address(this), 9000);
        _assertFlow(logs[3], DEPOSIT, address(this), address(this), 10000, 10000, 9000);
    }

    function test_PT_AC_57_zap_entry() public {
        _funded(false);
        _position(0);
        _idle(100, 100);
        manager.queueSwap(_delta(-50, 40), Q96, 0);
        manager.queueModify(_delta(-140, -140), 0);
        vm.recordLogs();
        assertEq(pair.zapDeposit(address(currency0), 100, 14000, RECIPIENT), 14000);
        Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
        assertEq(logs.length, 2);
        _assertTransfer(logs[0], address(0), RECIPIENT, 14000);
        _assertFlow(logs[1], DEPOSIT, address(this), RECIPIENT, 140, 140, 14000);
        assertEq(pair.balanceOf(pair.DEAD()), 1000);
        assertEq(pair.totalSupply(), 24000);
    }

    function test_PT_AC_57_zap_exit_and_payout_order() public {
        _funded(false);
        manager.queueModify(_delta(100, 0), 0);
        manager.queueModify(_delta(70, 80), 0);
        manager.queueSwap(_delta(20, -30), Q96, 0);
        currency0.setCallback(address(this), abi.encodeCall(this.payoutMarker, ()), true);
        currency0.setTransferMode(ScriptedERC20.ReturnMode.Callback);
        vm.recordLogs();
        assertEq(pair.redeemZap(1000, address(currency0), 110, RECIPIENT), 110);
        Vm.Log[] memory all = vm.getRecordedLogs();
        Vm.Log[] memory logs = _instanceLogs(all);
        assertEq(logs.length, 3);
        assertEq(logs[0].topics.length, 1);
        assertEq(logs[0].topics[0], COMPOUNDED);
        assertEq(logs[0].data, abi.encode(uint256(100), uint256(0), uint256(0), uint256(0), uint128(0)));
        _assertTransfer(logs[1], address(this), address(0), 1000);
        _assertFlow(logs[2], REDEEM, address(this), RECIPIENT, 90, 89, 1000);
        uint256 burnIndex;
        uint256 payoutIndex;
        uint256 redeemIndex;
        bytes memory payoutState;
        for (uint256 i; i < all.length; ++i) {
            if (all[i].emitter == address(pair) && all[i].topics[0] == TRANSFER) burnIndex = i;
            if (all[i].emitter == address(this)) {
                payoutIndex = i;
                payoutState = all[i].data;
            }
            if (all[i].emitter == address(pair) && all[i].topics[0] == REDEEM) redeemIndex = i;
        }
        assertEq(payoutState, abi.encode(uint256(9000), uint256(8000)));
        assertGt(payoutIndex, burnIndex);
        assertLt(payoutIndex, redeemIndex);
        TraceRecorder.Entry memory lastTransfer = _entry("transfer", trace.count("transfer") - 1);
        assertEq(lastTransfer.caller, address(pair));
        assertEq(lastTransfer.depth, 0);
        assertEq(lastTransfer.data, abi.encodeWithSelector(TOKEN_TRANSFER, RECIPIENT, 110));
    }

    function test_PT_AC_57_allowance_consumption() public {
        _funded(false);
        vm.recordLogs();
        pair.approve(SPENDER, 10);
        Vm.Log[] memory approvalLogs = _instanceLogs(vm.getRecordedLogs());
        assertEq(approvalLogs.length, 1);
        assertEq(approvalLogs[0].topics.length, 3);
        assertEq(approvalLogs[0].topics[0], keccak256("Approval(address,address,uint256)"));
        assertEq(approvalLogs[0].topics[1], bytes32(uint256(uint160(address(this)))));
        assertEq(approvalLogs[0].topics[2], bytes32(uint256(uint160(SPENDER))));
        assertEq(approvalLogs[0].data, abi.encode(uint256(10)));
        assertEq(pair.allowance(address(this), SPENDER), 10);
        vm.recordLogs();
        vm.prank(SPENDER);
        pair.transferFrom(address(this), RECIPIENT, 4);
        Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
        assertEq(logs.length, 1, "consumption must not emit Approval");
        _assertTransfer(logs[0], address(this), RECIPIENT, 4);
        assertEq(pair.allowance(address(this), SPENDER), 6);
        assertEq(trace.length(), 0);
    }

    function test_PT_AC_64() public {
        _zeroExit(false, false);
        _zeroExit(true, true);
        _zeroExit(true, false);
    }

    function test_PT_AC_64_one_zero_paired_leg() public {
        for (uint256 zeroLeg; zeroLeg < 2; ++zeroLeg) {
            _funded(false);
            _position(0);
            _idle(zeroLeg == 0 ? 0 : 1000, zeroLeg == 1 ? 0 : 1000);
            vm.recordLogs();
            (uint256 amount0, uint256 amount1) = pair.redeem(1000, 0, 0, RECIPIENT);
            assertEq(amount0, zeroLeg == 0 ? 0 : 99);
            assertEq(amount1, zeroLeg == 1 ? 0 : 99);
            assertEq(trace.count("transfer"), 1);
            TraceRecorder.Entry memory payout = _entry("transfer", 0);
            assertEq(payout.target, zeroLeg == 0 ? address(currency1) : address(currency0));
            assertEq(payout.data, abi.encodeWithSelector(TOKEN_TRANSFER, RECIPIENT, 99));
            Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
            assertEq(logs.length, 2);
            _assertFlow(logs[1], REDEEM, address(this), RECIPIENT, amount0, amount1, 1000);
        }
    }

    function test_PT_AC_64_zero_native_selected_call() public {
        _funded(true);
        NativeRecipient recipient = new NativeRecipient(trace);
        manager.queueModify(0, 0);
        vm.recordLogs();
        assertEq(pair.redeemZap(1, address(0), 0, address(recipient)), 0);
        assertEq(recipient.receivedCalls(), 1);
        assertEq(recipient.receivedValue(), 0);
        TraceRecorder.Entry memory payout = _entry("payout", 0);
        assertEq(payout.caller, address(pair));
        assertEq(payout.value, 0);
        assertEq(payout.data, "");
        assertEq(payout.depth, 0);
        Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
        assertEq(logs.length, 2);
        _assertFlow(logs[1], REDEEM, address(this), address(recipient), 0, 0, 1);
    }

    function test_PT_AC_64_zero_native_paired_skips_call() public {
        _funded(true);
        NativeRecipient recipient = new NativeRecipient(trace);
        recipient.setReject(true);
        manager.queueModify(0, 0);
        vm.recordLogs();
        (uint256 amount0, uint256 amount1) = pair.redeem(1, 0, 0, address(recipient));
        assertEq(amount0, 0);
        assertEq(amount1, 0);
        assertEq(recipient.receivedCalls(), 0);
        assertEq(trace.count("payout"), 0);
        assertEq(trace.count("transfer"), 0);
        Vm.Log[] memory logs = _instanceLogs(vm.getRecordedLogs());
        assertEq(logs.length, 2);
        _assertTransfer(logs[0], address(this), address(0), 1);
        _assertFlow(logs[1], REDEEM, address(this), address(recipient), 0, 0, 1);
    }

    function test_PT_AC_65() public {
        for (uint256 scenario; scenario < 3; ++scenario) {
            _funded(true);
            NativeRecipient recipient = new NativeRecipient(trace);
            recipient.setReject(true);
            manager.queueModify(_delta(100, 0), 0);
            if (scenario != 2) manager.queueModify(0, 0);
            bytes memory callData = scenario == 0
                ? abi.encodeCall(pair.redeem, (1000, 0, 0, address(recipient)))
                : abi.encodeCall(pair.redeemZap, (scenario == 2 ? 1 : 1000, address(0), 0, address(recipient)));
            _fails(
                callData,
                _wrapped(
                    address(recipient), bytes4(0),
                    abi.encodeWithSignature("Error(string)", "recipient rejected"), "NativeTransferFailed()"
                ),
                address(recipient)
            );
            assertEq(recipient.receivedCalls(), 0);
            assertEq(recipient.receivedValue(), 0);
        }
    }

    function test_PT_EXIT_skip_add() public {
        _funded(false);
        _collectAndRemove(70, 80);
        manager.queueSwap(_delta(20, -30), Q96, 0);
        assertEq(pair.redeemZap(1000, address(currency0), 100, RECIPIENT), 100);
        assertEq(trace.count("modify"), 2);
        assertEq(pair.positionLiquidity(), 45005);
        // The same instance must subsequently add. This observes reset without a
        // private flag getter, SUT subclass, storage write or replacement runtime.
        _idle(2000, 2000);
        trace.clear();
        manager.queueModify(0, 0);
        manager.queueModify(_delta(-2000, -2000), 0);
        pair.compound();
        assertEq(trace.count("modify"), 2);
        _assertModification(0, 0);
        _assertModification(1, 2000);
        assertEq(pair.positionLiquidity(), 47005);
        assertEq(currency0.balanceOf(address(pair)), 0);
        assertEq(currency1.balanceOf(address(pair)), 0);
        assertEq(pair.totalSupply(), 9000);
    }

    function test_PT_GAS_forwarding_payout() public {
        for (uint256 route; route < 2; ++route) {
            _funded(true);
            NativeRecipient recipient = new NativeRecipient(trace);
            _position(0);
            _idle(1000, route == 0 ? 1000 : 0);
            if (route == 0) {
                (uint256 amount0, uint256 amount1) = pair.redeem(1000, 99, 99, address(recipient));
                assertEq(amount0, 99);
                assertEq(amount1, 99);
            } else {
                assertEq(pair.redeemZap(1000, address(0), 99, address(recipient)), 99);
            }
            assertEq(recipient.receivedCalls(), 1, "receive storage writes require more than a stipend");
            assertEq(recipient.receivedValue(), 99);
            assertEq(address(recipient).balance, 99);
            TraceRecorder.Entry memory payout = _entry("payout", 0);
            assertEq(payout.target, address(recipient));
            assertEq(payout.caller, address(pair));
            assertEq(payout.value, 99);
            assertEq(payout.data, "");
            assertEq(payout.depth, 0);
        }
    }
}
