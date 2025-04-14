// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
// import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
// import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleProxy} from "contracts/interfaces/proxies/IVaultFeeOracleProxy.sol";

interface IVaultRegistryProxy is
    IVaultRegistryVaultQuery,
    IVaultRegistryVaultPackageQuery,
    IVaultRegistryDeployment,
    // IVaultFeeOracleQuery,
    // IVaultFeeOracleManager,
    IVaultFeeOracleProxy
{}
