// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Deploy-time primary-market gate mode (PRD DETF_Threshold_Modes).
enum ThresholdMode {
    Policy, // 0 — default; deadband gates
    Open // 1 — threshold gates always pass; live still enforced by family
}

error InvalidThresholdPair(uint256 mintThreshold, uint256 burnThreshold);
error InvalidThresholdMode(uint8 mode);

/// @notice Shared mint/burn threshold resolve + Policy/Open gate helpers for true DETFs.
/// @dev Families must not reimplement defaults or Open short-circuit. Live/inert stays in the family.
library DETFThresholdPolicy {
    uint256 internal constant DEFAULT_MINT_THRESHOLD = 1.05e18;
    uint256 internal constant DEFAULT_BURN_THRESHOLD = 0.95e18;

    //--------------------------------------------------------------------------
    // Resolve
    //--------------------------------------------------------------------------

    /// @notice Map PkgArgs zeros to defaults. Mode-agnostic. Does not validate mint > burn.
    function resolveThresholds(uint256 mintArg_, uint256 burnArg_)
        internal
        pure
        returns (uint256 mintThreshold_, uint256 burnThreshold_)
    {
        mintThreshold_ = mintArg_ == 0 ? DEFAULT_MINT_THRESHOLD : mintArg_;
        burnThreshold_ = burnArg_ == 0 ? DEFAULT_BURN_THRESHOLD : burnArg_;
    }

    //--------------------------------------------------------------------------
    // Validation
    //--------------------------------------------------------------------------

    /// @notice True if raw mode is Policy (0) or Open (1) only.
    /// @dev Takes `uint8` so out-of-range values can be checked without Solidity's
    /// enum conversion panic (0x21). Typed `ThresholdMode` overloads below.
    function isValidThresholdMode(uint8 mode_) internal pure returns (bool) {
        return mode_ <= uint8(ThresholdMode.Open);
    }

    /// @notice True if mode is Policy or Open only.
    function isValidThresholdMode(ThresholdMode mode_) internal pure returns (bool) {
        return isValidThresholdMode(uint8(mode_));
    }

    /// @notice After resolve: Policy and Open both require mintThreshold > burnThreshold.
    function isValidThresholdPair(uint256 mintThreshold_, uint256 burnThreshold_)
        internal
        pure
        returns (bool)
    {
        return mintThreshold_ > burnThreshold_;
    }

    /// @notice Resolve zeros then require mint > burn.
    function resolveAndRequireValidThresholds(uint256 mintArg_, uint256 burnArg_)
        internal
        pure
        returns (uint256 mintThreshold_, uint256 burnThreshold_)
    {
        (mintThreshold_, burnThreshold_) = resolveThresholds(mintArg_, burnArg_);
        if (mintThreshold_ <= burnThreshold_) {
            revert InvalidThresholdPair(mintThreshold_, burnThreshold_);
        }
    }

    /// @notice Revert unless raw mode is Policy or Open.
    function requireValidThresholdMode(uint8 mode_) internal pure {
        if (!isValidThresholdMode(mode_)) {
            revert InvalidThresholdMode(mode_);
        }
    }

    /// @notice Revert unless mode is Policy or Open.
    function requireValidThresholdMode(ThresholdMode mode_) internal pure {
        requireValidThresholdMode(uint8(mode_));
    }

    //--------------------------------------------------------------------------
    // Mode-aware allow (primary API — no live param)
    //--------------------------------------------------------------------------

    /// @dev No live flag. Open → true. Policy → strict >.
    function _isMintingAllowed(ThresholdMode mode_, uint256 mintThreshold_, uint256 price_)
        internal
        pure
        returns (bool allowed_)
    {
        if (mode_ == ThresholdMode.Open) return true;
        allowed_ = price_ > mintThreshold_;
    }

    /// @dev No live flag. Open → true. Policy → strict <.
    function _isBurningAllowed(ThresholdMode mode_, uint256 burnThreshold_, uint256 price_)
        internal
        pure
        returns (bool allowed_)
    {
        if (mode_ == ThresholdMode.Open) return true;
        allowed_ = price_ < burnThreshold_;
    }

    /// @notice True when mode is product Open.
    function _isOpenMode(ThresholdMode mode_) internal pure returns (bool) {
        return mode_ == ThresholdMode.Open;
    }

    //--------------------------------------------------------------------------
    // Backward-compatible 2-arg wrappers (Policy-only)
    //--------------------------------------------------------------------------

    /// @notice Policy-only wrapper (legacy). Prefer 3-arg form with explicit mode.
    function _isMintingAllowed(uint256 threshold_, uint256 price_)
        internal
        pure
        returns (bool allowed_)
    {
        allowed_ = _isMintingAllowed(ThresholdMode.Policy, threshold_, price_);
    }

    /// @notice Policy-only wrapper (legacy). Prefer 3-arg form with explicit mode.
    function _isBurningAllowed(uint256 threshold_, uint256 price_)
        internal
        pure
        returns (bool allowed_)
    {
        allowed_ = _isBurningAllowed(ThresholdMode.Policy, threshold_, price_);
    }
}
