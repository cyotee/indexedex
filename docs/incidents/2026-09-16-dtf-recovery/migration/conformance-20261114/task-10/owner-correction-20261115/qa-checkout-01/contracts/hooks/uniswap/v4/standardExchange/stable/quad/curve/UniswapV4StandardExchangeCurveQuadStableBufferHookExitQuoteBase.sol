// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookTarget} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";

abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase is UniswapV4StandardExchangeCurveQuadStableBufferHookTarget {
    function _quoteExitSingleExactBptIn(address tokenOut, uint256 sharesIn) internal view returns (uint256) {
        return ClaimLib.previewSingleExit(_tokenIndex(tokenOut), sharesIn, _totalSupply(), false);
    }

    function _quoteExitSingleExactBptInFlexible(address tokenOut, uint256 sharesIn, bool receiveSeShare)
        internal view returns (uint256)
    {
        uint8 idx = _tokenIndex(tokenOut);
        if (receiveSeShare && Repo._layout().standardExchanges[idx] == address(0)) revert SeShareNotBuffered();
        return ClaimLib.previewSingleExit(idx, sharesIn, _totalSupply(), receiveSeShare);
    }
}
