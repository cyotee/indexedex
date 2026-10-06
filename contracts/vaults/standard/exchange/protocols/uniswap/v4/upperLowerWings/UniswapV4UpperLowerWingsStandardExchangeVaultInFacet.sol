// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInTarget} from "./UniswapV4UpperLowerWingsStandardExchangeVaultInTarget.sol";
contract UniswapV4UpperLowerWingsStandardExchangeVaultInFacet is UniswapV4UpperLowerWingsStandardExchangeVaultInTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(UniswapV4UpperLowerWingsStandardExchangeVaultInFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1); ids_[0] = type(IStandardExchangeIn).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](2);
        selectors_[0] = IStandardExchangeIn.exchangeIn.selector;
        selectors_[1] = IStandardExchangeIn.previewExchangeIn.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
