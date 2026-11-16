// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4SingleSEBufferHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/decimals/UniswapV4SingleSEBufferHook_Decimals.sol";

/// @notice Combo `P6_R9`. pairToken 6-dec; vaultShare/hook LP stay 18. Wrap pool is pair vs SE share.
contract UniswapV4SingleSEBufferHook_P6_R9 is UniswapV4SingleSEBufferHook_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
