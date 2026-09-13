// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Weighted_PonsV1Se_Policy_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Weighted_PonsV1Se_Policy_Decimals.sol";

/// @notice Combo `B_P18_R6`. pair/launch 18-dec; other configurable leg 6-dec. vaultShare / detfToken stay 18.
contract UniswapV4Detf_Weighted_PonsV1Se_Policy_B_P18_R6 is UniswapV4Detf_Weighted_PonsV1Se_Policy_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 18; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }
}
