// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4StandardExchangeOrbitalBufferHookHooksTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDepositTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositTarget.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookWithdrawTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookWithdrawTarget.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookSeTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol";

/// @dev Legacy monotarget name: union of role Targets for diagnostics only.
/// @dev Deployable Facets inherit a single role Target (not this type) for EIP-170.
abstract contract UniswapV4StandardExchangeOrbitalBufferHookTarget is
    UniswapV4StandardExchangeOrbitalBufferHookHooksTarget,
    UniswapV4StandardExchangeOrbitalBufferHookDepositTarget,
    UniswapV4StandardExchangeOrbitalBufferHookWithdrawTarget,
    UniswapV4StandardExchangeOrbitalBufferHookSeTarget
{}
