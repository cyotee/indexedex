// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

library DualLiquidityLinkedCrossVersionUniswapVaultMathLib {
    /// @notice Shares minted for BPT deposited, quoted BEFORE the BPT enters the reserve.
    /// @dev First deposit into an empty vault (no shares or no reserve BPT yet) mints 1:1, which both
    ///      guards the division and sets the genesis share:BPT ratio at unity. Balancer already locks
    ///      minimum liquidity when the reserve pool is initialized, so no extra dust lock is needed here.
    function _sharesForBpt(uint256 bptIn_, uint256 totalShares_, uint256 totalBpt_)
        internal
        pure
        returns (uint256 shares_)
    {
        if (totalShares_ == 0 || totalBpt_ == 0) {
            return bptIn_;
        }
        shares_ = Math.mulDiv(bptIn_, totalShares_, totalBpt_);
    }

    /// @notice BPT owed for shares burned, quoted BEFORE the shares are burned.
    function _bptForShares(uint256 sharesIn_, uint256 totalShares_, uint256 totalBpt_)
        internal
        pure
        returns (uint256 bpt_)
    {
        bpt_ = Math.mulDiv(sharesIn_, totalBpt_, totalShares_);
    }
}
