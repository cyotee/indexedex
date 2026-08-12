// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
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

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget
 * @notice IHooks callbacks + rated StableSwap V4 swaps (beforeSwap + beforeSwapReturnDelta).
 * @dev No BaseHook inheritance. Fee-net curve on input residual; gross buffer SE in last.
 */
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget is
    UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget,
    IHooks
{
    using SafeERC20 for IERC20;

    /* ---------------------------------------------------------------------- */
    /*                                  IHooks                                */
    /* ---------------------------------------------------------------------- */

    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
        view
        override
        returns (bytes4)
    {
        _onlyPoolManager();
        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (a >= b) revert InvalidPoolKey();
        _tokenIndex(a);
        _tokenIndex(b);
        if (poolKey.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) revert InvalidPoolKey();
        if (poolKey.tickSpacing != Repo.TICK_SPACING) revert InvalidPoolKey();
        if (address(poolKey.hooks) != address(this)) revert InvalidPoolKey();
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        _onlyPoolManager();
        revert LiquidityNotAllowed();
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external view override returns (bytes4) {
        _onlyPoolManager();
        revert LiquidityNotAllowed();
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta swapDelta, uint24)
    {
        _onlyPoolManager();
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

    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        override
        returns (bytes4, int128)
    {
        revert HookNotImplemented();
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        _onlyPoolManager();
        revert DonateNotAllowed();
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    /* ---------------------------------------------------------------------- */
    /*                         rated StableSwap swaps                         */
    /* ---------------------------------------------------------------------- */

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        public
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactIn(tokenIn, tokenOut, amountIn);
    }

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOut(tokenIn, tokenOut, amountOut);
    }

    function _previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert InvalidPair();
        uint8 i = _tokenIndex(tokenIn);
        uint8 j = _tokenIndex(tokenOut);
        uint256[4] memory rated = _ratedWadAllForSwapIn(i, amountIn);
        if (rated[i] == 0 || rated[j] == 0) revert SwapNotLive();

        Repo.Layout storage l = Repo._layout();
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();

        uint256 netIn = Math.applyTradingFeeNet(amountIn, feeWad);
        uint256 ratedInflow = _mapPairInToRatedWad(i, netIn);
        if (ratedInflow == 0) revert ZeroAmount();
        uint256 outScaled = Math.quoteExactInRated(rated, i, j, ratedInflow, _amp());
        amountOut = Math.descale(outScaled, l.ratedScales[j]);
        if (amountOut == 0) revert ZeroAmount();
        if (amountOut >= _ratedPairUnits(j)) revert WouldZeroReserve();
    }

    /// @dev Rated book snapshot for exact-in. Raw `tokenIn` start reserve:
    ///      - no free funding yet → live face (D21)
    ///      - free >= amountIn (post-pull / funded pretransfer) → exclude funding so it is not double-counted
    function _ratedWadAllForSwapIn(uint8 iIn, uint256 amountInPair)
        internal
        view
        returns (uint256[4] memory scaled)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 k; k < Repo.N_TOKENS; ++k) {
            uint256 pairUnits = _ratedPairUnits(k);
            if (k == iIn && l.standardExchanges[k] == address(0) && amountInPair > 0) {
                uint256 face = IERC20(l.tokens[k]).balanceOf(address(this));
                uint256 book = l.rawReserves[k];
                uint256 free = face > book ? face - book : 0;
                if (free >= amountInPair) {
                    // Funding already on hook; start book excludes this trade's input.
                    pairUnits = face - amountInPair;
                }
            }
            scaled[k] = Math.scaleTo(pairUnits, l.ratedScales[k]);
        }
    }

    function _mapPairInToRatedWad(uint8 i, uint256 pairAmount) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (se == address(0)) {
            return Math.scaleTo(pairAmount, l.ratedScales[i]);
        }
        // Buffer preview → shares → pair units (rate or claim) → rated WAD
        uint256 shares =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(l.tokens[i]), pairAmount, IERC20(se));
        if (shares == 0) return 0;
        address rp = l.rateProviders[i];
        uint256 pairUnits;
        if (rp != address(0)) {
            pairUnits = (shares * _getRateFailClosed(rp)) / Math.RATE_PRECISION;
        } else {
            pairUnits = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), shares, IERC20(l.tokens[i]));
        }
        return Math.scaleTo(pairUnits, l.ratedScales[i]);
    }

    function _previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        if (amountOut == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert InvalidPair();
        uint8 i = _tokenIndex(tokenIn);
        uint8 j = _tokenIndex(tokenOut);
        if (amountOut >= _ratedPairUnits(j)) revert WouldZeroReserve();
        uint256[4] memory rated = _ratedWadAll();
        if (rated[i] == 0 || rated[j] == 0) revert SwapNotLive();

        Repo.Layout storage l = Repo._layout();
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();

        uint256 outScaled = Math.scaleToUp(amountOut, l.ratedScales[j]);
        uint256 netInRated = Math.quoteExactOutRated(rated, i, j, outScaled, _amp());
        // Map rated net inflow back to pair units then gross-up for fee
        uint256 netPair = _mapRatedWadToPairIn(i, netInRated);
        amountIn = Math.grossUpExactOut(netPair, feeWad);
        if (amountIn == 0) revert ZeroAmount();
    }

    /// @dev Invert rated WAD inflow to pair-token units (raw face or buffer invert approx).
    function _mapRatedWadToPairIn(uint8 i, uint256 ratedWadIn) internal view returns (uint256 pairIn) {
        Repo.Layout storage l = Repo._layout();
        uint256 pairUnits = Math.descaleUp(ratedWadIn, l.ratedScales[i]);
        address se = l.standardExchanges[i];
        if (se == address(0)) {
            return pairUnits;
        }
        // pairUnits is claim/rate units of SE shares. Invert: shares ≈ pairUnits when rate 1e18.
        address rp = l.rateProviders[i];
        uint256 sharesNeeded;
        if (rp != address(0)) {
            uint256 rate = _getRateFailClosed(rp);
            sharesNeeded = Math.descaleUp(pairUnits * Math.RATE_PRECISION, rate);
        } else {
            // invert claim ≈ use exchangeOut preview when available
            sharesNeeded = IStandardExchangeOut(se).previewExchangeOut(
                IERC20(se), IERC20(l.tokens[i]), pairUnits
            );
        }
        // Invert buffer: pair such that previewExchangeIn ≈ sharesNeeded
        try IStandardExchangeOut(se).previewExchangeOut(IERC20(l.tokens[i]), IERC20(se), sharesNeeded)
        returns (uint256 pairNeed) {
            return pairNeed;
        } catch {
            // linear gross-up via 1-unit preview
            uint256 got = IStandardExchangeIn(se).previewExchangeIn(
                IERC20(l.tokens[i]), sharesNeeded, IERC20(se)
            );
            if (got == 0) revert ZeroAmount();
            return (sharesNeeded * sharesNeeded + got - 1) / got;
        }
    }

    function _swapExactInExecute(address tokenIn, address tokenOut, uint256 amountIn, uint256)
        internal
        returns (uint256 amountOut)
    {
        amountOut = _previewSwapExactIn(tokenIn, tokenOut, amountIn);
        uint8 j = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[j] != address(0)) {
            _unwrapExactTokenOut(j, amountOut, address(this));
        } else {
            if (amountOut >= _nativeAt(j)) revert WouldZeroReserve();
            _debitRawIntentional(j, amountOut);
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
}
