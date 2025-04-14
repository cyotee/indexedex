// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {VaultRegistryVaultRepo} from "contracts/registries/vault/VaultRegistryVaultRepo.sol";

abstract contract VaultRegistryVaultQueryTarget is IVaultRegistryVaultQuery {
    using BetterAddress for address[];
    using BetterEfficientHashLib for bytes;

    /**
     * @notice Returns ALL the deployed vaults and pools.
     * @dev NOT intended for on-chain usage, but is allowed.
     * @return vaults_ - An array of all deployed vaults and pools.
     */
    function vaults() public view returns (address[] memory vaults_) {
        return VaultRegistryVaultRepo._vaults();
    }

    /**
     * @notice Checks if a given address is a deployed vault or pool.
     * @param vault - The address to check.
     * @return True if the address is a deployed vault or pool, false otherwise.
     */
    function isVault(address vault) public view returns (bool) {
        return VaultRegistryVaultRepo._isVault(vault);
    }

    /**
     * @notice Returns ALL tokens contained across ALL vault and pools.
     * @dev NOT intended for on-chain usage, but is allowed.
     * @return tokens_ - An array of all contained tokens.
     */
    function vaultTokens() public view returns (address[] memory tokens_) {
        return VaultRegistryVaultRepo._vaultTokens();
    }

    /**
     * @notice Checks if a given address is a contained token across ALL vault and pools.
     * @param token - The address to check.
     * @return True if the address is a contained token, false otherwise.
     */
    function isContainedToken(address token) public view returns (bool) {
        return VaultRegistryVaultRepo._isContainedToken(token);
    }

    /**
     * @notice Returns ALL vaults that contain a given token.
     * @param token - The address of the token to check.
     * @return vaultsOfToken_ - An array of all vaults that contain the given token.
     */
    function vaultsOfToken(address token) public view returns (address[] memory vaultsOfToken_) {
        return VaultRegistryVaultRepo._vaultsOfToken(token);
    }

    /**
     * @notice Returns ALL vaults that contain a given array of tokens.
     * @notice Will sort in ascending order and hash array as contents ID.
     * @param tokens_ - The array of tokens to check.
     * @return vaultsOfTokens_ - An array of all vaults that contain the given tokens.
     */
    function vaultsOfTokens(address[] memory tokens_) public view returns (address[] memory vaultsOfTokens_) {
        return VaultRegistryVaultRepo._vaultsOfContentsId(abi.encode(tokens_._sort())._hash());
    }

    /**
     * @notice Calculates the contents ID of a given array of tokens.
     * @notice Contents ID is the hash of the tokens contained in a vault.
     * @notice Ensure tokens were sorted in ascending order before hashing.
     * @param tokens_ - The array of tokens to check.
     * @return contentsId - The contents ID of the given tokens.
     */
    function calcContentsId(address[] memory tokens_)
        public
        pure
        returns (
            /// forge-lint: disable-next-line(mixed-case-variable)
            bytes32 contentsId
        )
    {
        // return keccak256(abi.encode(tokens_._sort()));
        return abi.encode(tokens_._sort())._hash();
    }

    /**
     * @notice Returns ALL registered contents IDs of ALL vaults.
     * @notice Contents ID is the hash of the tokens contained in a vault.
     * @notice Ensure tokens were sorted in ascending order before hashing.
     * @return contentsIds_ - An array of all registered contents IDs.
     */
    function contentsIds() public view returns (bytes32[] memory contentsIds_) {
        return VaultRegistryVaultRepo._contentsIds();
    }

    /**
     * @notice Returns ALL vaults that contain a given contents ID.
     * @notice Contents ID is the hash of the tokens contained in a vault.
     * @notice Ensure tokens were sorted in ascending order before hashing.
     * @param contentsHash - The hash of the tokens to check.
     * @return vaultsOfContentsId_ - An array of all vaults that contain the given contents ID.
     */
    /// forge-lint: disable-next-line(mixed-case-function)
    function vaultsOfContentsId(bytes32 contentsHash)
        public
        view
        returns (
            /// forge-lint: disable-next-line(mixed-case-variable)
            address[] memory vaultsOfContentsId_
        )
    {
        return VaultRegistryVaultRepo._vaultsOfContentsId(contentsHash);
    }

    /**
     * @notice Returns ALL vaults of a given type.
     * @notice Type is the ERC165 interface ID of a vault.
     * @notice Vaults will typically be of many types.
     * @param vaultTypeId - The type of vault to return.
     * @return vaultsOfType_ - An array of all vaults of the given type.
     */
    function vaultsOfType(bytes4 vaultTypeId) public view returns (address[] memory vaultsOfType_) {
        return VaultRegistryVaultRepo._vaultsOfType(vaultTypeId);
    }

    /**
     * @notice Returns ALL vaults of a given type that contain a given token.
     * @param vaultTypeId - The type of vault to return.
     * @param token - The address of the token to check.
     * @return vaults_ - An array of all vaults of the given type that contain the given token.
     */
    function vaultsOfTypeOfToken(bytes4 vaultTypeId, address token) public view returns (address[] memory vaults_) {
        return VaultRegistryVaultRepo._vaultsOfTokenOfTypeId(vaultTypeId, token);
    }

    /**
     * @notice Returns ALL vaults of a given type that contain a given array of tokens.
     * @notice Will sort in ascending order and hash array as contents ID.
     * @param vaultTypeId - The type of vault to return.
     * @param tokens_ - The array of tokens to check.
     * @return vaults_ - An array of all vaults of the given type that contain the given tokens.
     */
    function vaultsOfTypeOfTokens(bytes4 vaultTypeId, address[] memory tokens_)
        public
        view
        returns (address[] memory vaults_)
    {
        return VaultRegistryVaultRepo._vaultsOfContentsIdOfTypeId(vaultTypeId, abi.encode(tokens_._sort())._hash());
    }

    /**
     * @notice Returns ALL vaults of a given type that contain a given contents ID.
     * @notice Contents ID is the hash of the tokens contained in a vault.
     * @notice Ensure tokens were sorted in ascending order before hashing.
     * @param vaultTypeId - The type of vault to return.
     * @param contentsHash - The hash of the tokens to check.
     * @return vaults_ - An array of all vaults of the given type that contain the given contents ID.
     */
    /// forge-lint: disable-next-line(mixed-case-function)
    function vaultsOfTypeOfContentsId(bytes4 vaultTypeId, bytes32 contentsHash)
        public
        view
        returns (address[] memory vaults_)
    {
        return VaultRegistryVaultRepo._vaultsOfContentsIdOfTypeId(vaultTypeId, contentsHash);
    }

    /**
     * @notice Returns ALL vaults of a given package.
     * @param pkg - The address of the package to check.
     * @return vaults_ - An array of all vaults of the given package.
     */
    function vaultsOfPackage(address pkg) public view returns (address[] memory vaults_) {
        return VaultRegistryVaultRepo._vaultsOfPkg(pkg);
    }

    /**
     * @notice Returns ALL vaults of a given package that contain a given token.
     * @param pkg - The address of the package to check.
     * @param token - The address of the token to check.
     * @return vaults_ - An array of all vaults of the given package that contain the given token.
     */
    function vaultsOfPkgOfToken(address pkg, address token) public view returns (address[] memory vaults_) {
        return VaultRegistryVaultRepo._vaultsOfTokenOfPkg(pkg, token);
    }

    /**
     * @notice Returns ALL vaults of a given package that contain a given array of tokens.
     * @notice Will sort in ascending order and hash array as contents ID.
     * @param pkg - The address of the package to check.
     * @param tokens_ - The array of tokens to check.
     * @return vaults_ - An array of all vaults of the given package that contain the given tokens.
     */
    function vaultsOfPkgOfTokens(address pkg, address[] memory tokens_) public view returns (address[] memory vaults_) {
        return VaultRegistryVaultRepo._vaultsOfContentsIdOfPkg(pkg, abi.encode(tokens_._sort())._hash());
    }

    /**
     * @notice Returns ALL vaults of a given package that contain a given contents ID.
     * @notice Contents ID is the hash of the tokens contained in a vault.
     * @notice Ensure tokens were sorted in ascending order before hashing.
     * @param pkg - The address of the package to check.
     * @param contentsHash - The hash of the tokens to check.
     * @return vaults_ - An array of all vaults of the given package that contain the given contents ID.
     */
    /// forge-lint: disable-next-line(mixed-case-function)
    function vaultsOfPkgOfContentsId(address pkg, bytes32 contentsHash) public view returns (address[] memory vaults_) {
        return VaultRegistryVaultRepo._vaultsOfContentsIdOfPkg(pkg, contentsHash);
    }

    function vaultUsageFeeTypeId(address vault) external view returns (bytes4 vaultUsageFeeTypeId_) {
        return VaultRegistryVaultRepo._usageFeeIdOfVault(vault);
    }

    function vaultDexTermsTypeId(address vault) external view returns (bytes4 vaultDexTermsTypeId_) {
        return VaultRegistryVaultRepo._dexFeeIdOfVault(vault);
    }

    function vaultBondTermsTypeId(address vault) external view returns (bytes4 vaultBondTermsTypeId_) {
        return VaultRegistryVaultRepo._bondFeeIdOfVault(vault);
    }

    function seeigniorageTermsTypeId(address vault) external view returns (bytes4 vaultSeigniorageTermsTypeId_) {
        return VaultRegistryVaultRepo._seigniorageIncentiveIdOfVault(vault);
    }

    function vaultLendingTermsTypeId(address vault) external view returns (bytes4 vaultLendingTermsTypeId_) {
        return VaultRegistryVaultRepo._lendingFeeIdOfVault(vault);
    }
}
