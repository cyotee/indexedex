// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryEvents} from "contracts/interfaces/IVaultRegistryEvents.sol";

/**
 * @title IVaultRegistryQuery - Interface for querying deployed vaults and pools.
 * @author cyotee doge <doge.cyotee>
 * @notice This registry considers liquidity pools to be a type of vault.
 * @custom:interfaceid
 */
interface IVaultRegistryVaultQuery is IVaultRegistryEvents {
    /**
     * @notice Returns ALL the deployed vaults and pools.
     * @dev NOT intended for on-chain usage, but is allowed.
     * @return vaults_ - An array of all deployed vaults and pools.
     * @custom:selector 0x8220ef5b
     */
    function vaults() external view returns (address[] memory vaults_);

    /**
     * @notice Checks if a given address is a deployed vault or pool.
     * @param vault - The address to check.
     * @return True if the address is a deployed vault or pool, false otherwise.
     * @custom:selector 0x652b9b41
     */
    function isVault(address vault) external view returns (bool);

    /**
     * @notice Returns ALL tokens contained across ALL vault and pools.
     * @dev NOT intended for on-chain usage, but is allowed.
     * @return tokens_ - An array of all contained tokens.
     * @custom:selector
     */
    function vaultTokens() external view returns (address[] memory tokens_);

    /**
     * @notice Checks if a given address is a contained token across ALL vault and pools.
     * @param token - The address to check.
     * @return True if the address is a contained token, false otherwise.
     * @custom:selector 0xa6558759
     */
    function isContainedToken(address token) external view returns (bool);

    /**
     * @notice Returns ALL vaults that contain a given token.
     * @param token - The address of the token to check.
     * @return vaultsOfToken_ - An array of all vaults that contain the given token.
     * @custom:selector 0x2b9fc930
     */
    function vaultsOfToken(address token) external view returns (address[] memory vaultsOfToken_);

    /**
     * @notice Returns ALL vaults that contain a given array of tokens.
     * @notice Will sort in ascending order and hash array as contents ID.
     * @param tokens_ - The array of tokens to check.
     * @return vaultsOfTokens_ - An array of all vaults that contain the given tokens.
     * @custom:selector 0x25d6a19d
     */
    function vaultsOfTokens(address[] memory tokens_) external view returns (address[] memory vaultsOfTokens_);

    /**
     * @notice Calculates the contents ID of a given array of tokens.
     * @notice Contents ID is the hash of the tokens contained in a vault.
     * @notice Ensure tokens were sorted in ascending order before hashing.
     * @param tokens_ - The array of tokens to check.
     * @return contentsID - The contents ID of the given tokens.
     * @custom:selector 0x396d8457
     */
    function calcContentsId(address[] memory tokens_)
        external
        pure
        returns (
            /// forge-lint: disable-next-line(mixed-case-variable)
            bytes32 contentsID
        );

    /**
     * @notice Returns ALL registered contents IDs of ALL vaults.
     * @notice Contents ID is the hash of the tokens contained in a vault.
     * @notice Ensure tokens were sorted in ascending order before hashing.
     * @return contentsIds_ - An array of all registered contents IDs.
     * @custom:selector 0x73dee313
     */
    function contentsIds() external view returns (bytes32[] memory contentsIds_);

    /**
     * @notice Returns ALL vaults that contain a given contents ID.
     * @notice Contents ID is the hash of the tokens contained in a vault.
     * @notice Ensure tokens were sorted in ascending order before hashing.
     * @param contentsHash - The hash of the tokens to check.
     * @return vaultsOfContentsId_ - An array of all vaults that contain the given contents ID.
     * @custom:selector 0x9452ecaa
     */
    /// forge-lint: disable-next-line(mixed-case-function)
    function vaultsOfContentsId(bytes32 contentsHash)
        external
        view
        returns (
            /// forge-lint: disable-next-line(mixed-case-variable)
            address[] memory vaultsOfContentsId_
        );

    /**
     * @notice Returns ALL vaults of a given type.
     * @notice Type is the ERC165 interface ID of a vault.
     * @notice Vaults will typically be of many types.
     * @param vaultTypeId - The type of vault to return.
     * @return vaultsOfType_ - An array of all vaults of the given type.
     * @custom:selector 0x45a04abd
     */
    function vaultsOfType(bytes4 vaultTypeId) external view returns (address[] memory);

    /**
     * @notice Returns ALL vaults of a given type that contain a given token.
     * @param vaultTypeId - The type of vault to return.
     * @param token - The address of the token to check.
     * @return vaults_ - An array of all vaults of the given type that contain the given token.
     * @custom:selector 0xcc130893
     */
    function vaultsOfTypeOfToken(bytes4 vaultTypeId, address token) external view returns (address[] memory vaults_);

    /**
     * @notice Returns ALL vaults of a given type that contain a given array of tokens.
     * @notice Will sort in ascending order and hash array as contents ID.
     * @param vaultTypeId - The type of vault to return.
     * @param tokens_ - The array of tokens to check.
     * @return vaults_ - An array of all vaults of the given type that contain the given tokens.
     * @custom:selector 0x1cee886c
     */
    function vaultsOfTypeOfTokens(bytes4 vaultTypeId, address[] memory tokens_)
        external
        view
        returns (address[] memory vaults_);

    /**
     * @notice Returns ALL vaults of a given type that contain a given contents ID.
     * @notice Contents ID is the hash of the tokens contained in a vault.
     * @notice Ensure tokens were sorted in ascending order before hashing.
     * @param vaultTypeId - The type of vault to return.
     * @param contentsHash - The hash of the tokens to check.
     * @return vaults_ - An array of all vaults of the given type that contain the given contents ID.
     * @custom:selector 0x78a24e1d
     */
    /// forge-lint: disable-next-line(mixed-case-function)
    function vaultsOfTypeOfContentsId(bytes4 vaultTypeId, bytes32 contentsHash)
        external
        view
        returns (address[] memory vaults_);

    /**
     * @notice Returns ALL vaults of a given package.
     * @param pkg - The address of the package to check.
     * @return vaults_ - An array of all vaults of the given package.
     * @custom:selector 0x2398fdc4
     */
    function vaultsOfPackage(address pkg) external view returns (address[] memory vaults_);

    /**
     * @notice Returns ALL vaults of a given package that contain a given token.
     * @param pkg - The address of the package to check.
     * @param token - The address of the token to check.
     * @return vaults_ - An array of all vaults of the given package that contain the given token.
     * @custom:selector 0x7d73194b
     */
    function vaultsOfPkgOfToken(address pkg, address token) external view returns (address[] memory vaults_);

    /**
     * @notice Returns ALL vaults of a given package that contain a given array of tokens.
     * @notice Will sort in ascending order and hash array as contents ID.
     * @param pkg - The address of the package to check.
     * @param tokens_ - The array of tokens to check.
     * @return vaults_ - An array of all vaults of the given package that contain the given tokens.
     * @custom:selector 0x902d8230
     */
    function vaultsOfPkgOfTokens(address pkg, address[] memory tokens_) external view returns (address[] memory vaults_);

    /**
     * @notice Returns ALL vaults of a given package that contain a given contents ID.
     * @notice Contents ID is the hash of the tokens contained in a vault.
     * @notice Ensure tokens were sorted in ascending order before hashing.
     * @param pkg - The address of the package to check.
     * @param contentsHash - The hash of the tokens to check.
     * @return vaults_ - An array of all vaults of the given package that contain the given contents ID.
     * @custom:selector 0x39786c18
     */
    /// forge-lint: disable-next-line(mixed-case-function)
    function vaultsOfPkgOfContentsId(address pkg, bytes32 contentsHash) external view returns (address[] memory vaults_);

    function vaultUsageFeeTypeId(address vault) external view returns (bytes4 vaultUsageFeeTypeId_);

    function vaultDexTermsTypeId(address vault) external view returns (bytes4 vaultDexTermsTypeId_);

    function vaultBondTermsTypeId(address vault) external view returns (bytes4 vaultBondTermsTypeId_);

    function vaultLendingTermsTypeId(address vault) external view returns (bytes4 vaultLendingTermsTypeId_);
}
