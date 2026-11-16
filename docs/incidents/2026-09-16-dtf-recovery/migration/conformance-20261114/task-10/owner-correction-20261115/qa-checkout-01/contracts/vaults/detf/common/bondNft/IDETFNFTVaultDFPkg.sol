// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

/// @notice Factory schema for fresh funded-bond deployments.
interface IDETFNFTVaultDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc721Facet;
        IFacet metadataFacet;
        IFacet detfNFTVaultFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
    }

    struct PkgArgs {
        string name;
        string symbol;
        IDetf detf;
        IERC20 lpToken;
    }

    error NotCalledByRegistry(address caller);
    error InvalidPackageArguments();

    function deployVault(string memory name_, string memory symbol_, IDetf detf_, IERC20 lpToken_)
        external returns (address);
}
