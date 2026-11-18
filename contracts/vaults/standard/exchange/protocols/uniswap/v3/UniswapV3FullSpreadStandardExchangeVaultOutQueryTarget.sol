// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

abstract contract UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget {
    function previewExchangeOut(IERC20, IERC20, uint256) external pure returns (uint256) {
        return 0;
    }
}
