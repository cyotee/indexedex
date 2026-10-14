// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookTarget} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";

abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase is UniswapV4StandardExchangeCurveQuadStableBufferHookTarget {
    function _singleExitInvOut(uint8 idx, uint256 sharesIn) internal view returns (uint256 invOut) {
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256 outS = Math.singleExitExactBptInAmountOut(
            _invWadAll(), sharesIn, idx, _amp(), _previewSupplyAfterProtocolMint(), feeWad
        );
        invOut = Math.descale(outS, Repo._layout().invScales[idx]);
    }

    function _quoteExitSingleExactBptIn(address tokenOut, uint256 sharesIn)
        internal view returns (uint256 amountOut)
    {
        uint8 idx = _tokenIndex(tokenOut);
        uint256 invOut = _singleExitInvOut(idx, sharesIn);
        uint256[4] memory inv;
        inv[idx] = invOut;
        uint256[4] memory pair = _invToPairOutPreview(inv);
        amountOut = pair[idx];
    }

    function _quoteExitSingleExactBptInFlexible(address tokenOut, uint256 sharesIn, bool receiveSeShare)
        internal view returns (uint256 amountOut)
    {
        uint8 idx = _tokenIndex(tokenOut);
        if (receiveSeShare && Repo._layout().standardExchanges[idx] == address(0)) {
            revert SeShareNotBuffered();
        }
        uint256 invOut = _singleExitInvOut(idx, sharesIn);
        if (receiveSeShare || Repo._layout().standardExchanges[idx] == address(0)) {
            amountOut = invOut;
        } else {
            address se = Repo._layout().standardExchanges[idx];
            amountOut = IStandardExchangeIn(se).previewExchangeIn(
                IERC20(se), invOut, IERC20(tokenOut)
            );
        }
    }
}
