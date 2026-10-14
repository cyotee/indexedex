// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeStandardYieldExecutionTarget} from "contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol";
import {UniswapV4SeBufferHookLegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookInExecutionBase} from "./UniswapV4StandardExchangeWeightedBufferHookInExecutionBase.sol";

import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {DETFDecimalScaleLib} from "contracts/vaults/detf/common/core/DETFDecimalScaleLib.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookTarget
 * @notice Product logic: dual-scale weighted book, SE buffer-last LP, rated V4/SE swaps, MultiAssetLiquidity.
 * @dev No BaseHook / DeltaResolver inheritance. LP via ERC20Repo; inventory = face | live SE shares.
 */
import {
    UniswapV4StandardExchangeWeightedBufferHookSwapCore
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookSeTarget
 * @notice Standard Exchange swaps and native LP join/exit routes.
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHookExchangeCore is
    UniswapV4StandardExchangeWeightedBufferHookInExecutionBase,
    UniswapV4StandardExchangeWeightedBufferHookSwapCore
{
    using SafeERC20 for IERC20;

    function _validNativeToken(address token_) internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.numTokens; ++i) if (token_ == l.tokens[i]) return true;
        if (token_ == address(0)) return false;
        for (uint256 i; i < l.numTokens; ++i) if (token_ == l.standardExchanges[i]) return true;
        return false;
    }
    function _redeemHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal onlyLiquidityRemover nonReentrant returns (uint256)
    {
        Repo.Layout storage l_ = Repo._layout();
        bool asShare_ = UniswapV4SeBufferHookLegLib.classify(l_.legs, tokenOut_)
            == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange;
        address pair_ = asShare_ ? l_.legs.pairOfStandardExchange[tokenOut_] : tokenOut_;
        return _exitSingleAssetFrom(address(this), pair_, shares_, asShare_, receiver_, minimum_, block.timestamp);
    }

/* ---------------------------------------------------------------------- */
    /*                         Standard Exchange swap and liquidity routes                        */
    /* ---------------------------------------------------------------------- */

    function _entryExchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) {
            return _exchangeIn(tokenIn, amountIn, tokenOut, minAmountOut, recipient, pretransferred, deadline);
        }
        return _swapExchangeIn(tokenIn, amountIn, tokenOut, minAmountOut, recipient, pretransferred, deadline);
    }

    function _swapExchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) internal nonReentrant returns (uint256 amountOut) {
        _requireDeadline(deadline);
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        if (tin == tout) revert IStandardExchangeErrors.InvalidRoute(tin, tout);
        _tokenIndex(tin);
        _tokenIndex(tout);

        ExactInOutput memory output = _previewSwapExactInPlan(tin, tout, amountIn);
        amountOut = output.amountOut;
        if (amountOut < minAmountOut) revert Slippage();
        // L-GAPS-11 / ISecurePullErrors: pretransfer credits only in-window delta (I1/I3).
        _securePull(IERC20(tin), amountIn, pretransferred);

        uint8 i = _tokenIndex(tin);
        Repo.Layout storage l = Repo._layout();
        amountOut = _payExactInOutput(_tokenIndex(tout), output, recipient);
        if (amountOut < minAmountOut) revert Slippage();
        // buffer-last in
        if (l.standardExchanges[i] != address(0)) {
            _bufferToken(i, amountIn);
        } else {
            l.rawReserves[i] += amountIn;
        }
        _syncVaultReserves();
    }

    function _entryPreviewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) {
            if (_liquiditySePair(tokenIn, tokenOut) != address(0)) revert IStandardExchangeOut.ExchangeOutNotAvailable();
            return LiquidityRoute.previewOut(tokenIn, tokenOut, amountOut);
        }
        return _previewSwapExactOut(address(tokenIn), address(tokenOut), amountOut);
    }

    function _entryExchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) internal returns (uint256 amountIn) {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) {
            if (_liquiditySePair(tokenIn, tokenOut) != address(0)) revert IStandardExchangeOut.ExchangeOutNotAvailable();
            return LiquidityRoute.exchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline);
        }
        return _swapExchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline);
    }

    function _swapExchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) internal nonReentrant returns (uint256 amountIn) {
        _requireDeadline(deadline);
        if (amountOut == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        amountIn = _previewSwapExactOut(tin, tout, amountOut);
        if (amountIn > maxAmountIn) revert Slippage();

        // L-GAPS-11: delta-gate claimed amountIn (no absolute free inventory credit).
        _pullExactOutInput(IERC20(tin), amountIn, maxAmountIn, pretransferred);

        uint8 j = _tokenIndex(tout);
        uint8 ii = _tokenIndex(tin);
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[j] != address(0)) {
            _unwrapExactTokenOut(j, amountOut, recipient);
        } else {
            if (amountOut >= l.rawReserves[j]) revert WouldZeroReserve();
            l.rawReserves[j] -= amountOut;
            IERC20(tout).safeTransfer(recipient, amountOut);
        }
        if (l.standardExchanges[ii] != address(0)) {
            _bufferToken(ii, amountIn);
        } else {
            l.rawReserves[ii] += amountIn;
        }
        _syncVaultReserves();
    }

    /// @notice D89: owner exact-in; internal book settlement (no nested PoolManager.unlock).
    function _entryOwnerSwapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal nonReentrant returns (uint256 amountOut) {
        _onlyHookOwner();
        _requireDeadline(deadline);
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert IStandardExchangeErrors.InvalidRoute(tokenIn, tokenOut);
        _tokenIndex(tokenIn);
        _tokenIndex(tokenOut);
        ExactInOutput memory output = _previewSwapExactInPlan(tokenIn, tokenOut, amountIn);
        amountOut = output.amountOut;
        if (amountOut < minAmountOut) revert Slippage();
        _securePull(IERC20(tokenIn), amountIn, false);
        amountOut = _payExactInOutput(_tokenIndex(tokenOut), output, msg.sender);
        if (amountOut < minAmountOut) revert Slippage();
        _bufferOwnerSwapInput(tokenIn, amountIn);
    }

    /// @notice D89: owner exact-out; internal book settlement (no nested PoolManager.unlock).
    function _entryOwnerSwapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        uint256 deadline
    ) internal nonReentrant returns (uint256 amountIn) {
        _onlyHookOwner();
        _requireDeadline(deadline);
        if (amountOut == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert IStandardExchangeErrors.InvalidRoute(tokenIn, tokenOut);
        amountIn = _previewSwapExactOut(tokenIn, tokenOut, amountOut);
        if (amountIn > maxAmountIn) revert Slippage();
        _securePull(IERC20(tokenIn), amountIn, false);
        _payOwnerSwap(tokenIn, tokenOut, amountIn, amountOut);
    }

    function _onlyHookOwner() private view {
        if (msg.sender != MultiStepOwnableRepo._owner()) {
            revert IMultiStepOwnable.NotOwner(msg.sender);
        }
    }

    function _payOwnerSwap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) private {
        uint8 j = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[j] != address(0)) {
            _unwrapExactTokenOut(j, amountOut, msg.sender);
        } else {
            if (amountOut >= l.rawReserves[j]) revert WouldZeroReserve();
            l.rawReserves[j] -= amountOut;
            IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
        }
        _bufferOwnerSwapInput(tokenIn, amountIn);
    }

    function _bufferOwnerSwapInput(address tokenIn, uint256 amountIn) private {
        uint8 i = _tokenIndex(tokenIn);
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] != address(0)) {
            _bufferToken(i, amountIn);
        } else {
            l.rawReserves[i] += amountIn;
        }
        _syncVaultReserves();
    }

}

abstract contract UniswapV4StandardExchangeWeightedBufferHookSeTarget is UniswapV4StandardExchangeWeightedBufferHookExchangeCore, NativeStandardYieldExecutionTarget {
    function isValidTokenIn(address token_) public view override returns (bool) { return _validNativeToken(token_); }
    function isValidTokenOut(address token_) public view override returns (bool) { return _validNativeToken(token_); }
    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_) internal override returns (uint256) {
        return _redeemHeld(receiver_, shares_, tokenOut_, minimum_);
    }
    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minimum, address recipient, bool prepaid, uint256 deadline) external returns (uint256) {
        return _entryExchangeIn(tokenIn, amountIn, tokenOut, minimum, recipient, prepaid, deadline);
    }
}

abstract contract UniswapV4StandardExchangeWeightedBufferHookExchangeOutPreviewTarget is UniswapV4StandardExchangeWeightedBufferHookExchangeCore {
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut) external view returns (uint256) {
        return _entryPreviewExchangeOut(tokenIn, tokenOut, amountOut);
    }
}

abstract contract UniswapV4StandardExchangeWeightedBufferHookExchangeOutTarget is UniswapV4StandardExchangeWeightedBufferHookExchangeCore {
    function exchangeOut(IERC20 tokenIn, uint256 maximum, IERC20 tokenOut, uint256 amountOut, address recipient, bool prepaid, uint256 deadline) external returns (uint256) {
        return _entryExchangeOut(tokenIn, maximum, tokenOut, amountOut, recipient, prepaid, deadline);
    }
}

abstract contract UniswapV4StandardExchangeWeightedBufferHookOwnerSwapTarget is UniswapV4StandardExchangeWeightedBufferHookExchangeCore {
    function ownerSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn, uint256 minimum, uint256 deadline) external returns (uint256) {
        return _entryOwnerSwapExactIn(tokenIn, tokenOut, amountIn, minimum, deadline);
    }
    function ownerSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut, uint256 maximum, uint256 deadline) external returns (uint256) {
        return _entryOwnerSwapExactOut(tokenIn, tokenOut, amountOut, maximum, deadline);
    }
}
