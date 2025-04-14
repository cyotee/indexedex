// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {VaultRegistryVaultManagerTarget} from "contracts/registries/vault/VaultRegistryVaultManagerTarget.sol";

contract VaultRegistryVaultManagerFacet is VaultRegistryVaultManagerTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(VaultRegistryVaultManagerFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IVaultRegistryVaultManager).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IVaultRegistryVaultManager.registerVault.selector;
        funcs[1] = IVaultRegistryVaultManager.unregisterVault.selector;
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
