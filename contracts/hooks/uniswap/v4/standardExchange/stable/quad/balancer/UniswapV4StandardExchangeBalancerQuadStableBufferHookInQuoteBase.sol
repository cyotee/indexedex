// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {NativeStandardYieldQuoteBase} from "contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";

abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookInQuoteBase is
    NativeStandardYieldQuoteBase, UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore
{
    struct ExactInOutput {
        uint256 amountOut;
        uint256 sharesOut;
    }

    function _previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        internal view override returns (uint256)
    {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) {
            if (address(tokenIn) == address(tokenOut)) revert LiquidityRoute.InvalidLiquidityRoute();
            return address(tokenOut) == address(this)
                ? _entryPreviewJoinSingleAssetExactIn(address(tokenIn), amountIn)
                : _entryPreviewExitSingleAssetExactBptIn(address(tokenOut), amountIn);
        }
        return _previewSwapExactInContext(address(tokenIn), address(tokenOut), amountIn, false, address(0)).amountOut;
    }

    function _previewSwapExactInContext(address tokenIn, address tokenOut, uint256 amountIn, bool funded, address manager)
        internal view returns (ExactInOutput memory output)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert InvalidPair();
        uint8 i = _tokenIndex(tokenIn);
        uint8 j = _tokenIndex(tokenOut);
        uint256[] memory rated = manager == address(0) ? _ratedWadAllForSwapIn(i, funded ? amountIn : 0) : ClaimLib.ratedWadAllWithContext(manager);
        if (rated[i] == 0 || rated[j] == 0) revert SwapNotLive();

        Repo.Layout storage l = Repo._layout();
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();

        uint256 netIn = Math.applyTradingFeeNet(amountIn, feeWad);
        uint256 ratedInflow = manager == address(0) || l.standardExchanges[i] == address(0) || l.standardExchanges[i] == l.tokens[i]
            ? _mapPairInToRatedWad(i, netIn) : ClaimLib.pairInWithContext(i, netIn, manager);
        (output.amountOut, output.sharesOut) = ClaimLib.quoteSwapExactInContext(i, j, rated, ratedInflow, _amp(), manager);
    }

    /// @dev Exclude funded raw input from the pre-swap book.
    function _ratedWadAllForSwapIn(uint8 iIn, uint256 amountInPair)
        internal view returns (uint256[] memory scaled)
    {
        scaled = new uint256[](Repo._numTokens());
        Repo.Layout storage l = Repo._layout();
        for (uint8 k; k < Repo._numTokens(); ++k) {
            uint256 pairUnits = _ratedPairUnits(k);
            if (k == iIn && l.standardExchanges[k] == address(0) && amountInPair > 0) {
                uint256 face = IERC20(l.tokens[k]).balanceOf(address(this));
                uint256 book = l.rawReserves[k];
                uint256 free = face > book ? face - book : 0;
                if (free >= amountInPair) {
                    pairUnits = face - amountInPair;
                }
            }
            scaled[k] = Math.scaleTo(pairUnits, l.ratedScales[k]);
        }
    }

    function _mapPairInToRatedWad(uint8 i, uint256 pairAmount) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (se == address(0) || se == l.tokens[i]) {
            address rpRaw = l.rateProviders[i];
            uint256 units = rpRaw == address(0)
                ? pairAmount
                : Math.ratedPairUnits(pairAmount, _getRateFailClosed(rpRaw), l.invScales[i], l.ratedScales[i]);
            return Math.scaleTo(units, l.ratedScales[i]);
        }
        uint256 shares =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(l.tokens[i]), pairAmount, IERC20(se));
        if (shares == 0) return 0;
        address rp = l.rateProviders[i];
        if (rp == address(0)) revert ClaimLib.RateProviderRequired();
        uint256 pairUnits = Math.ratedPairUnits(shares, _getRateFailClosed(rp), ClaimLib.shareScale(se), l.ratedScales[i]);
        return Math.scaleTo(pairUnits, l.ratedScales[i]);
    }
}
