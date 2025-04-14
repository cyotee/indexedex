// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";

interface IVaultRegistryVaultManager {
    function registerVault(address vault, address pkg, IStandardVault.VaultConfig memory vaultConfig)
        external
        returns (bool);

    function unregisterVault(address vault, address pkg, IStandardVault.VaultConfig memory vaultConfig)
        external
        returns (bool);
}
