// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

library DualLiquidityLinkedCrossVersionUniswapVaultMathLib {
    /// @notice Shares minted for BPT deposited, quoted BEFORE the BPT enters the reserve.
    /// @dev 1:1 genesis only when **both** `totalShares_ == 0` and `totalBpt_ == 0`. If the diamond
    ///      already holds idle `reserveBpt` with no shares (`SEC-DETF-DL-004` / A0), 1:1 would grant
    ///      the first minter the donated inventory. Callers must lock that idle BPT as dead shares
    ///      (see Common `_lockIdleReserveAsDeadShares`) so this function sees a positive supply and
    ///      mints pro-rata. `totalBpt_ == 0` with leftover shares no longer reprints 1:1.
    function _sharesForBpt(uint256 bptIn_, uint256 totalShares_, uint256 totalBpt_)
        internal
        pure
        returns (uint256 shares_)
    {
        if (totalShares_ == 0 && totalBpt_ == 0) {
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
