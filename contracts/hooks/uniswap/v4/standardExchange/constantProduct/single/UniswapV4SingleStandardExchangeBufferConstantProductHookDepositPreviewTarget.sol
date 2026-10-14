// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib as PullLib} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib.sol";
import {NativeStandardYieldPreviewCallsTarget as NativeStandardYieldPreviewTarget} from "contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase.sol";

import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as ClaimLib}
    from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget
/// @notice CP deposit and join previews using the shared reserve accounting.
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget is
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon, NativeStandardYieldPreviewTarget
{
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut) external view returns (uint256) {
        return _previewExchangeIn(tokenIn, amountIn, tokenOut);
    }

    function isValidTokenIn(address token_) public view override returns (bool) {
        Repo.Layout storage l_ = Repo._layout();
        return token_ == l_.rawToken || token_ == l_.pairToken || token_ == l_.standardExchange;
    }
    function isValidTokenOut(address token_) public view override returns (bool) {
        Repo.Layout storage l_ = Repo._layout();
        return token_ == l_.rawToken || token_ == l_.pairToken;
    }

    /// @notice CP previewJoinSingleAssetExactIn entry point.
    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn) external view returns (uint256 shares) {
        return _singlePreviewJoin(tokenIn, amountIn);
    }

    /// @notice CP previewJoinSingleAssetExactOut entry point.
    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        external
        view
        returns (uint256 amountIn)
    {
        if (!_isLive() || sharesOut == 0) return 0;
        return 0;
    }

    function joinSingleAssetExactOut(address tokenIn, uint256 sharesOut, address to, uint256 amountInMax, uint256 deadline)
        external onlyLiquidityOwner nonReentrant returns (uint256)
    {
        if (!_isLive()) revert NotLive();
        uint256 previewIn = _singlePreviewDeposit(tokenIn, amountInMax);
        if (previewIn < sharesOut) revert InsufficientLpOut();
        _mintProtocolFeeIfNeeded();
        PullLib.pullErc20Single(tokenIn, amountInMax);
        _depositSingle(tokenIn, amountInMax, to, sharesOut, deadline);
        return amountInMax;
    }

    /// @notice CP previewDepositSingle entry point.
    function previewDepositSingle(address tokenIn, uint256 amountIn) external view returns (uint256 lpAmount) {
        return _singlePreviewDeposit(tokenIn, amountIn);
    }

    function previewClaimAfterJoin(uint256 detfIn, uint256 lpAmount) external view returns (uint256 detfValue) {
        Repo.Layout storage l = Repo._layout();
        SingleZapQuote memory q = _singleZapState(l.rawToken, detfIn);
        uint256 supply;
        (q,, supply) = _singleFinishDeposit(q, _supplyAfterProtocolMint());
        supply = _quoteClaimSupplyAfterDust(q, supply);
        if (lpAmount == 0 || supply == 0) return 0;
        uint256 rawOut = q.rawReserve * lpAmount / supply;
        uint256 seBalance = IStandardExchangeTransitionQuote(l.standardExchange).quoteShareBalance(q.state);
        uint256 seOut = seBalance * lpAmount / supply;
        uint256 rawCap = q.rawReserve > Repo.MAX_DUST_WEI ? q.rawReserve - Repo.MAX_DUST_WEI : 0;
        uint256 seCap = seBalance > Repo.MAX_DUST_WEI ? seBalance - Repo.MAX_DUST_WEI : 0;
        detfValue = rawOut > rawCap ? rawCap : rawOut;
        if (seOut > seCap) seOut = seCap;
        if (seOut == 0) return detfValue;
        uint256 pairOut = IStandardExchangeTransitionQuote(l.standardExchange).quoteAssets(q.state, seOut);
        if (pairOut == 0) return detfValue;
        return detfValue + _quotePairToRawAfterJoin(q, pairOut);
    }

    function _quoteClaimSupplyAfterDust(SingleZapQuote memory q, uint256 supply) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 pairDust = IERC20(l.pairToken).balanceOf(address(this)) + q.pairAdded;
        if (pairDust <= Repo.MAX_DUST_WEI) return supply;
        uint256 beforePair = q.pairReserve;
        (q.state,,, q.pairReserve) = _singleMintableDeposit(q.state, pairDust - Repo.MAX_DUST_WEI);
        (bool feeOn,, uint256 ownerFeeShare) = _feeOnAndShare();
        if (!feeOn) return supply;
        uint256 rawWad = Math.toWad(q.rawReserve, _decimalsOf(l.rawToken));
        return supply + Math.calculateProtocolFee(
            supply, rawWad * Math.toWad(q.pairReserve, _decimalsOf(l.pairToken)),
            rawWad * Math.toWad(beforePair, _decimalsOf(l.pairToken)), ownerFeeShare
        );
    }

    function _quotePairToRawAfterJoin(SingleZapQuote memory q, uint256 pairOut) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        (,,, uint256 claimAfter) = _singleMintableDeposit(q.state, pairOut);
        uint256 delta = claimAfter > q.pairReserve ? claimAfter - q.pairReserve : 0;
        return Math.fromWadFloor(Math.saleQuote(
            Math.toWad(delta, _decimalsOf(l.pairToken)), Math.toWad(q.pairReserve, _decimalsOf(l.pairToken)),
            Math.toWad(q.rawReserve, _decimalsOf(l.rawToken))
        ), _decimalsOf(l.rawToken));
    }

    /// @notice CP previewZapSplit entry point.
    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn)
    {
        (amountToSwap, amountOtherOut, amountKeptIn) = _previewZapSplit(tokenIn, amountIn);
        if (tokenIn == Repo._layout().rawToken && ClaimLib.supportsTransitionQuote(
            Repo._layout().standardExchange, Repo._layout().pairToken, address(this)
        )) {
            SingleZapQuote memory q = _singleZapState(tokenIn, amountIn);
            amountOtherOut = q.pairAdded;
        }
    }

}
