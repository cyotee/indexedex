// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @dev Integrating-contract fixture: pull from an approved payer, then either push tokens
///      and invoke a true-flag route or approve and invoke a false-flag pull route.
///      Also used as the deployed contract-wallet control (D44). Not a SUT mock.
contract AtomicPretransferCaller {
    function consumePretransfer(
        IERC20 token,
        address payer,
        address target,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes memory returned) {
        if (amount != 0) {
            token.transferFrom(payer, address(this), amount);
            token.transfer(target, amount);
        }
        return _call(target, data);
    }

    function consumePull(
        IERC20 token,
        address payer,
        address target,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes memory returned) {
        if (amount != 0) {
            token.transferFrom(payer, address(this), amount);
            token.approve(target, amount);
        }
        return _call(target, data);
    }

    function execute(address target, bytes calldata data) external returns (bytes memory returned) {
        return _call(target, data);
    }

    function _call(address target, bytes memory data) private returns (bytes memory returned) {
        bool ok;
        (ok, returned) = target.call(data);
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(returned, 32), mload(returned))
            }
        }
    }
}
