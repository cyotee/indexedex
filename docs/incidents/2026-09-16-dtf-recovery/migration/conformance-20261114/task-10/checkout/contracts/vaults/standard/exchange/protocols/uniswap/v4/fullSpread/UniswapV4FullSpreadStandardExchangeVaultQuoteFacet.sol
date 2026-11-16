// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4FullSpreadStandardExchangeVaultQuoteTarget} from "./UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol";
import {
    IStandardExchangeBundleIn,
    IStandardExchangeBundleOut
} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";

contract UniswapV4FullSpreadStandardExchangeVaultQuoteFacet is UniswapV4FullSpreadStandardExchangeVaultQuoteTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultQuoteFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](3);
        ids_[0] = type(IStandardExchangeIn).interfaceId;
        ids_[1] = type(IStandardExchangeBundleIn).interfaceId;
        ids_[2] = type(IStandardExchangeBundleOut).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](3);
        funcs_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[1] = IStandardExchangeBundleIn.previewExchangeBundleInForSingleOut.selector;
        funcs_[2] = IStandardExchangeBundleOut.previewExchangeBundleOut.selector;
    }

    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
