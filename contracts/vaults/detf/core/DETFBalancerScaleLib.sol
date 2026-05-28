// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

library DETFBalancerScaleLib {
    using FixedPoint for uint256;

    function _toLiveScaled18(uint256 rawAmount_, TokenInfo memory info_) internal view returns (uint256 scaled18_) {
        uint256 rate = FixedPoint.ONE;
        if (address(info_.rateProvider) != address(0)) {
            rate = info_.rateProvider.getRate();
        }

        scaled18_ = rawAmount_.mulDown(rate);
    }
}