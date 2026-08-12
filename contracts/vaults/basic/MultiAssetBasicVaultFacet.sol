// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {MultiAssetBasicVaultTarget} from "contracts/vaults/basic/MultiAssetBasicVaultTarget.sol";

/**
 * @title MultiAssetBasicVaultFacet
 * @notice IFacet-only surface; domain logic lives on MultiAssetBasicVaultTarget (D41).
 */
contract MultiAssetBasicVaultFacet is MultiAssetBasicVaultTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                                 IFacet                                 */
    /* ---------------------------------------------------------------------- */
    function facetName() public pure returns (string memory name) {
        return type(MultiAssetBasicVaultFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBasicVault).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[0] = IBasicVault.vaultTokens.selector;
        funcs[1] = IBasicVault.reserveOfToken.selector;
        funcs[2] = IBasicVault.reserves.selector;
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
