// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol";


/// @notice B6 flexible multipath deposit surface (Option 1a size split).
abstract contract UniswapV4StandardExchangeOrbitalBufferHookDepositFlexibleTarget is UniswapV4StandardExchangeOrbitalBufferHookCommon {
    using SafeERC20 for IERC20;

    function depositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        DepositFlexibleVars memory v;
        v.amount0 = amount0;
        v.amount0IsSeShare = amount0IsSeShare;
        v.amount1 = amount1;
        v.amount1IsSeShare = amount1IsSeShare;
        v.amount2 = amount2;
        v.amount2IsSeShare = amount2IsSeShare;
        v.to = to;
        v.sharesMin = sharesMin;
        return _depositFlexible(v, deadline);
    }

    function previewDepositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare
    ) external view returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        DepositFlexibleVars memory v;
        v.amount0 = amount0;
        v.amount0IsSeShare = amount0IsSeShare;
        v.amount1 = amount1;
        v.amount1IsSeShare = amount1IsSeShare;
        v.amount2 = amount2;
        v.amount2IsSeShare = amount2IsSeShare;
        return _previewDepositFlexible(v);
    }
}
