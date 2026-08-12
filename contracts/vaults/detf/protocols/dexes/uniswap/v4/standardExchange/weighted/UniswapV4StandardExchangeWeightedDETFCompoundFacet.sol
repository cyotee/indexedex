// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4StandardExchangeWeightedDETFCompoundTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFCompoundTarget.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";

/// @notice Claim + compound + expansion surface (Option 1e size split from Bonding Facet).
contract UniswapV4StandardExchangeWeightedDETFCompoundFacet is
    IFacet,
    UniswapV4StandardExchangeWeightedDETFCompoundTarget
{
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeWeightedDETFCompoundFacet";
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
        name_ = "UniswapV4StandardExchangeWeightedDETFCompoundFacet";
        interfaces_ = new bytes4[](0);
        funcs_ = _allFuncs();
    }

    function _allFuncs() private pure returns (bytes4[] memory f) {
        f = new bytes4[](10);
        f[0] = IUniswapV4StandardExchangeWeightedDETF.claimRewards.selector;
        f[1] = IUniswapV4StandardExchangeWeightedDETF.depositClaim.selector;
        f[2] = IUniswapV4StandardExchangeWeightedDETF.redeemClaim.selector;
        f[3] = IUniswapV4StandardExchangeWeightedDETF.claimLiquidity.selector;
        f[4] = IUniswapV4StandardExchangeWeightedDETF.compoundProtocolRewards.selector;
        f[5] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        f[6] = bytes4(keccak256("tryCompoundProtocolRewardsExternal()"));
        f[7] = bytes4(keccak256("realizeExpansionExternal()"));
        f[8] = bytes4(keccak256("redepositDetfExternal(uint256,uint256[])"));
        f[9] = bytes4(keccak256("swapDetfToCapitalExternal(uint256,address)"));
    }
    // note: selectors 5–6 are required for diamond `this.` routes from Common helpers
}
