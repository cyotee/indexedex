// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfFacet.sol";
import {
    UniswapV4DetfBondTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfBondTarget.sol";

/// @notice Independently deployed bond selectors of the universal DETF.
contract UniswapV4DetfBondFacet is UniswapV4DetfFacet, UniswapV4DetfBondTarget {
    /// @inheritdoc UniswapV4DetfFacet
    function facetName() public pure override returns (string memory) {
        return "UniswapV4DetfBondFacet";
    }

    /// @inheritdoc UniswapV4DetfFacet
    function facetFuncs() public pure override returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IUniswapV4Detf.bond.selector;
    }
}
