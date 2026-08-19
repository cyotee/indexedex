// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFBondingTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFBondingTarget.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @dev Bonding / claim / compound surface only (exchange moved to ExchangeFacet — Option 1e).
contract UniswapV4StandardExchangeOrbitalDETFFacet is IFacet, UniswapV4StandardExchangeOrbitalDETFBondingTarget {
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeOrbitalDETFFacet";
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4StandardExchangeOrbitalDETF).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory) {
        return _allFuncs();
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4StandardExchangeOrbitalDETFFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4StandardExchangeOrbitalDETF).interfaceId;
        funcs_ = _allFuncs();
    }

    function _allFuncs() private pure returns (bytes4[] memory f) {
        f = new bytes4[](15);
        f[0] = bytes4(keccak256("bond(address,uint256,address,uint256,uint256,address,bool,uint256)"));
        f[1] = bytes4(keccak256("bond(address,uint256,uint256,address,bool,uint256)"));
        f[2] = IUniswapV4StandardExchangeOrbitalDETF.sellPositionToDetfNft.selector;
        f[3] = IUniswapV4StandardExchangeOrbitalDETF.closeBondMature.selector;
        f[4] = IUniswapV4StandardExchangeOrbitalDETF.previewCloseBondMature.selector;
        f[5] = IUniswapV4StandardExchangeOrbitalDETF.claimRewards.selector;
        f[6] = IUniswapV4StandardExchangeOrbitalDETF.depositClaim.selector;
        f[7] = IUniswapV4StandardExchangeOrbitalDETF.redeemClaim.selector;
        f[8] = IUniswapV4StandardExchangeOrbitalDETF.buyClaim.selector;
        f[9] = IUniswapV4StandardExchangeOrbitalDETF.previewBuyClaim.selector;
        f[10] = IUniswapV4StandardExchangeOrbitalDETF.claimLiquidity.selector;
        f[11] = IUniswapV4StandardExchangeOrbitalDETF.compoundProtocolRewards.selector;
        f[12] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        f[13] = IUniswapV4StandardExchangeOrbitalDETF.completeReserveBondNft.selector;
        f[14] = IUniswapV4StandardExchangeOrbitalDETF.completeReserveClaim.selector;
    }
}
