// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfFacet.sol";
import {
    UniswapV4DetfExchangeTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfExchangeTarget.sol";

/// @notice Independently deployed exchange selectors of the universal DETF.
contract UniswapV4DetfExchangeFacet is UniswapV4DetfFacet, UniswapV4DetfExchangeTarget {
    /// @inheritdoc UniswapV4DetfFacet
    function facetName() public pure override returns (string memory) {
        return "UniswapV4DetfExchangeFacet";
    }

    /// @inheritdoc UniswapV4DetfFacet
    function facetFuncs() public pure override returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
    }
}
