// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Orbital_Extras_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_Extras_Decimals.sol";

/// @notice Book `B_ALL6`. pairToken/pair0 6-dec; pair1 6-dec; remaining 6. DETF token stays 18.
contract UniswapV4Detf_Orbital_Extras_B_ALL6 is UniswapV4Detf_Orbital_Extras_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }
}
