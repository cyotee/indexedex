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
function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut) external view returns (uint256 amountOut, uint256 amountRefunded) {
        return (_previewExchangeIn(tokenIn, amountIn, tokenOut), 0);
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
        _requireDeadline(deadline);
        if (ERC20Repo._totalSupply() == 0) revert NotLive();
        _requireNonZero(sharesOut);
        uint256 previewIn = _singlePreviewDeposit(tokenIn, amountInMax);
        if (previewIn < sharesOut) revert InsufficientLpOut();
        uint256 beforeBalance = IERC20(tokenIn).balanceOf(msg.sender);
        PullLib.pullErc20Single(tokenIn, amountInMax);
        ClaimLib.singleComponentJoin(tokenIn, amountInMax, to, sharesOut, sharesOut);
        _syncReserves();
        return beforeBalance - IERC20(tokenIn).balanceOf(msg.sender);
    }

    /// @notice CP previewDepositSingle entry point.
    function previewDepositSingle(address tokenIn, uint256 amountIn) external view returns (uint256 lpAmount) {
        return _singlePreviewDeposit(tokenIn, amountIn);
    }

    function previewClaimAfterJoin(uint256 detfIn, uint256 lpAmount) external view returns (uint256) {
        return ClaimLib.previewRawClaimAfterJoin(detfIn, lpAmount);
    }



    /// @notice CP previewZapSplit entry point.
    function previewZapSplit(address tokenIn, uint256 amountIn)
        external view returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn)
    {
        return ClaimLib.previewComponentSplit(tokenIn, amountIn);
    }

}
