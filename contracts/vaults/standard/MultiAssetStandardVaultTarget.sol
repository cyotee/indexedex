// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";

/**
 * @title MultiAssetStandardVaultTarget
 * @notice Domain logic for multi-asset standard vault surface (Repo-backed).
 */
contract MultiAssetStandardVaultTarget is IStandardVault {
    function vaultFeeTypeIds() public view returns (bytes32 vaultFeeTypeIds_) {
        return StandardVaultRepo._vaultFeeTypeIds();
    }

    function contentsId() external view returns (bytes32 contentsId_) {
        return StandardVaultRepo._contentsId();
    }

    function vaultTypes() public view returns (bytes4[] memory vaultTypes_) {
        return StandardVaultRepo._vaultTypes();
    }

    function vaultConfig() public view returns (VaultConfig memory vaultConfig_) {
        StandardVaultRepo.Storage storage standardVaultStorage = StandardVaultRepo._layout();
        vaultConfig_ = IStandardVault.VaultConfig({
            vaultFeeTypeIds: StandardVaultRepo._vaultFeeTypeIds(standardVaultStorage),
            contentsId: StandardVaultRepo._contentsId(standardVaultStorage),
            vaultTypes: StandardVaultRepo._vaultTypes(standardVaultStorage),
            tokens: MultiAssetBasicVaultRepo._vaultTokens()
        });
    }
}
