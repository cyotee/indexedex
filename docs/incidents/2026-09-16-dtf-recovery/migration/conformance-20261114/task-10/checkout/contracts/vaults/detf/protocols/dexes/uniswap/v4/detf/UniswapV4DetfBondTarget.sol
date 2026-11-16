// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {UniswapV4DetfTarget} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol";

/// @notice Bond entrypoints for the universal DETF diamond.
abstract contract UniswapV4DetfBondTarget is UniswapV4DetfTarget {
    /// @notice Acquires protocol LP and opens an NFT with funded, staked DETF principal that vests linearly.
    /// @dev The returned shares are acquired protocol LP, not an NFT redemption entitlement.
    function bond(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares) {
        return _entryBond(tokenIn, amountIn, lockDuration, recipient, pretransferred, deadline);
    }

}
