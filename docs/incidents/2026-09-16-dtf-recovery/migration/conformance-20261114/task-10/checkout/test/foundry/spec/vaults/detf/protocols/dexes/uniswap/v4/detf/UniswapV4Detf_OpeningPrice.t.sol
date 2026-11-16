// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_OpeningPriceLayerBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OpeningPriceLayerBase.sol";

/// @notice CP gold opening vs creation T1/T2/T5 (WP-UDPL-POLICY). No T6.
contract UniswapV4Detf_OpeningPrice is UniswapV4Detf_OpeningPriceLayerBase {}
