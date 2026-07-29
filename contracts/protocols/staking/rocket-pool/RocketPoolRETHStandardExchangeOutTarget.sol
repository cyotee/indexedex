// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

import {
    RocketPoolRETHStandardExchangeCommon
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol";

/**
 * @title RocketPoolRETHStandardExchangeOutTarget
 * @notice Exact-out Standard Exchange surface for Rocket Pool rETH SE.
 */
contract RocketPoolRETHStandardExchangeOutTarget is
    RocketPoolRETHStandardExchangeCommon,
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

        // SE redeem exact-out
        if (_isSeShare(in_)) {
            if (!_isAsset(out_)) revert InvalidRoute(in_, out_);
            amountIn = _quoteExactOut(in_, out_, amountOut);
            if (amountIn > maxAmountIn) revert Slippage();
            _burnShares(amountIn);
            _payAsset(out_, amountOut, recipient);
            return amountIn;
        }

        // asset → SE mint exact-out
        if (_isSeShare(out_)) {
            if (!_isAsset(in_)) revert InvalidRoute(in_, out_);
            amountIn = _quoteExactOut(in_, out_, amountOut);
            if (amountIn > maxAmountIn) revert Slippage();

            uint256 totalBefore = totalReserveEth();
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            uint256 ethValue = _creditAssetToReserve(in_, actualIn);
            uint256 minted = _convertEthDeltaToShares(ethValue, totalBefore);
            if (minted < amountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            if (in_ == weth()) {
                _bestEffortStakeOverageTowardTarget();
            }
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
