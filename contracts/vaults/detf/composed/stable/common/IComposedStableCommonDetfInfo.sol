// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ThresholdMode} from 'contracts/vaults/detf/core/DETFThresholdPolicy.sol';

/// @notice MUST threshold-mode surface for ComposedStableCommonDetf (PRD §4.5).
interface IComposedStableCommonDetfInfo {
    /// @notice Emitted once at init with resolved mint/burn thresholds (PRD §16.4).
    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);

    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function thresholdMode() external view returns (ThresholdMode);
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);
}
