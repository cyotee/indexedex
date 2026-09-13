// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Cp_Univ3Se_Policy_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_Policy_Decimals.sol";

/// @notice Combo `H6`. pairToken/pair0 6-dec; other/rate 6-dec; remaining 18. SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible.
contract UniswapV4Detf_Cp_Univ3Se_Policy_H6 is UniswapV4Detf_Cp_Univ3Se_Policy_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }
}
