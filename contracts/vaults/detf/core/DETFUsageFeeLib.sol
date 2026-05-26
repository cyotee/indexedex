// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

library DETFUsageFeeLib {
    uint256 internal constant ONE_WAD = 1e18;

    function _splitUsageFee(uint256 grossAmount_, uint256 feePercentage_)
        internal
        pure
        returns (uint256 userAmount_, uint256 feeAmount_)
    {
        feeAmount_ = Math.mulDiv(grossAmount_, feePercentage_, ONE_WAD);
        userAmount_ = grossAmount_ - feeAmount_;
    }
}