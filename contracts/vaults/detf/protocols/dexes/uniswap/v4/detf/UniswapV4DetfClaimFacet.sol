// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfFacet.sol";
import {
    UniswapV4DetfClaimTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfClaimTarget.sol";

/// @notice Independently deployed claim selectors of the universal DETF.
contract UniswapV4DetfClaimFacet is UniswapV4DetfFacet, UniswapV4DetfClaimTarget {
    /// @inheritdoc UniswapV4DetfFacet
    function facetName() public pure override returns (string memory) {
        return "UniswapV4DetfClaimFacet";
    }

    /// @inheritdoc UniswapV4DetfFacet
    function facetFuncs() public pure override returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](2);
        funcs_[0] = IUniswapV4Detf.completeReserveBondNft.selector;
        funcs_[1] = IUniswapV4Detf.completeReserveClaim.selector;
    }
}
