// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

library DETFSafeTransferLib {
    function _safeTransfer(IERC20 token_, address to_, uint256 amount_) internal {
        (bool success, bytes memory data) =
            address(token_).call(abi.encodeWithSelector(IERC20.transfer.selector, to_, amount_));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }
}