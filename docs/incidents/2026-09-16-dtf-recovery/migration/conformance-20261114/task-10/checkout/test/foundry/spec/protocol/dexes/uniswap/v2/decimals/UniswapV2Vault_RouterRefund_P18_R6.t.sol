// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV2Vault_RouterRefund_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v2/decimals/UniswapV2Vault_RouterRefund_Decimals.sol";

/// @notice Combo `P18_R6`. pairToken (tokenA) = 18 decimals; other (tokenB) = 6 decimals.
/// @dev After Uniswap pair address sort, token0/token1 may swap; roles stay pairToken vs other.
contract UniswapV2Vault_RouterRefund_P18_R6 is UniswapV2Vault_RouterRefund_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
