// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {VaultRegistryVaultQueryTarget} from "contracts/registries/vault/VaultRegistryVaultQueryTarget.sol";

contract VaultRegistryVaultQueryFacet is VaultRegistryVaultQueryTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(VaultRegistryVaultQueryFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IVaultRegistryVaultQuery).interfaceId;
    }

    /**
     * @notice Returns the function selectors supported by this facet
     * @return selectors Array of 4-byte function selectors
     */
    function facetFuncs() public pure override returns (bytes4[] memory selectors) {
        selectors = new bytes4[](21);
        selectors[0] = IVaultRegistryVaultQuery.vaults.selector;
        selectors[1] = IVaultRegistryVaultQuery.isVault.selector;
        selectors[2] = IVaultRegistryVaultQuery.vaultTokens.selector;
        selectors[3] = IVaultRegistryVaultQuery.isContainedToken.selector;
        selectors[4] = IVaultRegistryVaultQuery.vaultsOfToken.selector;
        selectors[5] = IVaultRegistryVaultQuery.vaultsOfTokens.selector;
        selectors[6] = IVaultRegistryVaultQuery.calcContentsId.selector;
        selectors[7] = IVaultRegistryVaultQuery.contentsIds.selector;
        selectors[8] = IVaultRegistryVaultQuery.vaultsOfContentsId.selector;
        selectors[9] = IVaultRegistryVaultQuery.vaultsOfType.selector;
        selectors[10] = IVaultRegistryVaultQuery.vaultsOfTypeOfToken.selector;
        selectors[11] = IVaultRegistryVaultQuery.vaultsOfTypeOfTokens.selector;
        selectors[12] = IVaultRegistryVaultQuery.vaultsOfTypeOfContentsId.selector;
        selectors[13] = IVaultRegistryVaultQuery.vaultsOfPackage.selector;
        selectors[14] = IVaultRegistryVaultQuery.vaultsOfPkgOfToken.selector;
        selectors[15] = IVaultRegistryVaultQuery.vaultsOfPkgOfTokens.selector;
        selectors[16] = IVaultRegistryVaultQuery.vaultsOfPkgOfContentsId.selector;
        selectors[17] = IVaultRegistryVaultQuery.vaultUsageFeeTypeId.selector;
        selectors[18] = IVaultRegistryVaultQuery.vaultDexTermsTypeId.selector;
        selectors[19] = IVaultRegistryVaultQuery.vaultBondTermsTypeId.selector;
        selectors[20] = IVaultRegistryVaultQuery.vaultLendingTermsTypeId.selector;
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
