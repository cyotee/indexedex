// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";

/// @notice Test-only real outer unlock for read-only calls to a provider or exchange.
contract FullSpreadRateContextReader is IUnlockCallback {
    IPoolManager public immutable manager;
    bool private active;
    constructor(IPoolManager manager_) { manager = manager_; }
    function readWhileUnlocked(address target_, bytes calldata data_) external returns (bytes memory result_) {
        require(!active, "recursive context reader");
        active = true;
        result_ = manager.unlock(abi.encode(target_, data_));
        active = false;
    }
    function unlockCallback(bytes calldata data_) external returns (bytes memory result_) {
        require(msg.sender == address(manager) && active, "unauthorized context reader");
        (address target, bytes memory callData) = abi.decode(data_, (address, bytes));
        bool ok;
        (ok, result_) = target.staticcall(callData);
        if (!ok) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
    }
}
