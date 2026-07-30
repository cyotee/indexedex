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

    function lastExpansionTimestamp() external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().lastExpansionTimestamp;
    }

    function expansionClosureRatePerSecond() external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().expansionClosureRatePerSecond;
    }

    function expansionCatchUpMaxSeconds() external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().expansionCatchUpMaxSeconds;
    }

    function expansionCatchUpCapBps() external view returns (uint256) {
        return MixedBufferMultiVaultStableDetfRepo._layoutStruct().expansionCatchUpCapBps;
    }

    /// @inheritdoc IMixedBufferMultiVaultStableDetfInfo
    function compoundProtocolRewards() external nonReentrant returns (uint256 detfIn, uint256 bptOut) {
        return _tryCompoundProtocolRewards();
    }
}
