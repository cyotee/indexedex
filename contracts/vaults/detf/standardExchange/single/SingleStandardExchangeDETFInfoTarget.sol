// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";
import {
    SingleStandardExchangeDETFCommon
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFCommon.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

interface ISingleStandardExchangeDETFInfo {
    /// @notice Emitted once at init with resolved mint/burn thresholds (PRD §16.4).
    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);

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
}
