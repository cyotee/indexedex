// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

/// @title DetfReentryTarget
/// @notice Nested callee for hostile-share reentrancy probes into DETF / SE entry points.
/// @dev Product-specific bond/redeem helpers can extend this contract or call these helpers.
contract DetfReentryTarget {
    function reenterExchangeIn(
        address detf_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        address recipient_
    ) external {
        IStandardExchangeIn(detf_).exchangeIn(
            tokenIn_, amountIn_, tokenOut_, 0, recipient_, false, block.timestamp + 1 hours
        );
    }

    /// @dev Generic low-level bond call: `bond(token, amount, lock, recipient, false, deadline)`.
    function reenterBondGeneric(
        address detf_,
        IERC20 share_,
        uint256 amountIn_,
        uint256 lock_,
        address recipient_
    ) external {
        (bool ok, bytes memory ret) = detf_.call(
            abi.encodeWithSignature(
                "bond(address,uint256,uint256,address,bool,uint256)",
                address(share_),
                amountIn_,
                lock_,
                recipient_,
                false,
                block.timestamp + 1 hours
            )
        );
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}
