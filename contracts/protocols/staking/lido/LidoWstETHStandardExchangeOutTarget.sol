// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

import {LidoWstETHStandardExchangeCommon} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol";

/**
 * @title LidoWstETHStandardExchangeOutTarget
 * @notice Exact-out Standard Exchange surface for Lido SE.
 * @dev Closed-form routes (no binary search). Previews never gate on liquid sleeve;
 *      execution reverts `InsufficientLiquidReserve` when paying WETH beyond sleeve.
 *
 * Supported exact-out routes:
 *   WETH/stETH/wstETH → SE | SE → WETH/stETH/wstETH
 *   WETH ↔ stETH/wstETH | stETH ↔ wstETH
 */
contract LidoWstETHStandardExchangeOutTarget is
    LidoWstETHStandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeOut
{
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        if (amountOut == 0) revert ZeroAmount();
        return _quoteExactOut(address(tokenIn), address(tokenOut), amountOut);
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (amountOut == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        address in_ = address(tokenIn);
        address out_ = address(tokenOut);

        // SE redeem exact-out: burn shares for fixed asset out
        if (_isSeShare(in_)) {
            if (!_isAsset(out_)) revert InvalidRoute(in_, out_);
            amountIn = _quoteExactOut(in_, out_, amountOut);
            if (amountIn > maxAmountIn) revert Slippage();
            _burnShares(amountIn);
            _payAsset(out_, amountOut, recipient);
            return amountIn;
        }

        // asset → SE mint exact-out (fixed shares out)
        if (_isSeShare(out_)) {
            if (!_isAsset(in_)) revert InvalidRoute(in_, out_);
            amountIn = _quoteExactOut(in_, out_, amountOut);
            if (amountIn > maxAmountIn) revert Slippage();

            uint256 totalBefore = totalReserveEth();
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            uint256 ethValue = _creditAssetToReserve(in_, actualIn);
            uint256 minted = _convertEthDeltaToShares(ethValue, totalBefore);
            if (minted < amountOut) revert Slippage();
            // Mint exact amountOut to user; any rounding surplus stays in reserve (NAV conserves)
            _mintWithUsageFee(recipient, amountOut);
            return amountIn;
        }

        // asset → asset exact-out
        if (_isAsset(in_) && _isAsset(out_)) {
            amountIn = _quoteExactOut(in_, out_, amountOut);
            if (amountIn > maxAmountIn) revert Slippage();
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            if (actualIn < amountIn) revert InsufficientDeposit(amountIn, actualIn);
            uint256 produced = _execAssetToAsset(in_, actualIn, out_, recipient);
            if (produced < amountOut) revert Slippage();
            return amountIn;
        }

        revert InvalidRoute(in_, out_);
    }
}
