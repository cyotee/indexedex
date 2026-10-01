// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Family-local, one-shot transient authorization for PoolManager callbacks.
/// @dev A callback is bound to its manager, exact action payload and settlement budgets.
library UniswapV4FullSpreadHooklessStandardExchangeVaultExecutionContextRepo {
    bytes32 internal constant DEFAULT_SLOT = bytes32(uint256(keccak256(abi.encode("indexedex.uniswap.v4.fullSpread.hookless.execution.context"))) - 1);
    error AccountingMismatch();

    function _begin(address manager, bytes32 action, uint256 budget0, uint256 budget1) internal {
        bytes32 slot = DEFAULT_SLOT;
        uint256 active;
        assembly ("memory-safe") { active := tload(slot) }
        uint256 operation; bytes32 plan; uint256 reserved0; uint256 reserved1;
        assembly ("memory-safe") {
            operation := tload(add(slot, 5)) plan := tload(add(slot, 8))
            reserved0 := tload(add(slot, 9)) reserved1 := tload(add(slot, 10))
        }
        if (active != 0 || operation == 0 || plan == bytes32(0)) revert AccountingMismatch();
        // Action authorization commits the enclosing workflow/plan and its live liabilities.
        action = keccak256(abi.encode(action, plan, reserved0, reserved1));
        assembly ("memory-safe") {
            tstore(slot, 1)
            tstore(add(slot, 1), manager)
            tstore(add(slot, 2), action)
            tstore(add(slot, 3), budget0)
            tstore(add(slot, 4), budget1)
        }
    }

    function _consume(address caller, bytes32 action) internal {
        bytes32 slot = DEFAULT_SLOT;
        uint256 active; address manager; bytes32 expected;
        assembly ("memory-safe") {
            active := tload(slot)
            manager := tload(add(slot, 1))
            expected := tload(add(slot, 2))
        }
        bytes32 plan; uint256 reserved0; uint256 reserved1;
        assembly ("memory-safe") {
            plan := tload(add(slot, 8)) reserved0 := tload(add(slot, 9)) reserved1 := tload(add(slot, 10))
        }
        action = keccak256(abi.encode(action, plan, reserved0, reserved1));
        if (active != 1 || manager != caller || expected != action) revert AccountingMismatch();
        assembly ("memory-safe") { tstore(slot, 2) }
    }

    function _spend(uint256 index, uint256 amount) internal {
        bytes32 slot = DEFAULT_SLOT;
        uint256 active; uint256 budget;
        assembly ("memory-safe") { active := tload(slot) budget := tload(add(add(slot, 3), index)) }
        if (index > 1 || active != 2 || amount > budget) revert AccountingMismatch();
        assembly ("memory-safe") { tstore(add(add(slot, 3), index), sub(budget, amount)) }
    }

    function _finish() internal {
        bytes32 slot = DEFAULT_SLOT;
        uint256 active;
        assembly ("memory-safe") { active := tload(slot) }
        if (active != 2) revert AccountingMismatch();
        assembly ("memory-safe") {
            tstore(slot, 0) tstore(add(slot, 1), 0) tstore(add(slot, 2), 0)
            tstore(add(slot, 3), 0) tstore(add(slot, 4), 0)
        }
    }

    function _beginOperation(bytes4 workflow, uint256 sleeve) internal {
        bytes32 slot = DEFAULT_SLOT;
        uint256 active;
        assembly ("memory-safe") { active := tload(add(slot, 5)) }
        if (active != 0) revert AccountingMismatch();
        assembly ("memory-safe") {
            tstore(add(slot, 5), 1)
            tstore(add(slot, 6), sleeve)
            tstore(add(slot, 7), workflow)
        }
    }

    function _sleeve() internal view returns (bool active, uint256 value) {
        bytes32 slot = DEFAULT_SLOT;
        assembly ("memory-safe") { active := tload(add(slot, 5)) value := tload(add(slot, 6)) }
    }

    function _endOperation() internal {
        bytes32 slot = DEFAULT_SLOT;
        uint256 action;
        assembly ("memory-safe") { action := tload(slot) }
        if (action != 0) revert AccountingMismatch();
        assembly ("memory-safe") { tstore(add(slot, 5), 0) tstore(add(slot, 6), 0) tstore(add(slot, 7), 0)
            tstore(add(slot, 8), 0) tstore(add(slot, 9), 0) tstore(add(slot, 10), 0)
        }
    }

    function _commitPlan(bytes32 plan, uint256 liability0, uint256 liability1) internal {
        bytes32 slot = DEFAULT_SLOT;
        uint256 operation; uint256 action; bytes4 workflow;
        assembly ("memory-safe") {
            operation := tload(add(slot, 5)) action := tload(slot) workflow := tload(add(slot, 7))
        }
        if (operation == 0 || action != 0) revert AccountingMismatch();
        plan = keccak256(abi.encode(workflow, plan));
        assembly ("memory-safe") {
            tstore(add(slot, 8), plan) tstore(add(slot, 9), liability0) tstore(add(slot, 10), liability1)
        }
    }
}
