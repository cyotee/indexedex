// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {
    RocketPoolRETHStandardExchangeCommon
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol";

/**
 * @title RocketPoolRETHStandardExchangeInTarget
 * @notice Exact-in Standard Exchange surface for Rocket Pool rETH SE.
 * @dev No exchangeInEth / native ETH entry. Previews never gate on sleeve/capacity/burn.
 */
contract RocketPoolRETHStandardExchangeInTarget is
    RocketPoolRETHStandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeIn
{
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
            // D22: best-effort soft stake overage toward liquid target
            if (in_ == weth()) {
                _bestEffortStakeOverageTowardTarget();
            }
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
}
