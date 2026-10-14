// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeStandardYieldPreviewTarget} from "contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookInExecutionBase} from "./UniswapV4DualStandardExchangeBufferConstantProductHookInExecutionBase.sol";
import {NativeStandardYieldQuoteBase} from "contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib as DepositQuoteLib} from "./UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol";

import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookPullLib as PullLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookPullLib.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

/// @title UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget
/// @notice Role Target for size-split Dual SE CP Buffer hook (Option 1a).
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget is UniswapV4DualStandardExchangeBufferConstantProductHookInExecutionBase, NativeStandardYieldPreviewTarget {
    function getTokensIn() public view override returns (address[] memory tokens_) {
        Repo.Layout storage l = Repo._layout();
        tokens_ = new address[](4);
        tokens_[0] = l.token0;
        tokens_[1] = l.token1;
        tokens_[2] = l.se0;
        tokens_[3] = l.se1;
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        uint256 supply_ = _supplyAfterProtocolMint();
        return supply_ == 0 ? 1e18 : FullMath.mulDiv(Math.sqrt(_wadProduct()), 1e18, supply_);
    }
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut) external view returns (uint256) {
        return _previewExchangeIn(tokenIn, amountIn, tokenOut);
    }

    using SafeERC20 for IERC20;

    function withdraw(
        uint256 lpAmount,
        address to,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        return _withdraw(lpAmount, to, minAmount0, minAmount1, deadline);
    }


    function withdrawFlexible(
        uint256 lpAmount,
        address to,
        bool receiveSeShare0,
        bool receiveSeShare1,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        return _withdrawFlexible(
            lpAmount, to, receiveSeShare0, receiveSeShare1, minAmount0, minAmount1, deadline
        );
    }


    function previewWithdraw(uint256 lpAmount)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _previewWithdraw(lpAmount);
    }


    function previewWithdrawFlexible(uint256 lpAmount, bool receiveSeShare0, bool receiveSeShare1)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _previewWithdrawFlexible(lpAmount, receiveSeShare0, receiveSeShare1);
    }

    function exitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        uint256 min0 = amountsMin.length > 0 ? amountsMin[0] : 0;
        uint256 min1 = amountsMin.length > 1 ? amountsMin[1] : 0;
        (uint256 a0, uint256 a1) = _withdraw(shares, to, min0, min1, deadline);
        amounts = new uint256[](2);
        amounts[0] = a0;
        amounts[1] = a1;
    }

    function previewExitProportional(uint256 shares) external view returns (uint256[] memory amounts) {
        (uint256 a0, uint256 a1) = _previewWithdraw(shares);
        amounts = new uint256[](2);
        amounts[0] = a0;
        amounts[1] = a1;
    }

    function exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        return _exitLiquidityExactIn(tokenOut, sharesIn, to, amountOutMin, deadline, address(0));
    }

    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewLiquidityExit(tokenOut, sharesIn);
    }

    function exitSingleAssetExactTokenOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external pure returns (uint256) {
        tokenOut;
        amountOut;
        to;
        sharesInMax;
        deadline;
        revert InvalidRoute();
    }

    function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256)
    {
        tokenOut;
        amountOut;
        return 0;
    }

    /// @dev Dual has no DETF self-leg: proportional tokenOut only, no residual swap (H2).
    function previewBurnToToken(uint256 lpAmount, address tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (lpAmount == 0 || !_isLive()) return 0;
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenOut);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        Repo.Layout storage l = Repo._layout();
        (uint256 a0, uint256 a1) = _previewWithdraw(lpAmount);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            tokenOut = l.legs.pairOfStandardExchange[tokenOut];
        }
        if (tokenOut == l.currency0) return a0;
        if (tokenOut == l.currency1) return a1;
        return 0;
    }

    function _exitSingleAsset(address tokenOut, uint256 sharesIn, address to, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        return _exitSingleAssetFrom(msg.sender, tokenOut, sharesIn, to, deadline);
    }

}
