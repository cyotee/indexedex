// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultEconomic as Economic} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultEconomic.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget} from "./UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol";
contract UniswapV4UpperLowerWingsStandardExchangeVaultEconomicFacet is UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(UniswapV4UpperLowerWingsStandardExchangeVaultEconomicFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](3);
        ids_[0] = type(IRateProvider).interfaceId; ids_[1] = type(IStandardExchangeRateQuote).interfaceId; ids_[2] = type(Economic).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](4);
        selectors_[0] = IRateProvider.getRate.selector; selectors_[1] = IStandardExchangeRateQuote.quoteRate.selector;
        selectors_[2] = Economic.sleeveState.selector; selectors_[3] = Economic.positionInventory.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
