// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library DETFThresholdPolicy {
    function _isMintingAllowed(uint256 threshold_, uint256 price_) internal pure returns (bool allowed_) {
        allowed_ = price_ > threshold_;
    }

    function _isBurningAllowed(uint256 threshold_, uint256 price_) internal pure returns (bool allowed_) {
        allowed_ = price_ < threshold_;
    }
}