// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFExchangeInTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFExchangeInTarget.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";

/// @title UniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet
/// @notice Exchange In/Out + Phase 0 exact-out InvalidRoute selectors.
contract UniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet is
    IFacet,
    UniswapV4StandardExchangeCurveQuadStableDETFExchangeInTarget
{
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet";
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](4);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = IUniswapV4StandardExchangeCurveQuadStableDETF.mintExactDetfOut.selector;
        funcs_[3] = IUniswapV4StandardExchangeCurveQuadStableDETF.burnExactTokenOut.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        funcs_ = new bytes4[](4);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = IUniswapV4StandardExchangeCurveQuadStableDETF.mintExactDetfOut.selector;
        funcs_[3] = IUniswapV4StandardExchangeCurveQuadStableDETF.burnExactTokenOut.selector;
    }
}
