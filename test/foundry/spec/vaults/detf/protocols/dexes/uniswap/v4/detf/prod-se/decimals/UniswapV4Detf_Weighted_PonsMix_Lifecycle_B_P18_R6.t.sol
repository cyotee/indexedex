// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Weighted_PonsMix_Lifecycle_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Weighted_PonsMix_Lifecycle_Decimals.sol";

/// @notice Combo `B_P18_R6`. pair/launch 18-dec; other configurable leg 6-dec. vaultShare / detfToken stay 18.
contract UniswapV4Detf_Weighted_PonsMix_Lifecycle_B_P18_R6 is UniswapV4Detf_Weighted_PonsMix_Lifecycle_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 18; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }
}
