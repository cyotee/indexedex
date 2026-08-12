// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";

/// @title HostileReentrantShare
/// @notice Shared adversarial harness: transferFrom re-enters a target, then completes transfer.
/// @dev Nested failure does not roll back probe state (outer transfer always completes).
///      Wave 0 shared harness for peer DETF/SE adversarial suites.
contract HostileReentrantShare is MockERC20 {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;

    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor() MockERC20("HostileReentrantShare", "HSHR", 18) {}

    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
        reentryAttempts = 0;
        nestedCallSucceeded = false;
        nestedErrorSelector = bytes4(0);
    }

    function disarm() external {
        armed = false;
    }

    function transferFrom(address from_, address to_, uint256 value_) public override returns (bool) {
        if (armed && _depth == 0) {
            _depth = 1;
            unchecked {
                ++reentryAttempts;
            }
            (bool ok_, bytes memory ret_) = target.call(reentryCall);
            nestedCallSucceeded = ok_;
            if (!ok_ && ret_.length >= 4) {
                bytes4 sel;
                assembly {
                    sel := mload(add(ret_, 0x20))
                }
                nestedErrorSelector = sel;
            } else if (ok_) {
                nestedErrorSelector = bytes4(0);
            }
            _depth = 0;
        }
        return super.transferFrom(from_, to_, value_);
    }
}
