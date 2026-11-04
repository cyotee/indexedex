// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {UniswapV4FullSpreadStandardExchangeVaultComponentBindings} from "./UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";
import {UniswapV4FullSpreadStandardExchangeVaultExecution as Execution} from "./UniswapV4FullSpreadStandardExchangeVaultExecution.sol";

contract UniswapV4FullSpreadStandardExchangeVaultCallbackTarget is
    IUnlockCallback,
    UniswapV4FullSpreadStandardExchangeVaultComponentBindings
{
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        return Execution.onCallback(data);
    }
}
