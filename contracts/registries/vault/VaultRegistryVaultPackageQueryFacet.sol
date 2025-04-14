// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {
    VaultRegistryVaultPackageQueryTarget
} from "contracts/registries/vault/VaultRegistryVaultPackageQueryTarget.sol";

contract VaultRegistryVaultPackageQueryFacet is VaultRegistryVaultPackageQueryTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(VaultRegistryVaultPackageQueryFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IVaultRegistryVaultPackageQuery).interfaceId;
    }

    /**
     * @notice Returns the function selectors supported by this facet
     * @return selectors Array of 4-byte function selectors
     */
    function facetFuncs() public pure override returns (bytes4[] memory selectors) {
        selectors = new bytes4[](10);
        selectors[0] = IVaultRegistryVaultPackageQuery.vaultPackages.selector;
        selectors[1] = IVaultRegistryVaultPackageQuery.isPackage.selector;
        selectors[2] = IVaultRegistryVaultPackageQuery.vaultTypeIds.selector;
        selectors[3] = IVaultRegistryVaultPackageQuery.vaultUsageFeeTypeIds.selector;
        selectors[4] = IVaultRegistryVaultPackageQuery.vaultDexFeeTypeIds.selector;
        selectors[5] = IVaultRegistryVaultPackageQuery.vaultBondFeeTypeIds.selector;
        selectors[6] = IVaultRegistryVaultPackageQuery.vaultLendingFeeTypeIds.selector;
        selectors[7] = IVaultRegistryVaultPackageQuery.packageName.selector;
        selectors[8] = IVaultRegistryVaultPackageQuery.packageFeeTypeIds.selector;
        selectors[9] = IVaultRegistryVaultPackageQuery.packagesOfTypeId.selector;
    }

    function facetMetadata()
        public
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
