// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

// import { IVault } from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

// import { IVaultRegistryQuery } from "contracts/indexedex/interfaces/IVaultRegistryQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryEvents} from "contracts/interfaces/IVaultRegistryEvents.sol";

/**
 * @custom:interfaceid 0xb1292be7
 */
interface IVaultRegistryDeployment is IVaultRegistryEvents {
    /* ---------------------------------------------------------------------- */
    /*                                 Structs                                */
    /* ---------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    error PkgNotRegistered(address pkg);

    /* ---------------------------------------------------------------------- */
    /*                                 Events                                 */
    /* ---------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------- */
    /*                                Functions                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @custom:selector 0x96295ed2
     */
    function deployPkg(bytes calldata initCode, bytes calldata initArgs, bytes32 salt) external returns (address pkg);

    /**
     * @custom:selector 0x968cbade
     */
    function deployVault(IStandardVaultPkg pkg, bytes calldata pkgArgs) external returns (address vault);
}
