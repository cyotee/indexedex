// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

/// @notice Registered deployment schema for separate raw-DETF and staking SY instances.
interface IDETFSYDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet syFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
    }

    struct PkgArgs {
        IERC20 detf;
        IStakedDETF staking;
        bool isStaking;
        string name;
        string symbol;
        address[] tokensIn;
        address[] tokensOut;
    }

    function deployVault(PkgArgs memory args_) external returns (address);
}
