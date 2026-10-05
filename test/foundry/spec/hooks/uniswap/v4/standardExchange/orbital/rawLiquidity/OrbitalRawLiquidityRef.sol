// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math as FullMath} from "@crane/contracts/utils/Math.sol";

/// @notice Test-local raw ownership reference. Not a call into the hook helper.
library OrbitalRawLiquidityRef {
    function floorShares(uint256 supply, uint256 contribution, uint256 incumbent)
        internal
        pure
        returns (uint256)
    {
        if (supply == 0 || contribution == 0 || incumbent == 0) return 0;
        return FullMath.mulDiv(supply, contribution, incumbent);
    }

    function ceilRequired(uint256 shares, uint256 incumbent, uint256 supply) internal pure returns (uint256) {
        if (shares == 0 || supply == 0) return 0;
        return FullMath.mulDiv(shares, incumbent, supply, FullMath.Rounding.Ceil);
    }

    function backs(uint256 delivered, uint256 supply, uint256 shares, uint256 incumbent)
        internal
        pure
        returns (bool)
    {
        if (shares == 0) return true;
        if (delivered == 0 || supply == 0 || incumbent == 0) return false;
        return FullMath.mulDiv(delivered, supply, shares) >= incumbent;
    }

    function min3(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 m) {
        m = a;
        if (b < m) m = b;
        if (c < m) m = c;
    }
}
