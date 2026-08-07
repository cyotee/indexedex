// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeWeightedDETFBondingTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFBondingTarget.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";

/// @dev Lifecycle facet: exchange / bond / claim / compound (info views on InfoFacet).
contract UniswapV4StandardExchangeWeightedDETFFacet is
    IFacet,
    UniswapV4StandardExchangeWeightedDETFBondingTarget
{
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeWeightedDETFFacet";
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
        name_ = "UniswapV4StandardExchangeWeightedDETFFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        funcs_ = _allFuncs();
    }

    function _allFuncs() private pure returns (bytes4[] memory f) {
        f = new bytes4[](16);
        f[0] = IStandardExchangeIn.exchangeIn.selector;
        f[1] = IStandardExchangeIn.previewExchangeIn.selector;
        // bond(IERC20[],uint256[],address,uint256,address,bool,uint256)
        f[2] = bytes4(keccak256("bond(address[],uint256[],address,uint256,address,bool,uint256)"));
        // bond(IERC20,uint256,uint256,address,bool,uint256)
        f[3] = bytes4(keccak256("bond(address,uint256,uint256,address,bool,uint256)"));
        f[4] = IUniswapV4StandardExchangeWeightedDETF.sellPositionToDetfNft.selector;
        f[5] = IUniswapV4StandardExchangeWeightedDETF.closeBondMature.selector;
        f[6] = IUniswapV4StandardExchangeWeightedDETF.claimRewards.selector;
        f[7] = IUniswapV4StandardExchangeWeightedDETF.depositClaim.selector;
        f[8] = IUniswapV4StandardExchangeWeightedDETF.redeemClaim.selector;
        f[9] = IUniswapV4StandardExchangeWeightedDETF.claimLiquidity.selector;
        f[10] = IUniswapV4StandardExchangeWeightedDETF.compoundProtocolRewards.selector;
        f[11] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        f[12] = bytes4(keccak256("tryCompoundProtocolRewardsExternal()"));
        f[13] = bytes4(keccak256("realizeExpansionExternal()"));
        f[14] = bytes4(keccak256("redepositDetfExternal(uint256,uint256[])"));
        f[15] = bytes4(keccak256("swapDetfToCapitalExternal(uint256,address)"));
    }
}
