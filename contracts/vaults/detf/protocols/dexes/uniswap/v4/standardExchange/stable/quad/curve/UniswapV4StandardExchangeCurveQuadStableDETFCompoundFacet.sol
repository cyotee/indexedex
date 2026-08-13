// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFCompoundTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFCompoundTarget.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";

/// @notice Claim + compound + expansion surface.
contract UniswapV4StandardExchangeCurveQuadStableDETFCompoundFacet is
    IFacet,
    UniswapV4StandardExchangeCurveQuadStableDETFCompoundTarget
{
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeCurveQuadStableDETFCompoundFacet";
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](0);
    }

    function facetFuncs() external pure returns (bytes4[] memory) {
        return _allFuncs();
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4StandardExchangeCurveQuadStableDETFCompoundFacet";
        interfaces_ = new bytes4[](0);
        funcs_ = _allFuncs();
    }

    function _allFuncs() private pure returns (bytes4[] memory f) {
        f = new bytes4[](10);
        f[0] = IUniswapV4StandardExchangeCurveQuadStableDETF.claimRewards.selector;
        f[1] = IUniswapV4StandardExchangeCurveQuadStableDETF.depositClaim.selector;
        f[2] = IUniswapV4StandardExchangeCurveQuadStableDETF.redeemClaim.selector;
        f[3] = IUniswapV4StandardExchangeCurveQuadStableDETF.claimLiquidity.selector;
        f[4] = IUniswapV4StandardExchangeCurveQuadStableDETF.compoundProtocolRewards.selector;
        f[5] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        f[6] = bytes4(keccak256("tryCompoundProtocolRewardsExternal()"));
        f[7] = bytes4(keccak256("realizeExpansionExternal()"));
        f[8] = bytes4(keccak256("redepositDetfExternal(uint256,uint256[])"));
        f[9] = bytes4(keccak256("swapDetfToCapitalExternal(uint256,address)"));
    }
}
