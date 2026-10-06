// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultQueryTarget} from "./UniswapV4UpperLowerWingsStandardExchangeVaultQueryTarget.sol";

contract UniswapV4UpperLowerWingsStandardExchangeVaultQueryFacet is UniswapV4UpperLowerWingsStandardExchangeVaultQueryTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(UniswapV4UpperLowerWingsStandardExchangeVaultQueryFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1); ids_[0] = type(IUniswapV4UpperLowerWingsStandardExchangeVault).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](6);
        selectors_[0] = IUniswapV4UpperLowerWingsStandardExchangeVault.poolManager.selector;
        selectors_[1] = IUniswapV4UpperLowerWingsStandardExchangeVault.poolKey.selector;
        selectors_[2] = IUniswapV4UpperLowerWingsStandardExchangeVault.targetToken.selector;
        selectors_[3] = IUniswapV4UpperLowerWingsStandardExchangeVault.liquidationValue.selector;
        selectors_[4] = IUniswapV4UpperLowerWingsStandardExchangeVault.localReserves.selector;
        selectors_[5] = IUniswapV4UpperLowerWingsStandardExchangeVault.position.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
