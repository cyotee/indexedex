// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

interface IComposedStableCommonDetfBondNFTVaultDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        IFacet erc721Facet;
        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;
        IFacet bondNFTVaultFacet;
        IFacet multiStepOwnableFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
    }

    struct PkgArgs {
        string name;
        string symbol;
        IDetf detf;
        IERC20 lpToken;
        IERC20 rewardToken;
        uint8 decimalOffset;
        address owner;
    }

    error NotCalledByRegistry(address caller);

    function deployVault(
        string memory name,
        string memory symbol,
        IDetf detf,
        IERC20 lpToken,
        IERC20 rewardToken,
        uint8 decimalOffset,
        address owner
    ) external returns (address vaultAddress);
}
