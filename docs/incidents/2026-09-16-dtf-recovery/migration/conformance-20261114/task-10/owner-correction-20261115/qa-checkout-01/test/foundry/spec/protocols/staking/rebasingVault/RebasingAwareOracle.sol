// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Independent ACC-03 oracle. Does not import Common, BetterMath, or wrapper previews.
library RebasingAwareOracle {
    function mulDivFloor(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        require(d != 0, "oracle-div0");
        return (x * y) / d;
    }

    function mulDivCeil(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        require(d != 0, "oracle-div0");
        uint256 q = (x * y) / d;
        if ((x * y) % d == 0) return q;
        return q + 1;
    }

    function sharesForDeposit(uint256 assets, uint256 A, uint256 S, uint256 V)
        internal
        pure
        returns (uint256)
    {
        return mulDivFloor(assets, S + V, A + 1);
    }

    function assetsForMint(uint256 shares, uint256 A, uint256 S, uint256 V)
        internal
        pure
        returns (uint256)
    {
        return mulDivCeil(shares, A + 1, S + V);
    }

    function assetsForRedeem(uint256 shares, uint256 A, uint256 S, uint256 V)
        internal
        pure
        returns (uint256)
    {
        return mulDivFloor(shares, A + 1, S + V);
    }

    function sharesForWithdraw(uint256 assets, uint256 A, uint256 S, uint256 V)
        internal
        pure
        returns (uint256)
    {
        return mulDivCeil(assets, S + V, A + 1);
    }

    function wadRate(uint256 A, uint256 S, uint256 V) internal pure returns (uint256) {
        return mulDivFloor(1e18, A + 1, S + V);
    }
}
