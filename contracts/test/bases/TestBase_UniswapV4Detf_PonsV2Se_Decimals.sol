// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf_PonsV2Se} from
    "contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol";

/// @notice H-CP-P2 decimals TestBase. Launch token and WETH quote stay 18 (D9).
/// @dev Combo IDs `P18_R6` / `P18_R9` live on suite wrappers. Does not inherit
///      `TestBase_UniswapV4Detf` (gold R-5 field clash).
abstract contract TestBase_UniswapV4Detf_PonsV2Se_Decimals is TestBase_UniswapV4Detf_PonsV2Se {
    function _pairDecimals() internal pure virtual returns (uint8) {
        return 18;
    }

    function _rateDecimals() internal pure virtual returns (uint8) {
        return 18;
    }
}
