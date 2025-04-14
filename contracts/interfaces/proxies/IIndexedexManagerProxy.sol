// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";

interface IIndexedexManagerProxy is
    IMultiStepOwnable,
    IVaultFeeOracleQuery,
    IVaultFeeOracleManager,
    IVaultRegistryDeployment,
    IVaultRegistryVaultManager,
    IVaultRegistryVaultPackageManager,
    IVaultRegistryVaultPackageQuery,
    IVaultRegistryVaultQuery
{}
