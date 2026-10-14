// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {
    ERC4626StandardExchangeQuoteTarget
} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol";

/// @dev Preview selector only. `exchangeIn` stays on `ERC4626StandardExchangeInTarget`.
contract ERC4626StandardExchangeInTargetExt is ERC4626StandardExchangeQuoteTarget {
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewExchangeIn(tokenIn, amountIn, tokenOut);
    }
}
