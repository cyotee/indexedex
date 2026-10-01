// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/// @notice Canonical unbooked-credit arithmetic and the contract-only pretransfer caller check.
/// @dev Pure availability math does not attribute ownership. `requirePretransferCaller` only
///      inspects bytecode; it cannot prove atomic transfer-and-consume.
library LocalCreditLib {
    using BetterAddress for address;

    /// @notice Unbooked local units: `balance - booked`, or 0 when booked is at least balance.
    function available(uint256 balance, uint256 booked) internal pure returns (uint256) {
        return balance > booked ? balance - booked : 0;
    }

    /// @notice Refund/credit cap: `min(available_, maximum)`.
    function budget(uint256 available_, uint256 maximum) internal pure returns (uint256) {
        return available_ < maximum ? available_ : maximum;
    }

    /// @notice Reverts `EOAPretransferNotAllowed` when `caller` has no bytecode.
    function requirePretransferCaller(address caller) internal view {
        if (!caller.isContract()) {
            revert ISecurePullErrors.EOAPretransferNotAllowed();
        }
    }
}
