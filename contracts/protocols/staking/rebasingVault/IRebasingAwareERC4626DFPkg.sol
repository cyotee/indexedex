// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

interface IRebasingAwareERC4626DFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet rebasingAwareErc4626Facet;
        IDiamondPackageCallBackFactory diamondFactory;
        IFacet standardExchangeFacet;
        IFacet standardYieldFacet;
        IFacet vaultMetadataFacet;
        IFacet transitionQuoteFacet;
        IVaultRegistryDeployment vaultRegistry;
    }

    struct PkgArgs {
        IERC20Metadata asset;
        string name;
        string symbol;
        uint8 decimalOffset;
        bytes32 optionalSalt;
    }

    error NoAsset();
    error NoNameAndSymbol();

    function deployVault(IERC20Metadata asset) external returns (IERC4626 vault);
    function deployVault(IERC20Metadata asset, uint8 decimalOffset, bytes32 optionalSalt)
        external
        returns (IERC4626 vault);

    function releaseIdentifier() external pure returns (string memory);
}
