// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {VaultRegistryDisableQueryTarget} from "contracts/registries/vault/VaultRegistryDisableQueryTarget.sol";

contract VaultRegistryDisableQueryFacet is VaultRegistryDisableQueryTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(VaultRegistryDisableQueryFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IVaultRegistryDisableQuery).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](7);
        funcs[0] = IVaultRegistryDisableQuery.isDisabled.selector;
        funcs[1] = IVaultRegistryDisableQuery.isDisabledDetailed.selector;
        funcs[2] = IVaultRegistryDisableQuery.isVaultAddressDisabled.selector;
        funcs[3] = IVaultRegistryDisableQuery.isPackageDisabled.selector;
        funcs[4] = IVaultRegistryDisableQuery.packageOfVault.selector;
        funcs[5] = IVaultRegistryDisableQuery.disabledVaults.selector;
        funcs[6] = IVaultRegistryDisableQuery.disabledPackages.selector;
        return funcs;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
