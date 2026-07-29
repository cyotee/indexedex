// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";
import {
    MixedBufferMultiVaultStableDetfCommon
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

interface IMixedBufferMultiVaultStableDetfInfo {
    /// @notice Emitted once at init with resolved mint/burn thresholds (PRD §16.4).
    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);

    function isReserveLive() external view returns (bool);
    function vaultCount() external view returns (uint256);
    function underlyingVaults() external view returns (address[] memory);
    function vaultShares() external view returns (address[] memory);
    function bufferToken() external view returns (address);
    function amplificationParameter() external view returns (uint256);
    function rateProvider(uint256 i) external view returns (address);
    function reservePool() external view returns (address);
    function syntheticPrice() external view returns (uint256);
    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function thresholdMode() external view returns (ThresholdMode);
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);
    function bondNftVault() external view returns (address);
    function rebasingClaimToken() external view returns (address);
    function detfIndex() external view returns (uint256);
    function bufferIndex() external view returns (uint256);
    function shareIndex(uint256 i) external view returns (uint256);
}

abstract contract MixedBufferMultiVaultStableDetfInfoTarget is
    MixedBufferMultiVaultStableDetfCommon,
    IMixedBufferMultiVaultStableDetfInfo
{
    function isReserveLive() external view returns (bool) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().isReserveLive;
    }

    function vaultCount() external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().vaultCount;
    }

    function underlyingVaults() external view returns (address[] memory out_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        out_ = new address[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            out_[i] = address(s.underlyingVaults[i]);
        }
    }

    function vaultShares() external view returns (address[] memory out_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        out_ = new address[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            out_[i] = address(s.vaultShares[i]);
        }
    }

    function bufferToken() external view returns (address) {
        return address(MixedBufferMultiVaultStableDetfRepo._layoutStruct().bufferToken);
    }

    function amplificationParameter() external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().amplificationParameter;
    }

    function rateProvider(uint256 i) external view returns (address) {
        return address(MixedBufferMultiVaultStableDetfRepo._layoutStruct().vaultShareRateProviders[i]);
    }

    function reservePool() external view returns (address) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().reservePool;
    }

    function syntheticPrice() external view returns (uint256) {
        return _syntheticPrice();
    }

    function mintThreshold() external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().mintThreshold;
    }

    function burnThreshold() external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().burnThreshold;
    }

    function thresholdMode() external view returns (ThresholdMode) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().thresholdMode;
    }

    function isMintingAllowed() external view returns (bool) {
        return _isMintingAllowed();
    }

    function isBurningAllowed() external view returns (bool) {
        return _isBurningAllowed();
    }

    function bondNftVault() external view returns (address) {
        return address(MixedBufferMultiVaultStableDetfRepo._layoutStruct().bondNftVault);
    }

    function rebasingClaimToken() external view returns (address) {
        return address(MixedBufferMultiVaultStableDetfRepo._layoutStruct().rebasingClaimToken);
    }

    function detfIndex() external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().detfIndex;
    }

    function bufferIndex() external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().bufferIndex;
    }

    function shareIndex(uint256 i) external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().shareIndexes[i];
    }
}
