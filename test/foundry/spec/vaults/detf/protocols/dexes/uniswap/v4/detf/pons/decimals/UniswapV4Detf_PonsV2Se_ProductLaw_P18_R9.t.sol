// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_PonsV2Se_ProductLaw_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/decimals/UniswapV4Detf_PonsV2Se_ProductLaw_Decimals.sol";

/// @notice Combo `P18_R9`. Launch token 18; WETH quote 18 (D9). vaultShare / detfToken stay 18.
contract UniswapV4Detf_PonsV2Se_ProductLaw_P18_R9 is UniswapV4Detf_PonsV2Se_ProductLaw_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 18; }
    function _rateDecimals() internal pure override returns (uint8) { return 9; }
}
