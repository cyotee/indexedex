// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";
import {SingleVaultDetfCommon} from "contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";

/// @notice Family info surface for threshold mode (PRD DETF_Threshold_Modes).
/// @dev Canonical typed surface is `IProtocolDETF.thresholdMode()`; this interface
///      also exposes the getter for family casts and holds the init event.
interface ISingleVaultDetfInfo {
    /// @notice Emitted once at init with resolved mint/burn thresholds.
    event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);

    /// @notice Same selector as `IProtocolDETF.thresholdMode()`.
    function thresholdMode() external view returns (ThresholdMode);
}

contract SingleVaultDetfInfoTarget is SingleVaultDetfCommon, ISingleVaultDetfInfo {
    function detfToken() external view returns (IERC20MintBurn) {
        return IERC20MintBurn(address(this));
    }

    function pairToken() external view returns (IERC20) {
        return SingleVaultDetfRepo._pairToken();
    }

    function rebasingClaimToken() external view returns (IERC20) {
        return IERC20(address(SingleVaultDetfRepo._rebasingClaimToken()));
    }

    function rateAsset() external view returns (IERC20) {
        return SingleVaultDetfRepo._rateAsset();
    }

    function detfNFTVault() external view returns (IDETFNFTVault) {
        return SingleVaultDetfRepo._detfNFTVault();
    }

    function underlyingVault() external view returns (IStandardExchange) {
        return SingleVaultDetfRepo._underlyingVault();
    }

    function reservePool() external view returns (address) {
        return SingleVaultDetfRepo._reservePool();
    }

    function detfNFTId() external view returns (uint256) {
        return SingleVaultDetfRepo._detfNFTId();
    }

    function syntheticPrice() public view returns (uint256) {
        return _calcSyntheticPrice();
    }

    function mintThreshold() external view returns (uint256) {
        return SingleVaultDetfRepo._layoutStruct().mintThreshold;
    }

    function burnThreshold() external view returns (uint256) {
        return SingleVaultDetfRepo._layoutStruct().burnThreshold;
    }

    function thresholdMode() external view returns (ThresholdMode) {
        return SingleVaultDetfRepo._thresholdMode();
    }

    function isMintingAllowed() external view returns (bool allowed_) {
        return _isMintingAllowed(SingleVaultDetfRepo._layoutStruct());
    }

    function isBurningAllowed() external view returns (bool allowed_) {
        return _isBurningAllowed(SingleVaultDetfRepo._layoutStruct());
    }

    function vaultRateProvider() external view returns (IRateProvider) {
        return SingleVaultDetfRepo._vaultRateProvider();
    }

    function reservePoolIndexes() external view returns (uint256 detfIndex_, uint256 vaultTokenIndex_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        detfIndex_ = layoutStruct.detfIndex;
        vaultTokenIndex_ = layoutStruct.vaultTokenIndex;
    }
}
