// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFBondingTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFBondingTarget.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";

/// @dev Bonding / mature sell-close surface only (exchange + claim/compound on sibling facets).
contract UniswapV4StandardExchangeCurveQuadStableDETFFacet is
    IFacet,
    UniswapV4StandardExchangeCurveQuadStableDETFBondingTarget
{
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeCurveQuadStableDETFFacet";
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4StandardExchangeCurveQuadStableDETF).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory) {
        return _allFuncs();
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4StandardExchangeCurveQuadStableDETFFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4StandardExchangeCurveQuadStableDETF).interfaceId;
        funcs_ = _allFuncs();
    }

    function _allFuncs() private pure returns (bytes4[] memory f) {
        f = new bytes4[](6);
        f[0] = bytes4(keccak256("bond(address[],uint256[],address,uint256,address,bool,uint256)"));
        f[1] = bytes4(keccak256("bond(address,uint256,uint256,address,bool,uint256)"));
        f[2] = IUniswapV4StandardExchangeCurveQuadStableDETF.sellPositionToDetfNft.selector;
        f[3] = IUniswapV4StandardExchangeCurveQuadStableDETF.closeBondMature.selector;
        f[4] = IUniswapV4StandardExchangeCurveQuadStableDETF.completeReserveBondNft.selector;
        f[5] = IUniswapV4StandardExchangeCurveQuadStableDETF.completeReserveClaim.selector;
    }
}
