// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";

/// @title ReentrantMockERC20
/// @notice A malicious ERC20 that attempts to re-enter a target contract during `transferFrom`,
///         modelling a hostile `tokenA`/`tokenB` (e.g. an arbitrary community token wired into a DETF)
///         whose transfer hook re-enters the vault mid-route.
/// @dev When armed, the first (non-nested) `transferFrom` performs a low-level call of `reentryCall`
///      against `target` before completing the transfer, and bubbles any revert so the outer call
///      surfaces the reason (e.g. a reentrancy-guard `IsLocked`). A depth flag prevents infinite
///      recursion so that WITHOUT a guard the re-entry proceeds (and the outer call would succeed),
///      making the test meaningful in both directions.
contract ReentrantMockERC20 is MockERC20 {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockERC20(name_, symbol_, decimals_) {}

    /// @notice Arms the token to re-enter `target_` with `reentryCall_` on the next `transferFrom`.
    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
    }

    function transferFrom(address from_, address to_, uint256 value_) public override returns (bool) {
        if (armed && _depth == 0) {
            _depth = 1;
            (bool ok_, bytes memory ret_) = target.call(reentryCall);
            _depth = 0;
            if (!ok_) {
                assembly {
                    revert(add(ret_, 0x20), mload(ret_))
                }
            }
        }
        return super.transferFrom(from_, to_, value_);
    }
}
