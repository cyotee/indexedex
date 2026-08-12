// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol";

/// @dev Legacy monotarget name: union of role Targets for diagnostics only.
/// @dev Deployable Facets inherit a single role Target (not this type) for EIP-170.
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookTarget is
    UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget,
    UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget,
    UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget,
    UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget
{}
