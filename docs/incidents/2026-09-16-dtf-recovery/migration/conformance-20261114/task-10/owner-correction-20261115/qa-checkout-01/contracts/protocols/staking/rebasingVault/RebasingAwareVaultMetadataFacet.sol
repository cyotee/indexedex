// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";

import {RebasingAwareVaultMetadataTarget} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareVaultMetadataTarget.sol";

contract RebasingAwareVaultMetadataFacet is RebasingAwareVaultMetadataTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(RebasingAwareVaultMetadataFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IBasicVault).interfaceId;
        interfaces[1] = type(IStandardVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](7);
        funcs[0] = IBasicVault.vaultTokens.selector;
        funcs[1] = IBasicVault.reserveOfToken.selector;
        funcs[2] = IBasicVault.reserves.selector;
        funcs[3] = IStandardVault.vaultFeeTypeIds.selector;
        funcs[4] = IStandardVault.contentsId.selector;
        funcs[5] = IStandardVault.vaultTypes.selector;
        funcs[6] = IStandardVault.vaultConfig.selector;
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
