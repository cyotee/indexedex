// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Weighted_Univ3Se_ProductLaw_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Weighted_Univ3Se_ProductLaw_Decimals.sol";

/// @notice Combo `B_P18_R9`. pairToken/pair0 18-dec; other/rate 9-dec; remaining 18. SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible.
contract UniswapV4Detf_Weighted_Univ3Se_ProductLaw_B_P18_R9 is UniswapV4Detf_Weighted_Univ3Se_ProductLaw_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 18; }
    function _rateDecimals() internal pure override returns (uint8) { return 9; }
}
