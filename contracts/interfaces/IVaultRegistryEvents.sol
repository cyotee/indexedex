// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

interface IVaultRegistryEvents {
    /* ---------------------------------------------------------------------- */
    /*                                 Events                                 */
    /* ---------------------------------------------------------------------- */

    event NewPackage(
        address indexed package, string indexed name, bytes32 indexed vaultFeeTypeIds, bytes4[] vaultTypes
    );

    event PackageRemoved(address indexed package);

    event NewPackageOfType(address indexed package, bytes4 indexed vaultType);

    event NewVault(
        address indexed vault,
        address indexed package,
        bytes32 vaultFeeIds,
        bytes32 indexed contentsId,
        bytes4[] vaultTypes,
        address[] tokens
    );

    event NewVaultOfType(address indexed vault, address indexed package, bytes4 indexed vaultType);

    event NewVaultOfToken(address indexed vault, address indexed package, address indexed token);

    event VaultRemoved(address indexed vault);
}
