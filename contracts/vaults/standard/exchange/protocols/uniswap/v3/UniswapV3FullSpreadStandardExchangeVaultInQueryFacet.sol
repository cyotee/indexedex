// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultInQueryTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol";

/**
 * @title UniswapV3FullSpreadStandardExchangeVaultInQueryFacet
 * @notice The canonical two-word exact-input preview.
 */
contract UniswapV3FullSpreadStandardExchangeVaultInQueryFacet is UniswapV3FullSpreadStandardExchangeVaultInQueryTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV3FullSpreadStandardExchangeVaultInQueryFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IStandardExchangeStateQuote).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](4);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeStateQuote.quoteExchangeState.selector;
        funcs[2] = IStandardExchangeStateQuote.quoteExchangeIn.selector;
        funcs[3] = IStandardExchangeStateQuote.quoteExchangeSupply.selector;
    }

    function facetMetadata()
        external
        pure
        override
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
