// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @dev Constructor-time integrating caller. Runtime code is absent while this sequence runs,
///      so `BetterAddress.isContract(msg.sender)` is false for the duration of the call.
contract AtomicPretransferConstructorCaller {
    bytes public result;

    constructor(
        IERC20 token,
        address payer,
        address target,
        uint256 amount,
        bytes memory data,
        bool pretransfer
    ) {
        if (amount != 0) {
            token.transferFrom(payer, address(this), amount);
            if (pretransfer) {
                token.transfer(target, amount);
            } else {
                token.approve(target, amount);
            }
        }
        (bool ok, bytes memory returned) = target.call(data);
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(returned, 32), mload(returned))
            }
        }
        result = returned;
    }
}
