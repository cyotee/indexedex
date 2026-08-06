// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFBondingTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFBondingTarget.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @dev Lifecycle facet: exchange / bond / claim / compound (info views on InfoFacet).
contract UniswapV4StandardExchangeOrbitalDETFFacet is
    IFacet,
    UniswapV4StandardExchangeOrbitalDETFBondingTarget
{
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeOrbitalDETFFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
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
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        funcs_ = _allFuncs();
    }

    function _allFuncs() private pure returns (bytes4[] memory f) {
        f = new bytes4[](11);
        f[0] = IStandardExchangeIn.exchangeIn.selector;
        f[1] = IStandardExchangeIn.previewExchangeIn.selector;
        f[2] = bytes4(keccak256("bond(address,uint256,address,uint256,uint256,address,bool,uint256)"));
        f[3] = bytes4(keccak256("bond(address,uint256,uint256,address,bool,uint256)"));
        f[4] = IUniswapV4StandardExchangeOrbitalDETF.sellPositionToDetfNft.selector;
        f[5] = IUniswapV4StandardExchangeOrbitalDETF.closeBondMature.selector;
        f[6] = IUniswapV4StandardExchangeOrbitalDETF.claimRewards.selector;
        f[7] = IUniswapV4StandardExchangeOrbitalDETF.redeemClaim.selector;
        f[8] = IUniswapV4StandardExchangeOrbitalDETF.claimLiquidity.selector;
        f[9] = IUniswapV4StandardExchangeOrbitalDETF.compoundProtocolRewards.selector;
        f[10] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
    }
}
