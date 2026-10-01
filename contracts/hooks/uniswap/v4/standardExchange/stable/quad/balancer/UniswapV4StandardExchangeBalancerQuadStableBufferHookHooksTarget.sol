// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget is
    UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget,
    IHooks
{
    using SafeERC20 for IERC20;

    struct ExactInOutput {
        uint256 amountOut;
        uint256 sharesOut;
    }

    /* ---------------------------------------------------------------------- */
    /*                                  IHooks                                */
    /* ---------------------------------------------------------------------- */

    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
        view
        override
        returns (bytes4)
    {
        return BeforeInitializeLib.beforeInitialize(poolKey);
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
        return _previewSwapExactInContext(tokenIn, tokenOut, amountIn, false, Repo._layout().poolManager).amountOut;
    }

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        public
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

    function _previewSwapExactInContext(address tokenIn, address tokenOut, uint256 amountIn, bool funded, address manager)
        private view returns (ExactInOutput memory output)
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

    /// @dev Rated book snapshot for exact-in. Raw `tokenIn` start reserve:
    ///      - no free funding yet → live face (D21)
    ///      - free >= amountIn (post-pull / funded pretransfer) → exclude funding so it is not double-counted
    function _ratedWadAllForSwapIn(uint8 iIn, uint256 amountInPair)
        internal
        view
        returns (uint256[] memory scaled)
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
        if (se == address(0) || se == l.tokens[i]) {
            // D60: a raw or self-share leg is its balance, times the rate when a provider is configured.
            address rpRaw = l.rateProviders[i];
            uint256 units = rpRaw == address(0)
                ? pairAmount
                : Math.ratedPairUnits(pairAmount, _getRateFailClosed(rpRaw), l.invScales[i], l.ratedScales[i]);
            return Math.scaleTo(units, l.ratedScales[i]);
        }
        // Buffer preview → shares → pair units (rate or claim) → rated WAD
        uint256 shares =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(l.tokens[i]), pairAmount, IERC20(se));
        if (shares == 0) return 0;
        address rp = l.rateProviders[i];
        if (rp == address(0)) revert ClaimLib.RateProviderRequired();
        // D60: the SE answers the buffering quote (shares for this deposit); the rate values them.
        uint256 pairUnits = Math.ratedPairUnits(shares, _getRateFailClosed(rp), ClaimLib.shareScale(se), l.ratedScales[i]);
        return Math.scaleTo(pairUnits, l.ratedScales[i]);
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
    function rateProviders() public view returns (address[] memory) {
        return Repo._layout().rateProviders;
    }

    /// @notice D60: the rate provider configured for `token_`, address(0) when none or unknown token.
    function rateProvider(address token_) public view returns (address) {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.tokens.length; ++i) {
            if (l.tokens[i] == token_) return l.rateProviders[i];
        }
        return address(0);
    }
}
