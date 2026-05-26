// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library DETFPreviewLib {
    function _applyDiscountBps(uint256 amount_, uint256 bufferBps_, uint256 denominator_)
        internal
        pure
        returns (uint256 adjustedAmount_)
    {
        adjustedAmount_ = amount_ - ((amount_ * bufferBps_) / denominator_);
    }

    function _applyMarkupBps(uint256 amount_, uint256 bufferBps_, uint256 denominator_)
        internal
        pure
        returns (uint256 adjustedAmount_)
    {
        adjustedAmount_ = amount_ + ((amount_ * bufferBps_) / denominator_);
    }
}