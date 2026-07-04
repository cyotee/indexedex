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
import {SingleVaultDetfCommon} from "contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";

contract SingleVaultDetfInfoTarget is SingleVaultDetfCommon {
    function detfToken() external view returns (IERC20MintBurn) {
        return IERC20MintBurn(address(this));
    }

    function richToken() external view returns (IERC20) {
        return SingleVaultDetfRepo._richToken();
    }

    function richirToken() external view returns (IERC20) {
        return IERC20(address(SingleVaultDetfRepo._richirToken()));
    }

    function wethToken() external view returns (IERC20) {
        return SingleVaultDetfRepo._wethToken();
    }

    function detfNFTVault() external view returns (IDETFNFTVault) {
        return SingleVaultDetfRepo._detfNFTVault();
    }

    function chirWethVault() external view returns (IStandardExchange) {
        return SingleVaultDetfRepo._wethRichVault();
    }

    function richChirVault() external view returns (IStandardExchange) {
        return SingleVaultDetfRepo._wethRichVault();
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

    function isMintingAllowed() external view returns (bool allowed_) {
        return _isMintingAllowed(SingleVaultDetfRepo._layoutStruct(), _calcReserveSpotPrice());
    }

    function isBurningAllowed() external view returns (bool allowed_) {
        return _isBurningAllowed(SingleVaultDetfRepo._layoutStruct(), _calcReserveSpotPrice());
    }

    function wethRichVault() external view returns (IStandardExchange) {
        return SingleVaultDetfRepo._wethRichVault();
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