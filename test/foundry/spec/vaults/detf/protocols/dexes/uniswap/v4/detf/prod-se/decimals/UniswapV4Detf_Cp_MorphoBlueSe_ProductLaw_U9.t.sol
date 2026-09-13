// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw_Decimals.sol";

/// @notice Combo `U9`. pairToken 9-dec; other/rate 18-dec. SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible.
contract UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw_U9 is UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 9; }
    function _rateDecimals() internal pure override returns (uint8) { return 18; }
}
