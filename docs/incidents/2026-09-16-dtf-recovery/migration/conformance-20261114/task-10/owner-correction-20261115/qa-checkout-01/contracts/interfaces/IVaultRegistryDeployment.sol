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

    /**
     * @notice Deploy a Uniswap V4 hook diamond vault via the hook package callback factory (premine path).
     * @dev Same ACL as deployVault (owner / operator / registered package). Hook packages call this from
     *      their typed deployVault helpers (parallel to SE packages calling deployVault). Does not use
     *      vault diamond factory salt law (no package-in-salt). Registers the instance as a vault.
     */
    function deployHookVault(IStandardVaultPkg pkg, bytes calldata pkgArgs, uint256 mineNonce)
        external
        returns (address vault);

    /**
     * @notice Deploy a hook diamond vault with factory auto-mine (gas-risky; prefer deployHookVault).
     * @dev Same ACL/register behavior as deployHookVault. Production packages should prefer premine + deployHookVault.
     */
    function deployHookVaultAutoMine(IStandardVaultPkg pkg, bytes calldata pkgArgs)
        external
        returns (address vault);

    /**
     * @notice Wire the hook diamond package callback factory for deployHookVault*.
     * @dev Owner/operator only. Called after CREATE3 deploy of the factory singleton.
     */
    function setHookDiamondPackageFactory(address hookFactory) external;
}
