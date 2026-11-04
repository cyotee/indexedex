// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.35;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {PairTokenTestBase} from "./harness/PairTokenTestBase.sol";
import {TraceRecorder} from "./harness/ScriptedDependencies.sol";
import {PairToken} from "../../../../contracts/pairtoken-baseline/PairToken.sol";
import {PoolKey, SwapParams} from "../../../../contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol";

contract PairTokenSurfaceTest is PairTokenTestBase {
    function test_PT_AC_05() public {
        _bootstrap(10000);
        pair.approve(address(0xB), 10);
        vm.recordLogs();
        vm.prank(address(0xB));
        pair.transferFrom(address(this), address(0xC), 4);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(pair.allowance(address(this), address(0xB)), 6);
        assertEq(pair.balanceOf(address(0xC)), 4);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        vm.prank(address(0xB));
        pair.transferFrom(address(this), address(0xC), 7);
        assertEq(pair.allowance(address(this), address(0xB)), 6);
        pair.approve(address(0xB), 20000);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        vm.prank(address(0xB));
        pair.transferFrom(address(this), address(0xC), 10000);
        assertEq(pair.allowance(address(this), address(0xB)), 20000);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        pair.transferFrom(address(this), address(this), 1);
        pair.approve(address(this), 10);
        pair.transferFrom(address(this), address(this), 4);
        assertEq(pair.allowance(address(this), address(this)), 6);
        assertEq(pair.balanceOf(address(this)), 8996);
    }

    function test_PT_AC_06() public {
        _bootstrap(10000);
        pair.approve(address(this), type(uint256).max);
        pair.transferFrom(address(this), address(9), 4);
        assertEq(pair.allowance(address(this), address(this)), type(uint256).max);
        uint256 balance = pair.balanceOf(address(this));
        pair.transfer(address(this), balance);
        pair.transfer(address(9), 0);
        assertEq(pair.balanceOf(address(this)), balance);
        vm.expectRevert(PairToken.ZeroAddress.selector);
        pair.transfer(address(0), 0);
        pair.approve(address(this), 0);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        pair.transferFrom(address(this), address(0), 1);
    }

    function test_PT_AC_07() public {
        _bootstrap(10000);
        manager.queueModify(_delta(100, 200), 0);
        trace.clear();
        pair.transfer(address(9), 4);
        assertEq(trace.length(), 0);
        assertEq(pair.balanceOf(address(9)), 4);
        assertEq(manager.modifyCursor(), 0);
        assertEq(feeManager.notifications(), 0);
    }

    function test_PT_AC_56() public {
        _idle(0, 0);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        _callback(4, abi.encode(true, uint256(1) << 255));
        assertEq(trace.count("swap"), 0);
        _callback(4, abi.encode(true, (uint256(1) << 255) + 1));
        assertEq(trace.count("swap"), 1);
        for (uint256 i; i < trace.length(); ++i) {
            TraceRecorder.Entry memory entry = trace.entryAt(i);
            if (entry.kind == "swap") {
                bytes memory args = _arguments(entry.data);
                (, SwapParams memory params, bytes memory hookData) =
                    abi.decode(args, (PoolKey, SwapParams, bytes));
                assertEq(params.amountSpecified, type(int256).max);
                assertEq(params.sqrtPriceLimitX96, 4295128740);
                assertTrue(params.zeroForOne);
                assertEq(hookData.length, 0);
            }
        }
    }

    function test_PT_VIEW_slots() public {
        bytes32 base = keccak256(abi.encode(pair.poolId(), bytes32(uint256(6))));
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(pair), int24(-887220), int24(887220), bytes32(0)));
        bytes32 slot = keccak256(abi.encode(positionKey, bytes32(uint256(base) + 6)));
        manager.setWord(slot, bytes32((uint256(123) << 128) | 500));
        assertEq(pair.positionLiquidity(), 500);
        _position(0);
        _idle(71, 83);
        vm.startStateDiffRecording();
        (uint256 a, uint256 b) = pair.basket();
        Vm.AccountAccess[] memory calls = vm.stopAndReturnStateDiff();
        assertEq(a, 71);
        assertEq(b, 83);
        uint256 index;
        for (uint256 i; i < calls.length; ++i) {
            if (calls[i].accessor != address(pair)) continue;
            if (calls[i].account != address(manager) && calls[i].account != address(currency0)
                && calls[i].account != address(currency1)) continue;
            assertEq(uint256(calls[i].kind), uint256(VmSafe.AccountAccessKind.StaticCall));
            if (index == 0) assertEq(calls[i].data, abi.encodeWithSignature("extsload(bytes32)", base));
            if (index == 1) assertEq(calls[i].data, abi.encodeWithSignature("extsload(bytes32)", slot));
            if (index == 2) assertEq(calls[i].account, address(currency0));
            if (index == 3) assertEq(calls[i].account, address(currency1));
            ++index;
        }
        assertEq(index, 4);
    }

    function test_PT_AC_62() public {
        _bootstrap(10000);
        _position(0);
        _idle(100, 100);
        vm.startStateDiffRecording();
        pair.deposit(10, 10, 0, address(this));
        address[] memory reads = _readTargets(vm.stopAndReturnStateDiff());
        assertEq(reads.length, 14);
        assertEq(reads[11], address(currency0));
        assertEq(reads[12], address(currency1));
        assertEq(reads[13], address(manager), "paired addition fresh price follows idle pair");

        _position(0);
        _idle(101, 99);
        vm.startStateDiffRecording();
        pair.redeem(1, 0, 0, address(this));
        reads = _readTargets(vm.stopAndReturnStateDiff());
        assertEq(reads.length, 6);
        assertEq(reads[1], address(currency0));
        assertEq(reads[2], address(currency1));
        assertEq(reads[3], address(currency0));
        assertEq(reads[4], address(currency1));
        assertEq(reads[5], address(manager));

        _position(0);
        _idle(2000, 2000);
        vm.startStateDiffRecording();
        pair.compound();
        reads = _readTargets(vm.stopAndReturnStateDiff());
        assertEq(reads[1], address(currency0));
        assertEq(reads[2], address(currency1));
        assertEq(reads[reads.length - 3], address(manager), "Deploy holds price before idle pair");
        assertEq(reads[reads.length - 2], address(currency0));
        assertEq(reads[reads.length - 1], address(currency1));
    }

    function test_PT_AC_62_skipAddAndEarlyBadToken() public {
        _bootstrap(10000);
        _position(0);
        _idle(100, 100);
        manager.queueSwap(0, Q96, 0);
        vm.startStateDiffRecording();
        pair.redeemZap(1000, address(currency0), 0, address(this));
        address[] memory reads = _readTargets(vm.stopAndReturnStateDiff());
        assertEq(reads.length, 8);
        assertEq(reads[6], address(manager));
        assertEq(reads[7], address(manager), "skip-add ends after price reread");
        vm.startStateDiffRecording();
        vm.expectRevert(PairToken.BadToken.selector);
        pair.redeemZap(1, address(0xBAD), 0, address(this));
        reads = _readTargets(vm.stopAndReturnStateDiff());
        assertEq(reads.length, 0);
    }

    function _readTargets(Vm.AccountAccess[] memory calls) internal view returns (address[] memory targets) {
        uint256 count;
        targets = new address[](calls.length);
        for (uint256 i; i < calls.length; ++i) {
            if (calls[i].accessor == address(pair) && calls[i].kind == VmSafe.AccountAccessKind.StaticCall
                && (calls[i].account == address(manager) || calls[i].account == address(currency0)
                    || calls[i].account == address(currency1))) {
                targets[count++] = calls[i].account;
            }
        }
        assembly ("memory-safe") { mstore(targets, count) }
    }

    function _arguments(bytes memory data) internal pure returns (bytes memory result) {
        result = new bytes(data.length - 4);
        for (uint256 i; i < result.length; ++i) result[i] = data[i + 4];
    }
}
