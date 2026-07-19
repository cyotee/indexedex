// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @title InvariantAssertLib
/// @notice Shared property/invariant assertions for L1–L3 suites (Wave 0).
/// @dev Prefer production SUT balances; do not mock vaults. Residual checks ignore intentional
///      reserve BPT held on the diamond — only free product/share inventory is flagged.
library InvariantAssertLib {
    /// @notice Cross-multiply: a/b >= c/d  <=>  a*d >= c*b (zero-safe).
    function claimRatioGte(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (bool) {
        if (b == 0 || d == 0) return true;
        return a * d >= c * b;
    }

    /// @notice Pro-rata claim of `shares` against `reserve` with total `supply`.
    function proRataClaim(uint256 shares, uint256 supply, uint256 reserve) internal pure returns (uint256) {
        if (supply == 0 || shares == 0) return 0;
        return (shares * reserve) / supply;
    }

    /// @notice Aggregate claims of holders must not exceed reserve (flooring dust ≤ holders.length).
    function assertAggregateClaimsLeReserve(
        address[] memory holders_,
        IERC20 shareToken_,
        uint256 supply_,
        uint256 reserve_
    ) internal view {
        if (supply_ == 0) return;
        uint256 claimed_;
        for (uint256 i; i < holders_.length; ++i) {
            uint256 s_ = shareToken_.balanceOf(holders_[i]);
            if (s_ > 0) claimed_ += proRataClaim(s_, supply_, reserve_);
        }
        require(claimed_ <= reserve_, "P-PRORATA: aggregate claims > reserve");
    }

    /// @notice Product token + listed share tokens must not sit free on the instance.
    function assertNoFreeProductInventory(address instance_, IERC20[] memory shareTokens_) internal view {
        require(IERC20(instance_).balanceOf(instance_) == 0, "P-RESID: residual free product token");
        for (uint256 i; i < shareTokens_.length; ++i) {
            require(shareTokens_[i].balanceOf(instance_) == 0, "P-RESID: residual free vault/share token");
        }
    }

    /// @notice Single share residual + product residual.
    function assertNoFreeShare(address instance_, IERC20 share_) internal view {
        require(share_.balanceOf(instance_) == 0, "P-RESID: residual free share");
        require(IERC20(instance_).balanceOf(instance_) == 0, "P-RESID: residual free product");
    }

    /// @notice Dust-bounded residual (e.g. one-wei router leftovers).
    function assertResidualBounded(address token_, address holder_, uint256 maxDust_) internal view {
        require(IERC20(token_).balanceOf(holder_) <= maxDust_, "P-RESID: residual exceeds dust bound");
    }
}
