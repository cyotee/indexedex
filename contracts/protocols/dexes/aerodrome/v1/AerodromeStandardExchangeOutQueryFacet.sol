// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {AerodromeStandardExchangeQuoteTarget} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeQuoteTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ConstantProductStandardYieldTarget} from "contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";


import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    AerodromeStandardExchangeOutQueryTarget
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutQueryTarget.sol";

/// @notice Exact-output previews and native SY adapters using the installed standard routes.
contract AerodromeStandardExchangeOutQueryFacet is AerodromeStandardExchangeOutQueryTarget, AerodromeStandardExchangeQuoteTarget, ConstantProductStandardYieldTarget, IFacet {
    function _redeemConstantProduct(address holder_, address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override nonReentrant returns (uint256)
    {
        address implementation_ = IDiamondLoupe(address(this)).facetAddress(IStandardExchangeOut.exchangeOut.selector);
        (bool ok_, bytes memory result_) = implementation_.delegatecall(abi.encodeWithSignature(
            "executeNativeSyRedemption(address,address,uint256,address,uint256)",
            holder_, receiver_, shares_, tokenOut_, minimum_
        ));
        if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
        return abi.decode(result_, (uint256));
    }

    function facetName() public pure returns (string memory name) {
        return type(AerodromeStandardExchangeOutQueryFacet).name;
    }

    function facetInterfaces() public pure virtual returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](3);
        interfaces[0] = type(IStandardizedYield).interfaceId;
        interfaces[1] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[2] = type(IStandardExchangeExternalQuote).interfaceId;
    }

    function facetFuncs() public pure virtual returns (bytes4[] memory funcs) {
        funcs = new bytes4[](8);
        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[1] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[5] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[6] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
        funcs[7] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
        funcs = NativeStandardYieldSelectors._append(funcs);
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
