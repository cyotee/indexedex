// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeWeightedDETFExchangeInTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFExchangeInTarget.sol";

/// @title UniswapV4StandardExchangeWeightedDETFExchangeFacet
/// @notice Exchange In/Out only (Option 1e size split from lifecycle mega-Facet).
contract UniswapV4StandardExchangeWeightedDETFExchangeFacet is
    IFacet,
    UniswapV4StandardExchangeWeightedDETFExchangeInTarget
{
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeWeightedDETFExchangeFacet";
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](2);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4StandardExchangeWeightedDETFExchangeFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        funcs_ = new bytes4[](2);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
    }
}
