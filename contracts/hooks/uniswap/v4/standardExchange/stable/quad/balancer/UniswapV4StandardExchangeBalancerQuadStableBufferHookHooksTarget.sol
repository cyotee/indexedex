// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookInQuoteBase} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookInQuoteBase.sol";

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib as ClaimLib} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookBeforeInitializeLib.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget
 * @notice IHooks callbacks + rated StableSwap V4 swaps (beforeSwap + beforeSwapReturnDelta).
 * @dev No BaseHook inheritance. Fee-net curve on input residual; gross buffer SE in last.
 */
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookSwapCore is
    UniswapV4StandardExchangeBalancerQuadStableBufferHookInQuoteBase
{
    using SafeERC20 for IERC20;

    /* ---------------------------------------------------------------------- */
    /*                                  IHooks                                */
    /* ---------------------------------------------------------------------- */

    function _hookBeforeInitialize(address, PoolKey calldata poolKey, uint160)
        internal
        view
        returns (bytes4)
    {
        return BeforeInitializeLib.beforeInitialize(poolKey);
    }

    function _hookAfterInitialize(address, PoolKey calldata, uint160, int24)
        internal
        pure
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function _hookBeforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        internal
        view
        returns (bytes4)
    {
        _onlyPoolManager();
        revert LiquidityNotAllowed();
    }

    function _hookAfterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal pure returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function _hookBeforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) internal view returns (bytes4) {
        _onlyPoolManager();
        revert LiquidityNotAllowed();
    }

    function _hookAfterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal pure returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function _hookBeforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        returns (bytes4, BeforeSwapDelta swapDelta, uint24)
    {
        BeforeInitializeLib.beforeInitialize(key);
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;

        address c0 = Currency.unwrap(key.currency0);
        address c1 = Currency.unwrap(key.currency1);
        address tokenIn = params.zeroForOne ? c0 : c1;
        address tokenOut = params.zeroForOne ? c1 : c0;

        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) {
            l.reentrancyStatus = Repo.NOT_ENTERED;
            revert InvalidFeeWad();
        }

        uint256 amountIn;
        uint256 amountOut;
        if (params.amountSpecified < 0) {
            amountIn = uint256(-params.amountSpecified);
            amountOut = _swapExactInExecute(tokenIn, tokenOut, amountIn, feeWad);
            swapDelta = toBeforeSwapDelta(int128(int256(amountIn)), int128(-int256(amountOut)));
        } else {
            amountOut = uint256(params.amountSpecified);
            amountIn = _swapExactOutExecute(tokenIn, tokenOut, amountOut, feeWad);
            swapDelta = toBeforeSwapDelta(int128(-int256(amountOut)), int128(int256(amountIn)));
        }

        if (amountIn > uint256(uint128(type(int128).max)) || amountOut > uint256(uint128(type(int128).max))) revert InvalidTransferAmount();
        _take(Currency.wrap(tokenIn), address(this), amountIn);
        _settle(Currency.wrap(tokenOut), amountOut);

        // Gross buffer SE in last (after take). Raw: credit intentional book for free-pretransfer gate.
        uint8 iIn = _tokenIndex(tokenIn);
        if (l.standardExchanges[iIn] != address(0)) {
            _bufferToken(iIn, amountIn);
        } else {
            _creditRawIntentional(iIn, amountIn);
        }

        _syncVaultReserves();
        l.reentrancyStatus = Repo.NOT_ENTERED;
        return (IHooks.beforeSwap.selector, swapDelta, Math.feeOverridePips(feeWad));
    }

    function _hookAfterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        pure
        returns (bytes4, int128)
    {
        revert HookNotImplemented();
    }

    function _hookBeforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        internal
        view
        returns (bytes4)
    {
        _onlyPoolManager();
        revert DonateNotAllowed();
    }

    function _hookAfterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        internal
        pure
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    /* ---------------------------------------------------------------------- */
    /*                         rated StableSwap swaps                         */
    /* ---------------------------------------------------------------------- */

    function _hookPreviewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactInContext(tokenIn, tokenOut, amountIn, false, Repo._layout().poolManager).amountOut;
    }

    function _hookPreviewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOutContext(tokenIn, tokenOut, amountOut, Repo._layout().poolManager);
    }

    function _previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactInFunded(tokenIn, tokenOut, amountIn, false);
    }

    function _previewSwapExactInFunded(address tokenIn, address tokenOut, uint256 amountIn, bool funded)
        internal view returns (uint256 amountOut)
    {
        return _previewSwapExactInPlan(tokenIn, tokenOut, amountIn, funded).amountOut;
    }

    function _previewSwapExactInPlan(address tokenIn, address tokenOut, uint256 amountIn, bool funded)
        internal view returns (ExactInOutput memory output)
    {
        return _previewSwapExactInContext(tokenIn, tokenOut, amountIn, funded, address(0));
    }

    function _previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOutContext(tokenIn, tokenOut, amountOut, address(0));
    }

    function _previewSwapExactOutContext(address tokenIn, address tokenOut, uint256 amountOut, address manager)
        private view returns (uint256)
    {
        if (amountOut == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert InvalidPair();
        uint8 i = _tokenIndex(tokenIn);
        uint8 j = _tokenIndex(tokenOut);
        uint256[] memory rated = manager == address(0) ? _ratedWadAll() : ClaimLib.ratedWadAllWithContext(manager);
        if (rated[i] == 0 || rated[j] == 0) revert SwapNotLive();

        Repo.Layout storage l = Repo._layout();
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();

        return ClaimLib.quoteSwapExactOutContext(i, j, rated, amountOut, feeWad, _amp(), manager);
    }

    /// @dev Invert rated WAD inflow through public SE quotes, rounding input up.
    function _mapRatedWadToPairIn(uint8 i, uint256 ratedWadIn) internal view returns (uint256 pairIn) {
        return ClaimLib.pairInputForRated(i, ratedWadIn);
    }

    function _swapExactInExecute(address tokenIn, address tokenOut, uint256 amountIn, uint256)
        internal
        returns (uint256 amountOut)
    {
        amountOut = _payExactInOutput(_tokenIndex(tokenOut), _previewSwapExactInPlan(tokenIn, tokenOut, amountIn, false), address(this));
    }

    function _payExactInOutput(uint8 j, ExactInOutput memory output, address recipient) internal returns (uint256 amountOut) {
        Repo.Layout storage l = Repo._layout();
        if (output.sharesOut != 0) {
            if (output.sharesOut >= _nativeAt(j)) revert WouldZeroReserve();
            uint256 beforeOut = IERC20(l.tokens[j]).balanceOf(recipient);
            _unwrapSeShares(j, output.sharesOut, recipient);
            amountOut = IERC20(l.tokens[j]).balanceOf(recipient) - beforeOut;
            if (amountOut < output.amountOut) revert UnwrapFailed();
        } else {
            amountOut = output.amountOut;
            if (amountOut >= _nativeAt(j)) revert WouldZeroReserve();
            if (l.standardExchanges[j] == address(0)) _debitRawIntentional(j, amountOut);
            if (recipient != address(this)) IERC20(l.tokens[j]).safeTransfer(recipient, amountOut);
        }
    }

    function _swapExactOutExecute(address tokenIn, address tokenOut, uint256 amountOut, uint256)
        internal
        returns (uint256 amountIn)
    {
        amountIn = _previewSwapExactOut(tokenIn, tokenOut, amountOut);
        uint8 j = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[j] != address(0)) {
            _unwrapExactTokenOut(j, amountOut, address(this));
        } else {
            if (amountOut >= _nativeAt(j)) revert WouldZeroReserve();
            _debitRawIntentional(j, amountOut);
        }
    }

    /// @notice D60: the configured rate providers, one per leg (address(0) on a raw leg without one).
    function _bindingRateProviders() internal view returns (address[] memory) {
        return Repo._layout().rateProviders;
    }

    /// @notice D60: the rate provider configured for `token_`, address(0) when none or unknown token.
    function _bindingRateProviderOfAddress(address token_) internal view returns (address) {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.tokens.length; ++i) {
            if (l.tokens[i] == token_) return l.rateProviders[i];
        }
        return address(0);
    }
}

abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget is UniswapV4StandardExchangeBalancerQuadStableBufferHookSwapCore, IHooks {
    function feeOracle() public view returns (IVaultFeeOracleQuery) { return _bindingFeeOracle(); }
    function tokens() public view returns (address[] memory) { return _bindingTokens(); }
    function dexSwapFee() public view returns (uint256) { return _bindingDexSwapFee(); }
    function usageFee() public view returns (uint256) { return _bindingUsageFee(); }
    function feeTo() public view returns (address) { return _bindingFeeTo(); }
    function isFullBook() public view returns (bool) { return _bindingIsFullBook(); }
    function pairDoorCount() public view returns (uint256) { return _bindingPairDoorCount(); }
    function poolManager() public view returns (IPoolManager) { return _bindingPoolManager(); }
    function permit2() public pure returns (address) { return _bindingPermit2(); }
    function numTokens() public view returns (uint8) { return _bindingNumTokens(); }
    function token(uint256 i) public view returns (address) { return _bindingToken(i); }
    function baseAmp() public view returns (uint256) { return _bindingBaseAmp(); }
    function getCurrentAmp() public view returns (uint256) { return _bindingCurrentAmp(); }
    function standardExchange(uint256 i) public view returns (address) { return _bindingStandardExchange(i); }
    function rateProvider(uint256 i) public view returns (address) { return _bindingRateProvider(i); }
    function isBuffered(uint256 i) public view returns (bool) { return _bindingIsBuffered(i); }
    function invScale(uint256 i) public view returns (uint256) { return _bindingInvScale(i); }
    function ratedScale(uint256 i) public view returns (uint256) { return _bindingRatedScale(i); }
    function nativeReserve(uint256 i) public view returns (uint256) { return _bindingNativeReserve(i); }
    function nativeReserves() public view returns (uint256[] memory) { return _bindingNativeReserves(); }
    function seBalance(uint256 i) public view returns (uint256) { return _bindingSeBalance(i); }
    function seClaim(uint256 i) public view returns (uint256) { return _bindingSeClaim(i); }
    function ratedBalance(uint256 i) public view returns (uint256) { return _bindingRatedBalance(i); }
    function ratedBalances() public view returns (uint256[] memory) { return _bindingRatedBalances(); }
    function kLast() public view returns (uint256) { return _bindingKLast(); }
    function rateProviders() public view returns (address[] memory) { return _bindingRateProviders(); }
    function rateProvider(address token_) public view returns (address) { return _bindingRateProviderOfAddress(token_); }
    function beforeInitialize(address s, PoolKey calldata k, uint160 p) external view override returns (bytes4) { return _hookBeforeInitialize(s, k, p); }
    function afterInitialize(address s, PoolKey calldata k, uint160 p, int24 t) external pure override returns (bytes4) { return _hookAfterInitialize(s, k, p, t); }
    function beforeAddLiquidity(address s, PoolKey calldata k, ModifyLiquidityParams calldata p, bytes calldata d) external view override returns (bytes4) { return _hookBeforeAddLiquidity(s, k, p, d); }
    function afterAddLiquidity(address s, PoolKey calldata k, ModifyLiquidityParams calldata p, BalanceDelta a, BalanceDelta f, bytes calldata d) external pure override returns (bytes4, BalanceDelta) { return _hookAfterAddLiquidity(s, k, p, a, f, d); }
    function beforeRemoveLiquidity(address s, PoolKey calldata k, ModifyLiquidityParams calldata p, bytes calldata d) external view override returns (bytes4) { return _hookBeforeRemoveLiquidity(s, k, p, d); }
    function afterRemoveLiquidity(address s, PoolKey calldata k, ModifyLiquidityParams calldata p, BalanceDelta a, BalanceDelta f, bytes calldata d) external pure override returns (bytes4, BalanceDelta) { return _hookAfterRemoveLiquidity(s, k, p, a, f, d); }
    function beforeSwap(address s, PoolKey calldata k, SwapParams calldata p, bytes calldata d) external override returns (bytes4, BeforeSwapDelta, uint24) { return _hookBeforeSwap(s, k, p, d); }
    function afterSwap(address s, PoolKey calldata k, SwapParams calldata p, BalanceDelta a, bytes calldata d) external pure override returns (bytes4, int128) { return _hookAfterSwap(s, k, p, a, d); }
    function beforeDonate(address s, PoolKey calldata k, uint256 a, uint256 b, bytes calldata d) external view override returns (bytes4) { return _hookBeforeDonate(s, k, a, b, d); }
    function afterDonate(address s, PoolKey calldata k, uint256 a, uint256 b, bytes calldata d) external pure override returns (bytes4) { return _hookAfterDonate(s, k, a, b, d); }
    function previewSwapExactIn(address in_, address out_, uint256 amount_) public view returns (uint256) { return _hookPreviewSwapExactIn(in_, out_, amount_); }
    function previewSwapExactOut(address in_, address out_, uint256 amount_) public view returns (uint256) { return _hookPreviewSwapExactOut(in_, out_, amount_); }
}
