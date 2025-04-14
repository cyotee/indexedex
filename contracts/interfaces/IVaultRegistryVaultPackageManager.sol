// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

interface IVaultRegistryVaultPackageManager {
    function registerPackage(address pkg, IStandardVaultPkg.VaultPkgDeclaration memory dec) external returns (bool);

    function unregisterPackage(address pkg) external returns (bool);
}
