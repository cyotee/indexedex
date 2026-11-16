// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {UniswapV4FullSpreadStandardExchangeVaultQueryTarget} from "./UniswapV4FullSpreadStandardExchangeVaultQueryTarget.sol";

contract UniswapV4FullSpreadStandardExchangeVaultQueryFacet is UniswapV4FullSpreadStandardExchangeVaultQueryTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultQueryFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1);
        ids_[0] = type(IBasicVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](2);
        funcs_[0] = IBasicVault.reserveOfToken.selector;
        funcs_[1] = IBasicVault.reserves.selector;
    }

    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
