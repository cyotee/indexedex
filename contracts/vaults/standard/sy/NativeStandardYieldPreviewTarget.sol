// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {NativeStandardYieldDiscoveryTarget, NativeStandardYieldValidation} from "./NativeStandardYieldDiscoveryTarget.sol";
import {NativeStandardYieldQuoteBase} from "./NativeStandardYieldQuoteBase.sol";

/// @notice Query-only native SY surface; it does not inherit deposit or redemption execution.
abstract contract NativeStandardYieldPreviewCallsTarget is NativeStandardYieldValidation, NativeStandardYieldQuoteBase {
    function previewDeposit(address tokenIn_, uint256 amount_) external view returns (uint256) {
        if (!isValidTokenIn(tokenIn_)) return 0;
        return _previewExchangeIn(IERC20(tokenIn_), amount_, IERC20(address(this)));
    }

    function previewRedeem(address tokenOut_, uint256 shares_) external view returns (uint256) {
        if (!isValidTokenOut(tokenOut_)) return 0;
        return _previewExchangeIn(IERC20(address(this)), shares_, IERC20(tokenOut_));
    }
}

abstract contract NativeStandardYieldPreviewTarget is NativeStandardYieldDiscoveryTarget, NativeStandardYieldPreviewCallsTarget {}
