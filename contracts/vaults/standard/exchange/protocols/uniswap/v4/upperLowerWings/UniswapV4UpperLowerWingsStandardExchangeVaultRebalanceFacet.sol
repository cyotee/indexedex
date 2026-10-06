// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget.sol";
contract UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFacet is UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1); ids_[0] = type(IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](1); selectors_[0] = IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.rebalance.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
