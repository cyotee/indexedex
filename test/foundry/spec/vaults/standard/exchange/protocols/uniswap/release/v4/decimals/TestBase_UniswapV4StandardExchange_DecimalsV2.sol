// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4StandardExchangeV2} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchangeV2.sol";

/**
 * @title TestBase_UniswapV4StandardExchange_DecimalsV2
 * @notice Combo-decimal helpers. Gold TestBase does not construct pair tokens.
 *         Suites mint `MintableERC20Decimals` at `_tokenADecimals` / `_tokenBDecimals`.
 *         pairToken = tokenA. vaultShare stays 18.
 */
abstract contract TestBase_UniswapV4StandardExchange_DecimalsV2 is TestBase_UniswapV4StandardExchangeV2 {
    function _tokenADecimals() internal pure virtual returns (uint8);
    function _tokenBDecimals() internal pure virtual returns (uint8);

    function _uA(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenADecimals()));
    }

    function _uB(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenBDecimals()));
    }
}
