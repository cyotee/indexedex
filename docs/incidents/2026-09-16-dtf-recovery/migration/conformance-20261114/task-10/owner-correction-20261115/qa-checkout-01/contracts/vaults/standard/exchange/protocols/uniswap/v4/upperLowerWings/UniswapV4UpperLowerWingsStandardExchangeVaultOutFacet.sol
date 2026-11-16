// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultOutTarget} from "./UniswapV4UpperLowerWingsStandardExchangeVaultOutTarget.sol";
contract UniswapV4UpperLowerWingsStandardExchangeVaultOutFacet is UniswapV4UpperLowerWingsStandardExchangeVaultOutTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(UniswapV4UpperLowerWingsStandardExchangeVaultOutFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1); ids_[0] = type(IStandardExchangeOut).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](2);
        selectors_[0] = IStandardExchangeOut.exchangeOut.selector;
        selectors_[1] = IStandardExchangeOut.previewExchangeOut.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
