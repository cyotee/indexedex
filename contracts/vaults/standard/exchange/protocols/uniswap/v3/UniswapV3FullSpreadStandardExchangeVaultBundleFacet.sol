// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {UniswapV3FullSpreadStandardExchangeVaultBundleTarget} from "./UniswapV3FullSpreadStandardExchangeVaultBundleTarget.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "../v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";

contract UniswapV3FullSpreadStandardExchangeVaultBundleFacet is UniswapV3FullSpreadStandardExchangeVaultBundleTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV3FullSpreadStandardExchangeVaultBundleFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IStandardExchangeBundleIn).interfaceId;
        interfaces_[1] = type(IStandardExchangeBundleOut).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](2);
        selectors_[0] = IStandardExchangeBundleIn.exchangeBundleInForSingleOut.selector;
        selectors_[1] = IStandardExchangeBundleOut.exchangeBundleOut.selector;
    }

    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
