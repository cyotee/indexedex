// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Vm, VmSafe} from "forge-std/Vm.sol";

/// @notice Trace-level regression for native SY's no-self-call execution requirement.
library Behavior_NativeStandardYieldExecution {
    error NativeSYExecutionSelfCall(address host, VmSafe.AccountAccessKind kind, bytes data);

    function requireNoSelfCalls(VmSafe.AccountAccess[] memory calls_, address host_) internal pure {
        for (uint256 i_; i_ < calls_.length; ++i_) {
            VmSafe.AccountAccess memory call_ = calls_[i_];
            if (uint8(call_.kind) <= uint8(VmSafe.AccountAccessKind.StaticCall)
                && call_.accessor == host_ && call_.account == host_) {
                revert NativeSYExecutionSelfCall(host_, call_.kind, call_.data);
            }
        }
    }
}

abstract contract NativeSYExecutionAssertions {
    Vm private constant NATIVE_TRACE_VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Protocol callbacks and delegatecalls to distinct implementations remain permitted.
    modifier noSelfCalls(address host_) {
        NATIVE_TRACE_VM.startStateDiffRecording();
        _;
        Behavior_NativeStandardYieldExecution.requireNoSelfCalls(NATIVE_TRACE_VM.stopAndReturnStateDiff(), host_);
    }
}
