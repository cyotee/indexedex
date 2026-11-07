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
        return _exitSingleAssetFrom(msg.sender, tokenOut, sharesIn, false, to, amountOutMin);
    }

    function _exitSingleAssetExactBptInFlexible(address tokenOut, uint256 sharesIn, bool receiveSeShare, address to, uint256 amountOutMin, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        _requireDeadline(deadline);
        return _exitSingleAssetFrom(msg.sender, tokenOut, sharesIn, receiveSeShare, to, amountOutMin);
    }
}
