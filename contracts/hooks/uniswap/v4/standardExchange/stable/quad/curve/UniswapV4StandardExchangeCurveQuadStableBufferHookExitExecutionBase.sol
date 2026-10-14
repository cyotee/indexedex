// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";
import {IUniswapV4StandardExchangeCurveQuadStableBufferHook} from "./interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookExitExecutionBase is UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase {
    using SafeERC20 for IERC20;

    function _exitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn, address to, uint256 amountOutMin, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (sharesIn == 0) revert ZeroAmount();
        if (!Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        uint256 protocolShares = _maybeMintProtocolFee();
        amountOut = _quoteExitSingleExactBptIn(tokenOut, sharesIn);
        if (amountOut < amountOutMin) revert Slippage();
        uint8 idx = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        uint256 invOut = _singleExitInvOut(idx, sharesIn);
        if (invOut >= _nativeAt(idx)) revert WouldZeroReserve();
        _burnLp(msg.sender, sharesIn);
        if (l.standardExchanges[idx] != address(0)) {
            _unwrapSeShares(idx, invOut, to);
        } else {
            _debitRawIntentional(idx, invOut);
            IERC20(tokenOut).safeTransfer(to, invOut);
        }
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.WithdrawSingle(
            msg.sender, to, tokenOut, amountOut, sharesIn, protocolShares
        );
    }

    function _exitSingleAssetExactBptInFlexible(address tokenOut, uint256 sharesIn, bool receiveSeShare, address to, uint256 amountOutMin, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        _requireDeadline(deadline);
        return _exitSingleAssetFrom(msg.sender, tokenOut, sharesIn, receiveSeShare, to, amountOutMin);
    }
}
