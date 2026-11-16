// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @title AdversarialAssertLib
/// @notice Residual free-inventory helpers for adversarial suites (Wave 0 pattern).
/// @dev BPT / reserve principal held on the diamond is intentional and not checked here.
library AdversarialAssertLib {
    function assertNoFreeProductInventory(address instance_, IERC20[] memory shareTokens_) internal view {
        require(IERC20(instance_).balanceOf(instance_) == 0, "residual free product token");
        for (uint256 i; i < shareTokens_.length; ++i) {
            require(shareTokens_[i].balanceOf(instance_) == 0, "residual free vault/share token");
        }
    }

    function assertNoFreeShare(address instance_, IERC20 share_) internal view {
        require(share_.balanceOf(instance_) == 0, "residual free share");
        require(IERC20(instance_).balanceOf(instance_) == 0, "residual free product");
    }
}
