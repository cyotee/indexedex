// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ThresholdMode} from 'contracts/vaults/detf/common/core/DETFThresholdPolicy.sol';

/// @notice MUST threshold-mode surface for ComposedStableCommonDetf (PRD §4.5).
interface IComposedStableCommonDetfInfo {
    /// @notice Emitted once at init with resolved mint/burn thresholds (PRD §16.4).
    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);

    // ProtocolRewardsCompounded is declared on ComposedStableCommonDetfCommon (emitted by compound path).

    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function thresholdMode() external view returns (ThresholdMode);
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);

    /// @notice Last timestamp at which expansion mint advanced the accrual clock (0 if never live-touched).
    function lastExpansionTimestamp() external view returns (uint256);

    /// @notice Resolved deploy-time expansion closure rate per second (1e18 fixed point).
    function expansionClosureRatePerSecond() external view returns (uint256);

    /// @notice Resolved deploy-time expansion catch-up max seconds.
    function expansionCatchUpMaxSeconds() external view returns (uint256);

    /// @notice Resolved deploy-time expansion catch-up cap in bps of totalSupply.
    function expansionCatchUpCapBps() external view returns (uint256);

    /// @notice Update expansion + bond rewards and attempt detf-NFT reward → single-sided DETF join → BPT to detf NFT.
    /// @dev Required public surface (PRD Phase 1 + Phase 2 expansion catch-up). Permissionless; no keeper.
    ///      Best-effort: returns (0,0) when nothing to compound or join fails (pending left intact).
    function compoundProtocolRewards() external returns (uint256 detfIn, uint256 bptOut);
}
