// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    AerodromeStandardExchangeOutQueryTarget
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutQueryTarget.sol";
import {
    AerodromeStandardExchangeOutExecuteTarget
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutExecuteTarget.sol";

/// @dev Legacy monotarget name: union of query + execute for diagnostics.
abstract contract AerodromeStandardExchangeOutTarget is
    AerodromeStandardExchangeOutQueryTarget,
    AerodromeStandardExchangeOutExecuteTarget
{}
