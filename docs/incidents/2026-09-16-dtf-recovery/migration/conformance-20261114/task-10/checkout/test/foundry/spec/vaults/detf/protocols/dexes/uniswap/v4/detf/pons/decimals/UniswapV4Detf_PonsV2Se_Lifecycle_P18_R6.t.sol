// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_PonsV2Se_Lifecycle_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/decimals/UniswapV4Detf_PonsV2Se_Lifecycle_Decimals.sol";

/// @notice Combo `P18_R6`. Launch token 18; WETH quote 18 (D9). vaultShare / detfToken stay 18.
contract UniswapV4Detf_PonsV2Se_Lifecycle_P18_R6 is UniswapV4Detf_PonsV2Se_Lifecycle_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 18; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }
}
