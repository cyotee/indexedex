// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    SingleStandardExchangeDETFCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

interface ISingleStandardExchangeDETFInfo {
    /// @notice Emitted once at init with resolved mint/burn thresholds (PRD §16.4).
    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);

    // ProtocolRewardsCompounded is declared on SingleStandardExchangeDETFCommon (emitted by compound path).

    function isReserveLive() external view returns (bool);
    function standardExchangeVault() external view returns (address);
    function standardExchangeVaultShare() external view returns (address);
    function rateTarget() external view returns (address);
    function reservePool() external view returns (address);
    function syntheticPrice() external view returns (uint256);
    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function thresholdMode() external view returns (ThresholdMode);
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);
    function bondNftVault() external view returns (address);
    function rebasingClaimToken() external view returns (address);

    /// @notice Last timestamp at which expansion mint advanced the accrual clock (0 if never live).
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

abstract contract SingleStandardExchangeDETFInfoTarget is
    SingleStandardExchangeDETFCommon,
    ISingleStandardExchangeDETFInfo
{
    function isReserveLive() external view returns (bool) {
        return SingleStandardExchangeDETFRepo._layoutStruct().isReserveLive;
    }

    function standardExchangeVault() external view returns (address) {
        return address(SingleStandardExchangeDETFRepo._layoutStruct().standardExchangeVault);
    }

    function standardExchangeVaultShare() external view returns (address) {
        return address(SingleStandardExchangeDETFRepo._layoutStruct().standardExchangeVaultShare);
    }

    function rateTarget() external view returns (address) {
        return address(SingleStandardExchangeDETFRepo._layoutStruct().rateTarget);
    }

    function reservePool() external view returns (address) {
        return SingleStandardExchangeDETFRepo._layoutStruct().reservePool;
    }

    function syntheticPrice() external view returns (uint256) {
        return _syntheticPrice();
    }

    function mintThreshold() external view returns (uint256) {
        return SingleStandardExchangeDETFRepo._layoutStruct().mintThreshold;
    }

    function burnThreshold() external view returns (uint256) {
        return SingleStandardExchangeDETFRepo._layoutStruct().burnThreshold;
    }

    function thresholdMode() external view returns (ThresholdMode) {
        return SingleStandardExchangeDETFRepo._layoutStruct().thresholdMode;
    }

    function isMintingAllowed() external view returns (bool) {
        return _isMintingAllowed();
    }

    function isBurningAllowed() external view returns (bool) {
        return _isBurningAllowed();
    }

    function bondNftVault() external view returns (address) {
        return address(SingleStandardExchangeDETFRepo._layoutStruct().bondNftVault);
    }

    function rebasingClaimToken() external view returns (address) {
        return address(SingleStandardExchangeDETFRepo._layoutStruct().rebasingClaimToken);
    }

    function lastExpansionTimestamp() external view returns (uint256) {
        return SingleStandardExchangeDETFRepo._layoutStruct().lastExpansionTimestamp;
    }

    function expansionClosureRatePerSecond() external view returns (uint256) {
        return SingleStandardExchangeDETFRepo._layoutStruct().expansionClosureRatePerSecond;
    }

    function expansionCatchUpMaxSeconds() external view returns (uint256) {
        return SingleStandardExchangeDETFRepo._layoutStruct().expansionCatchUpMaxSeconds;
    }

    function expansionCatchUpCapBps() external view returns (uint256) {
        return SingleStandardExchangeDETFRepo._layoutStruct().expansionCatchUpCapBps;
    }

    /// @inheritdoc ISingleStandardExchangeDETFInfo
    function compoundProtocolRewards() external nonReentrant returns (uint256 detfIn, uint256 bptOut) {
        return _tryCompoundProtocolRewards();
    }
}
