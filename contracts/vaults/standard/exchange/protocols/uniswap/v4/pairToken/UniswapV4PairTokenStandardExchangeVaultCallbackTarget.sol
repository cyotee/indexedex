// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {UniswapV4PairTokenStandardExchangeVaultExecution as Execution} from "./UniswapV4PairTokenStandardExchangeVaultExecution.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultCallbackTarget[]
/// @notice The sole manager callback surface; authentication belongs to the shared engine.
contract UniswapV4PairTokenStandardExchangeVaultCallbackTarget is IUnlockCallback {
    // tag::unlockCallback-91dd7346[]
    /// @inheritdoc IUnlockCallback
    /// @custom:signature unlockCallback(bytes)
    /// @custom:selector 0x91dd7346
    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        return Execution.unlockCallback(data_);
    }
    // end::unlockCallback-91dd7346[]
}
// end::UniswapV4PairTokenStandardExchangeVaultCallbackTarget[]
