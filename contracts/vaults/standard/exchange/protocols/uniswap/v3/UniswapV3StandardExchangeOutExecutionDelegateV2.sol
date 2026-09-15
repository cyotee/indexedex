// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

import {
    UniswapV3StandardExchangeOutBaseV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3StandardExchangeOutBaseV2.sol";

contract UniswapV3StandardExchangeOutExecutionDelegateV2 is UniswapV3StandardExchangeOutBaseV2 {
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
            delivered = _secureShareDelivery(maxSharesToBurn, true);
        }

        if (!canOpenBoundPoolOps()) {
            uint256 freeOut = IERC20(tokenOut).balanceOf(address(this));
            if (freeOut < minAmountOut) {
                revert UniswapV3Exchange_InsufficientLocalReserve(tokenOut, minAmountOut, freeOut);
            }
            state.actualOut = minAmountOut;
            if (pretransferred) {
                ERC20Repo._burn(address(this), sharesBurned);
                _refundUnusedShares(delivered, sharesBurned, msg.sender);
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
            _refundUnusedShares(delivered, sharesBurned, msg.sender);
        } else {
            ERC20Repo._burn(msg.sender, sharesBurned);
        }
        _transferCurrency(tokenOut, recipient, state.actualOut);
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
}
