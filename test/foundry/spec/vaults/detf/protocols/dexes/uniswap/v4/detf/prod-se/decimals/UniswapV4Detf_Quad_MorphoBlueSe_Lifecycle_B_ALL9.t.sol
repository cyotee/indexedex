// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Quad_MorphoBlueSe_Lifecycle_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Quad_MorphoBlueSe_Lifecycle_Decimals.sol";

/// @notice Combo `B_ALL9`. pairToken/pair0 9-dec; other/rate 9-dec; remaining 9. SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible.
contract UniswapV4Detf_Quad_MorphoBlueSe_Lifecycle_B_ALL9 is UniswapV4Detf_Quad_MorphoBlueSe_Lifecycle_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 9; }
    function _rateDecimals() internal pure override returns (uint8) { return 9; }
    function _dec2() internal pure override returns (uint8) { return 9; }
}
