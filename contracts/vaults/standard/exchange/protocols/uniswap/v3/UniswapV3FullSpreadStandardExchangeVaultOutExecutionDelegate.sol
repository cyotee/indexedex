// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";

import {
    UniswapV3FullSpreadStandardExchangeVaultOutBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutBase.sol";

contract UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate is UniswapV3FullSpreadStandardExchangeVaultOutBase {
    function executeZapOutWithdrawal(
        address tokenOut,
        uint256 maxSharesToBurn,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred
    ) external returns (uint256 sharesBurned) {
        ZapOutState memory state;
        state.totalShares = IERC20(address(this)).totalSupply();

        sharesBurned = _previewZapOutWithdrawal(tokenOut, minAmountOut);
        if (sharesBurned == 0 || sharesBurned > maxSharesToBurn) {
            revert UniswapV3ExchangeOut_InsufficientInput();
        }

        uint256 delivered;
        if (pretransferred) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            delivered = _pretransferCredit(IERC20(address(this)), maxSharesToBurn);
            if (sharesBurned > delivered) {
                revert ISecurePullErrors.TransferDeltaInsufficient(sharesBurned, delivered);
            }
        }

        if (!canOpenBoundPoolOps()) {
            uint256 freeOut = IERC20(tokenOut).balanceOf(address(this));
            if (freeOut < minAmountOut) {
                revert UniswapV3Exchange_InsufficientLocalReserve(tokenOut, minAmountOut, freeOut);
            }
            state.actualOut = minAmountOut;
            if (pretransferred) {
                ERC20Repo._burn(address(this), sharesBurned);
                _refundUnusedShares(delivered < maxSharesToBurn ? delivered : maxSharesToBurn, sharesBurned, msg.sender);
            } else {
                ERC20Repo._burn(msg.sender, sharesBurned);
            }
            _transferCurrency(tokenOut, recipient, state.actualOut);
            _syncVaultReserves();
            return sharesBurned;
        }

        _collectManagedFees();
        state.actualOut = _executeFreeZapOutWithdrawalCore(tokenOut, sharesBurned, state.totalShares);
        if (state.actualOut < minAmountOut) revert UniswapV3ExchangeOut_SlippageExceeded();

        if (pretransferred) {
            ERC20Repo._burn(address(this), sharesBurned);
            _refundUnusedShares(delivered < maxSharesToBurn ? delivered : maxSharesToBurn, sharesBurned, msg.sender);
        } else {
            ERC20Repo._burn(msg.sender, sharesBurned);
        }
        // D55 (APEX F6): exact-output pays exactly the requested amount. The zap-out surplus above it
        // stays in the vault and is booked by `_syncVaultReserves` (D6), so preview and execution agree
        // on both the shares spent and the amount delivered.
        _transferCurrency(tokenOut, recipient, minAmountOut);
        _syncVaultReserves();
    }

    function _executeFreeZapOutWithdrawalCore(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        returns (uint256 actualOut)
    {
        bool outIsToken0 = tokenOut == _token0();
        address otherToken = outIsToken0 ? _token1() : _token0();
        (uint256 free0, uint256 free1) = _freeBalances();
        uint256 freePortionOther =
            outIsToken0 ? (free1 * sharesBurned) / totalShares : (free0 * sharesBurned) / totalShares;
        uint256 freeOutShare = outIsToken0 ? (free0 * sharesBurned) / totalShares : (free1 * sharesBurned) / totalShares;
        uint256 otherBefore = IERC20(otherToken).balanceOf(address(this));
        uint256 outBefore = IERC20(tokenOut).balanceOf(address(this));
        _burnCenterLiquidityForShares(sharesBurned, totalShares);
        _swapRemovedOtherPlusFreeShare(otherToken, tokenOut, freePortionOther, otherBefore);
        actualOut = _actualOutPlusFreeShare(tokenOut, outBefore, freeOutShare);
    }

    /// @dev D64 exact-out mint. `amountIn` is the closed-form minimal pair input for `sharesOut`
    /// (owed-inclusive reserve basis, so it equals `previewExchangeOut`). The full input is booked by
    /// `_syncVaultReserves`; any rounding surplus over the exact backing stays for existing holders
    /// (D6, NAV never decreases). Lives in the delegate so the OutFacet stays under EIP-170.
    function executeZapInMintExactOut(
        address tokenIn,
        uint256 maxAmountIn,
        uint256 sharesOut,
        address recipient,
        bool pretransferred
    ) external returns (uint256 amountIn) {
        if (sharesOut == 0) revert UniswapV3Exchange_ZeroAmount();
        IERC20 token = IERC20(tokenIn);
        uint256 credit = pretransferred ? _pretransferCredit(token, maxAmountIn) : 0;
        amountIn = _amountInForZapMint(tokenIn, sharesOut, credit);
        if (amountIn > maxAmountIn) revert UniswapV3ExchangeOut_InsufficientInput();

        uint256 inboundBefore = token.balanceOf(address(this));
        uint256 pullAmount = amountIn;
        if (pretransferred) {
            if (amountIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, credit);
            pullAmount = credit;
        }
        uint256 providedAmountIn = _secureTokenTransfer(token, pullAmount, pretransferred);
        if (pretransferred) inboundBefore -= providedAmountIn;
        _requireDelivered(amountIn, providedAmountIn);
        if (pretransferred) {
            uint256 balance = token.balanceOf(address(this));
            uint256 unusedInbound = balance > inboundBefore ? balance - inboundBefore : 0;
            uint256 leftover = providedAmountIn > amountIn ? providedAmountIn - amountIn : 0;
            uint256 refund = leftover < unusedInbound ? leftover : unusedInbound;
            if (refund > 0) _transferCurrency(tokenIn, msg.sender, refund);
        }

        _collectIfIdle();
        ERC20Repo._mint(recipient, sharesOut);
        _syncVaultReserves();
    }
}
