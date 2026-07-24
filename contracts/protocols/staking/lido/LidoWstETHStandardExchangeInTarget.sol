// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IWstETH} from "@crane/contracts/protocols/staking/ethereum/lido/interfaces/IWstETH.sol";
import {IStETH} from "@crane/contracts/protocols/staking/ethereum/lido/interfaces/IStETH.sol";

import {LidoWstETHStandardExchangeCommon} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol";

/**
 * @title LidoWstETHStandardExchangeInTarget
 * @notice Exact-in Standard Exchange surface for Lido SE.
 * @dev Closed-form routes (no binary search). Previews never gate on liquid sleeve;
 *      execution reverts `InsufficientLiquidReserve` when paying WETH beyond sleeve.
 *
 * Supported exact-in routes:
 *   WETH/stETH/wstETH → SE | SE → WETH/stETH/wstETH
 *   WETH ↔ stETH/wstETH | stETH ↔ wstETH
 */
contract LidoWstETHStandardExchangeInTarget is
    LidoWstETHStandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeIn
{
    using SafeERC20 for IERC20;

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        return _quoteExactIn(address(tokenIn), amountIn, address(tokenOut));
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        address in_ = address(tokenIn);
        address out_ = address(tokenOut);

        // SE redeem exact-in: burn shares, pay asset
        if (_isSeShare(in_)) {
            if (!_isAsset(out_)) revert InvalidRoute(in_, out_);
            amountOut = _quoteExactIn(in_, amountIn, out_);
            if (amountOut < minAmountOut) revert Slippage();
            _burnShares(amountIn);
            _payAsset(out_, amountOut, recipient);
            return amountOut;
        }

        // asset → SE mint exact-in
        if (_isSeShare(out_)) {
            if (!_isAsset(in_)) revert InvalidRoute(in_, out_);
            uint256 totalBefore = totalReserveEth();
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            uint256 ethValue = _creditAssetToReserve(in_, actualIn);
            amountOut = _convertEthDeltaToShares(ethValue, totalBefore);
            if (amountOut < minAmountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            return amountOut;
        }

        // asset → asset exact-in
        if (_isAsset(in_) && _isAsset(out_)) {
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            amountOut = _execAssetToAsset(in_, actualIn, out_, recipient);
            if (amountOut < minAmountOut) revert Slippage();
            return amountOut;
        }

        revert InvalidRoute(in_, out_);
    }

    /// @notice Native ETH → submit stETH → wrap wstETH → mint SE (or stop at intermediate).
    function exchangeInEth(IERC20 tokenOut, uint256 minAmountOut, address recipient, uint256 deadline)
        external
        payable
        nonReentrant
        returns (uint256 amountOut)
    {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (msg.value == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        address st_ = stETH();
        address wst_ = wstETH();
        uint256 totalBefore = totalReserveEth();

        uint256 stBefore = IERC20(st_).balanceOf(address(this));
        IStETH(st_).submit{value: msg.value}(address(0));
        uint256 stGot = IERC20(st_).balanceOf(address(this)) - stBefore;
        if (stGot == 0) stGot = msg.value;

        if (address(tokenOut) == st_) {
            if (stGot < minAmountOut) revert Slippage();
            IERC20(st_).safeTransfer(recipient, stGot);
            return stGot;
        }

        IERC20(st_).forceApprove(wst_, stGot);
        uint256 wstOut = IWstETH(wst_).wrap(stGot);

        if (address(tokenOut) == wst_) {
            if (wstOut < minAmountOut) revert Slippage();
            IERC20(wst_).safeTransfer(recipient, wstOut);
            return wstOut;
        }

        if (address(tokenOut) == address(this)) {
            uint256 ethValue = _stEthFromWstEth(wstOut);
            amountOut = _convertEthDeltaToShares(ethValue, totalBefore);
            if (amountOut < minAmountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            return amountOut;
        }

        revert InvalidRoute(address(0), address(tokenOut));
    }
}
