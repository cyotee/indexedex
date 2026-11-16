// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {
    ConstantProductAccountingHandler
} from "test/foundry/spec/vaults/standard/exchange/invariant/ConstantProductAccountingHandler.sol";

/// @dev Canonical Aerodrome handler shares strict native accounting and production pool actions.
contract Handler_AerodromeStandardExchange is ConstantProductAccountingHandler {
    constructor(address vault_, address pool_) ConstantProductAccountingHandler(vault_, pool_, 2) {}
}
