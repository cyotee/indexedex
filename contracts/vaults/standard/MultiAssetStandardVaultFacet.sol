// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {MultiAssetStandardVaultTarget} from "contracts/vaults/standard/MultiAssetStandardVaultTarget.sol";

/**
 * @title MultiAssetStandardVaultFacet
 * @notice IFacet-only surface; domain logic lives on MultiAssetStandardVaultTarget (D41).
 */
contract MultiAssetStandardVaultFacet is MultiAssetStandardVaultTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(MultiAssetStandardVaultFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardVault).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](4);
        funcs[0] = IStandardVault.vaultFeeTypeIds.selector;
        funcs[1] = IStandardVault.contentsId.selector;
        funcs[2] = IStandardVault.vaultTypes.selector;
        funcs[3] = IStandardVault.vaultConfig.selector;
        return funcs;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
