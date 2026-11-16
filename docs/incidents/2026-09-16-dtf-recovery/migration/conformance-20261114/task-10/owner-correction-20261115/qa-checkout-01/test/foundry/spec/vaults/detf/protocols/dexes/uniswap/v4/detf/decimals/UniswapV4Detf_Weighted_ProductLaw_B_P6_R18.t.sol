// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Weighted_ProductLaw_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Weighted_ProductLaw_Decimals.sol";

/// @notice Book `B_P6_R18`. pairToken/pair0 6-dec; pair1 18-dec; remaining 18. DETF token stays 18.
contract UniswapV4Detf_Weighted_ProductLaw_B_P6_R18 is UniswapV4Detf_Weighted_ProductLaw_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 18; }
}
