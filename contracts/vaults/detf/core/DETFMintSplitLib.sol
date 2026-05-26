// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

library DETFMintSplitLib {
    uint256 internal constant ONE_WAD = 1e18;

    function _splitHalfSeigniorage(uint256 grossAmount_, uint256 seignioragePercentage_)
        internal
        pure
        returns (uint256 userAmount_, uint256 protocolAmount_)
    {
        protocolAmount_ = Math.mulDiv(grossAmount_, seignioragePercentage_, 2 * ONE_WAD);
        userAmount_ = grossAmount_ - protocolAmount_;
    }
}