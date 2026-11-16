// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV4FullSpreadStandardExchangeVaultOutTarget} from "./UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol";

contract UniswapV4FullSpreadStandardExchangeVaultOutFacet is UniswapV4FullSpreadStandardExchangeVaultOutTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultOutFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1);
        ids_[0] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](2);
        funcs_[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs_[1] = IStandardExchangeOut.exchangeOut.selector;
    }

    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
