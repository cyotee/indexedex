// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultTransitionTarget} from "./UniswapV4UpperLowerWingsStandardExchangeVaultTransitionTarget.sol";
contract UniswapV4UpperLowerWingsStandardExchangeVaultTransitionFacet is UniswapV4UpperLowerWingsStandardExchangeVaultTransitionTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(UniswapV4UpperLowerWingsStandardExchangeVaultTransitionFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](4);
        ids_[0] = type(IStandardExchangeTransitionQuote).interfaceId;
        ids_[1] = type(IStandardExchangeExternalQuote).interfaceId;
        ids_[2] = type(IStandardExchangeUnlockContextQuote).interfaceId;
        ids_[3] = type(IStandardExchangeExactOutputQuantityQuote).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](10);
        selectors_[0] = IStandardExchangeTransitionQuote.quoteState.selector;
        selectors_[1] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        selectors_[2] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        selectors_[3] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        selectors_[4] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        selectors_[5] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
        selectors_[6] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
        selectors_[7] = IStandardExchangeUnlockContextQuote.quoteStateWithUnavailableUnlock.selector;
        selectors_[8] = IStandardExchangeExactOutputQuantityQuote.quoteInputForExactShares.selector;
        selectors_[9] = IStandardExchangeExactOutputQuantityQuote.quoteSharesForExactAssets.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
