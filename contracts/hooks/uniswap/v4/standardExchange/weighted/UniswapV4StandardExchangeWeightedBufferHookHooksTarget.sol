// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";


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
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
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
    UniswapV4StandardExchangeWeightedBufferHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookBeforeInitializeLib.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookTarget
 * @notice Product logic: dual-scale weighted book, SE buffer-last LP, rated V4/SE swaps, MultiAssetLiquidity.
 * @dev No BaseHook / DeltaResolver inheritance. LP via ERC20Repo; inventory = face | live SE shares.
 */
import {
    UniswapV4StandardExchangeWeightedBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookHooksTarget
 * @notice IHooks callbacks + rated V4 swaps.
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHookSwapCore is
    UniswapV4StandardExchangeWeightedBufferHookTarget
{
    using SafeERC20 for IERC20;

    struct ExactInOutput {
        uint256 amountOut;
        uint256 sharesOut;
    }

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
        // settle out first as pair, then buffer in last
        _settle(Currency.wrap(tokenOut), amountOut);

        // Gross buffer SE in last (after take)
        uint8 iIn = _tokenIndex(tokenIn);
        if (l.standardExchanges[iIn] != address(0)) {
            _bufferToken(iIn, amountIn);
        } else {
            l.rawReserves[iIn] += amountIn;
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
    /*                              rated swaps                               */
    /* ---------------------------------------------------------------------- */

    function _hookPreviewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactInContext(tokenIn, tokenOut, amountIn, Repo._layout().poolManager).amountOut;
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
        return _previewSwapExactInPlan(tokenIn, tokenOut, amountIn).amountOut;
    }

    function _previewSwapExactInPlan(address tokenIn, address tokenOut, uint256 amountIn)
        internal view returns (ExactInOutput memory)
    {
        return _previewSwapExactInContext(tokenIn, tokenOut, amountIn, address(0));
    }

    function _previewSwapExactInContext(address tokenIn, address tokenOut, uint256 amountIn, address manager)
        private view returns (ExactInOutput memory output)
    {
        (output.amountOut, output.sharesOut) = ClaimLib.previewSwapExactInContext(tokenIn, tokenOut, amountIn, manager);
    }

    function _quoteRatedSwapExactIn(uint8 i, uint8 j, uint256[] memory rated, uint256 ratedInflow)
        internal view returns (uint256 amountOut)
    {
        return _quoteRatedSwapExactInPlan(i, j, rated, ratedInflow).amountOut;
    }

    function _quoteRatedSwapExactInPlan(uint8 i, uint8 j, uint256[] memory rated, uint256 ratedInflow)
        internal view returns (ExactInOutput memory output)
    {
        (output.amountOut, output.sharesOut) = ClaimLib.quoteSwapExactIn(i, j, rated, ratedInflow);
    }


    function _mapPairInToRatedWad(uint8 i, uint256 pairAmount) internal view returns (uint256) {
        return ClaimLib.mapPairInToRatedWad(i, pairAmount);
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

        return ClaimLib.quoteSwapExactOutContext(i, j, rated, amountOut, feeWad, manager);
    }

    function _swapExactInExecute(address tokenIn, address tokenOut, uint256 amountIn, uint256)
        internal
        returns (uint256 amountOut)
    {
        ExactInOutput memory output = _previewSwapExactInPlan(tokenIn, tokenOut, amountIn);
        amountOut = _payExactInOutput(_tokenIndex(tokenOut), output, address(this));
        // tokenIn credit deferred to after take + buffer-last in beforeSwap
    }

    function _payExactInOutput(uint8 j, ExactInOutput memory output, address recipient)
        internal returns (uint256 amountOut)
    {
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
            if (l.standardExchanges[j] == address(0)) l.rawReserves[j] -= amountOut;
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
            if (amountOut >= l.rawReserves[j]) revert WouldZeroReserve();
            l.rawReserves[j] -= amountOut;
        }
    }

    
}

abstract contract UniswapV4StandardExchangeWeightedBufferHookHooksTarget is UniswapV4StandardExchangeWeightedBufferHookSwapCore, IHooks {
    function poolManager() public view returns (IPoolManager) { return _bindingPoolManager(); }
    function permit2() public pure returns (address) { return _bindingPermit2(); }
    function numTokens() public view returns (uint8) { return _bindingNumTokens(); }
    function token(uint256 i) public view returns (address) { return _bindingToken(i); }
    function getNormalizedWeights() public view returns (uint256[] memory) { return _bindingWeights(); }
    function weight(uint256 i) public view returns (uint256) { return _bindingWeight(i); }
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
    function ensurePairPools() external returns (uint256) { return _ensurePairPools(); }
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

/// @notice Hook-only composed quotes, separated from inherited SE execution code.
abstract contract UniswapV4StandardExchangeWeightedBufferHookQuoteTarget is UniswapV4StandardExchangeWeightedBufferHookHooksTarget {
    function previewSwapAfterExchange(address tokenIn, address pairToken, address rawTokenOut, uint256 amountIn)
        external view returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        uint8 i = _tokenIndex(pairToken);
        uint8 j = _tokenIndex(rawTokenOut);
        if (i == j || l.standardExchanges[i] == address(0) || l.standardExchanges[j] != address(0)) revert InvalidPair();
        LegLib.ExternalQuote memory q = LegLib.afterExternalExchange(l.standardExchanges[i], pairToken, tokenIn, amountIn, address(this));
        return _swapAtExternalState(q, i, j);
    }

    function previewBondAfterDeposit(address tokenIn, address pairToken, address detfToken, uint256 amountIn, uint256 multiplier)
        external view returns (uint256, uint256, uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint8 i = _tokenIndex(pairToken);
        uint8 j = _tokenIndex(detfToken);
        if (i == j || l.standardExchanges[i] == address(0) || l.standardExchanges[j] != address(0)) revert InvalidPair();
        LegLib.ExternalQuote memory q = LegLib.afterExternalDeposit(l.standardExchanges[i], pairToken, tokenIn, amountIn, address(this));
        return _bondAtExternalState(q, i, j, multiplier);
    }

    function _bondAtExternalState(LegLib.ExternalQuote memory q, uint8 i, uint8 j, uint256 multiplier)
        private view returns (uint256 pairValue, uint256 purchasedDetf, uint256 liquidityDetf)
    {
        Repo.Layout storage l = Repo._layout();
        pairValue = q.exchange.quoteAssets(q.state, q.assets);
        if (!_isLive()) return (pairValue, 0, 0);
        uint256[] memory inv = _invWadAll();
        inv[i] = Math.scaleTo(q.heldShares, l.invScales[i]);
        liquidityDetf = LegLib.matchingLiquidityDetf(q, _nativeAt(j), pairValue, _previewSupplyAfterProtocolMint(inv), 0);
        q.assets = FullMath.mulDiv(pairValue, multiplier, 1e18);
        purchasedDetf = _swapAtExternalState(q, i, j);
    }

    function _swapAtExternalState(LegLib.ExternalQuote memory q, uint8 i, uint8 j)
        private view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        (uint256 minted,) = LegLib.depositAfterExchange(q, Math.applyTradingFeeNet(q.assets, feeWad));
        uint256[] memory rated = _ratedWadAll();
        if (l.rateProviders[i] == address(0)) revert ClaimLib.RateProviderRequired();
        {
            // D60: held reserve and inflow are shares x rate; `minted` carries the rated inflow from here on.
            uint256 rate = LegLib.rateAfterExchange(q, l.tokens[i], l.rateProviders[i]);
            rated[i] = Math.scaleTo(
                Math.ratedPairUnits(q.heldShares, rate, l.invScales[i], l.ratedScales[i]), l.ratedScales[i]
            );
            minted = Math.ratedPairUnits(minted, rate, l.invScales[i], l.ratedScales[i]);
        }
        if (rated[i] == 0 || rated[j] == 0) revert SwapNotLive();
        return _quoteRatedSwapExactIn(i, j, rated, Math.scaleTo(minted, l.ratedScales[i]));
    }

}
