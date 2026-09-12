// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Orbital_Policy_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_Policy_Decimals.sol";

/// @notice Book `B_P9_R18`. pairToken/pair0 9-dec; pair1 18-dec; remaining 18. DETF token stays 18.
contract UniswapV4Detf_Orbital_Policy_B_P9_R18 is UniswapV4Detf_Orbital_Policy_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 9; }
    function _rateDecimals() internal pure override returns (uint8) { return 18; }
}
