// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
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
import {
    UniswapV4QuadStableSwapHookCommon
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookCommon.sol";
import {
    UniswapV4QuadStableSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookRepo.sol";
import {
    UniswapV4QuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookMath.sol";

/**
 * @title UniswapV4QuadStableSwapHookTarget
 * @notice IHooks + add/remove/zap + StableSwap beforeSwap (fee-on-output).
 * @dev Pattern-copy settle order from dual/single buffer peers. No BaseHook inheritance.
 *      Zap Algorithm A: closed-form inverse, leave ≥1 scaled out-leg clamp, reclassify after
 *      each internal swap, working-snapshot until single Repo commit (plan §6.5).
 */
abstract contract UniswapV4QuadStableSwapHookTarget is UniswapV4QuadStableSwapHookCommon, IHooks {
    constructor(
        IPoolManager poolManager_,
        address token0_,
        address token1_,
        address token2_,
        address token3_,
        uint24 lpFeePips_,
        uint256 baseAmp_,
        address[4] memory rateProviders_
    )
        UniswapV4QuadStableSwapHookCommon(
            poolManager_, token0_, token1_, token2_, token3_, lpFeePips_, baseAmp_, rateProviders_
        )
    {}

    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: true,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
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
        _onlyPoolManager();
        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (a >= b) revert InvalidPoolKey();
        // both must be bound tokens
        _tokenIndex(a);
        _tokenIndex(b);
        if (poolKey.fee != _lpFeePips) revert InvalidPoolKey();
        if (poolKey.tickSpacing != int24(int256(Math.TICK_SPACING))) revert InvalidPoolKey();
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

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
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
        address c0 = Currency.unwrap(key.currency0);
        address c1 = Currency.unwrap(key.currency1);
        address tokenIn = params.zeroForOne ? c0 : c1;
        address tokenOut = params.zeroForOne ? c1 : c0;
        uint256 i = _tokenIndex(tokenIn);
        uint256 j = _tokenIndex(tokenOut);

        Repo.Layout storage l = Repo._layout();
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();

        uint256[4] memory rates = _loadRates();
        uint256 amp = getCurrentAmp();

        if (params.amountSpecified < 0) {
            // exact-in
            uint256 amountIn = uint256(-params.amountSpecified);
            if (amountIn == 0) revert ZeroAmount();
            (uint256 amountOut, uint256[4] memory newR) =
                Math.quoteExactIn(l.reserves, rates, i, j, amountIn, amp, _lpFeePips);
            l.reserves = newR;
            _take(Currency.wrap(tokenIn), address(this), amountIn);
            _settle(Currency.wrap(tokenOut), amountOut);
            swapDelta = toBeforeSwapDelta(int128(int256(amountIn)), int128(-int256(amountOut)));
        } else {
            // exact-out
            uint256 amountOut = uint256(params.amountSpecified);
            if (amountOut == 0) revert ZeroAmount();
            (uint256 amountIn, uint256[4] memory newR) =
                Math.quoteExactOut(l.reserves, rates, i, j, amountOut, amp, _lpFeePips);
            l.reserves = newR;
            _take(Currency.wrap(tokenIn), address(this), amountIn);
            _settle(Currency.wrap(tokenOut), amountOut);
            swapDelta = toBeforeSwapDelta(int128(-int256(amountOut)), int128(int256(amountIn)));
        }
        return (IHooks.beforeSwap.selector, swapDelta, 0);
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
    /*                            liquidity + zap                             */
    /* ---------------------------------------------------------------------- */

    function _previewAddLiquidity(uint256[4] memory amounts)
        internal
        view
        returns (uint256 shares, uint256[4] memory actual)
    {
        Repo.Layout storage l = Repo._layout();
        uint256[4] memory rates = _loadRates();
        if (l.totalSupply == 0) {
            for (uint256 i; i < 4; ++i) {
                if (amounts[i] == 0) revert ZeroAmount();
            }
            uint256[4] memory scaled;
            for (uint256 i; i < 4; ++i) {
                scaled[i] = Math.scaleTo(amounts[i], rates[i]);
            }
            shares = Math.firstMintShares(scaled);
            actual = amounts;
            return (shares, actual);
        }
        (shares, actual) = Math.laterMintShares(amounts, l.reserves, l.totalSupply);
    }

    function _addLiquidity(
        uint256[4] memory amounts,
        uint256[4] memory minAmounts,
        address to,
        uint256 sharesMin
    ) internal returns (uint256 shares, uint256[4] memory actual) {
        if (to == address(0)) revert ZeroAddress();
        (shares, actual) = _previewAddLiquidity(amounts);
        if (shares < sharesMin) revert Slippage();
        for (uint256 i; i < 4; ++i) {
            if (actual[i] < minAmounts[i]) revert Slippage();
        }

        Repo.Layout storage l = Repo._layout();
        bool first = l.totalSupply == 0;

        for (uint256 i; i < 4; ++i) {
            _pull(_tokenAt(i), actual[i]);
            l.reserves[i] += actual[i];
        }

        if (first) {
            _mint(address(0), Math.MINIMUM_LIQUIDITY);
        }
        _mint(to, shares);

        // post-state priceable
        _requirePriceable();
    }

    function _previewRemoveLiquidity(uint256 shares)
        internal
        view
        returns (uint256[4] memory amounts)
    {
        Repo.Layout storage l = Repo._layout();
        return Math.removeAmounts(shares, l.reserves, l.totalSupply);
    }

    function _removeLiquidity(uint256 shares, address to, uint256[4] memory minAmounts)
        internal
        returns (uint256[4] memory amounts)
    {
        if (to == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        amounts = Math.removeAmounts(shares, l.reserves, l.totalSupply);
        for (uint256 i; i < 4; ++i) {
            if (amounts[i] < minAmounts[i]) revert Slippage();
        }
        _burn(msg.sender, shares);
        for (uint256 i; i < 4; ++i) {
            l.reserves[i] -= amounts[i];
            _push(_tokenAt(i), to, amounts[i]);
        }
        // no post-invariant require on remove (D25)
    }

    function _previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        uint256 i = _tokenIndex(tokenIn);
        uint256 j = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();
        (amountOut,) =
            Math.quoteExactIn(l.reserves, _loadRates(), i, j, amountIn, getCurrentAmp(), _lpFeePips);
    }

    function _previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        uint256 i = _tokenIndex(tokenIn);
        uint256 j = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();
        (amountIn,) =
            Math.quoteExactOut(l.reserves, _loadRates(), i, j, amountOut, getCurrentAmp(), _lpFeePips);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Zap Algorithm A (plan §6.5)                    */
    /* ---------------------------------------------------------------------- */

    function _previewZapIn(uint256[4] memory amounts)
        internal
        view
        returns (uint256 shares, uint256[4] memory amountsUsed)
    {
        _requireZapEligible();
        bool any;
        for (uint256 i; i < 4; ++i) {
            if (amounts[i] > 0) any = true;
        }
        if (!any) revert ZeroAmount();

        uint256[4] memory rates = _loadRates();
        Repo.Layout storage l = Repo._layout();
        uint256[4] memory W = amounts;
        uint256[4] memory workingR = l.reserves;
        uint256 amp = getCurrentAmp();

        (W, workingR) = _zapRebalance(W, workingR, rates, amp);

        uint256 supply = l.totalSupply;
        (shares, amountsUsed) = Math.laterMintShares(W, workingR, supply);
    }

    function _zapIn(uint256[4] memory amounts, address to, uint256 sharesMin)
        internal
        returns (uint256 shares, uint256[4] memory amountsUsed)
    {
        if (to == address(0)) revert ZeroAddress();
        _requireZapEligible();
        bool any;
        for (uint256 i; i < 4; ++i) {
            if (amounts[i] > 0) any = true;
        }
        if (!any) revert ZeroAmount();

        // pull full amounts up front
        for (uint256 i; i < 4; ++i) {
            if (amounts[i] > 0) _pull(_tokenAt(i), amounts[i]);
        }

        uint256[4] memory rates = _loadRates();
        Repo.Layout storage l = Repo._layout();
        uint256[4] memory W = amounts;
        uint256[4] memory workingR = l.reserves;
        uint256 amp = getCurrentAmp();

        (W, workingR) = _zapRebalance(W, workingR, rates, amp);

        (shares, amountsUsed) = Math.laterMintShares(W, workingR, l.totalSupply);
        if (shares < sharesMin) revert Slippage();

        for (uint256 i; i < 4; ++i) {
            // single Repo commit: post-swap book + mint legs
            l.reserves[i] = workingR[i] + amountsUsed[i];
            // refund unused (includes pre-swap residual on surplus legs)
            uint256 refund = W[i] - amountsUsed[i];
            if (refund > 0) _push(_tokenAt(i), msg.sender, refund);
        }
        _mint(to, shares);
        _requirePriceable();
    }

    struct ZapWork {
        uint256[4] W;
        uint256[4] workingR;
        uint256[4] rates;
        uint256 amp;
        uint24 fee;
    }

    function _zapRebalance(
        uint256[4] memory W,
        uint256[4] memory workingR,
        uint256[4] memory rates,
        uint256 amp
    ) internal view returns (uint256[4] memory, uint256[4] memory) {
        ZapWork memory z;
        z.W = W;
        z.workingR = workingR;
        z.rates = rates;
        z.amp = amp;
        z.fee = _lpFeePips;
        _zapRebalanceWork(z);
        return (z.W, z.workingR);
    }

    function _zapRebalanceWork(ZapWork memory z) private view {
        for (uint256 pass; pass < 2; ++pass) {
            (uint256[4] memory T_s, bool allMatch) = _zapTargets(z);
            if (allMatch) return;
            _zapPassSurplusDeficit(z, T_s);
        }
        // Final proportional seed so every positive reserve leg has W[j]>0 for D24 mint.
        _zapSeedZeroLegs(z);
    }

    /// @dev Nudge exact-in from largest W into any W[j]==0 leg (closed-form size, maxViable clamp).
    function _zapSeedZeroLegs(ZapWork memory z) private view {
        for (uint256 round; round < 4; ++round) {
            bool anyZero;
            for (uint256 j; j < 4; ++j) {
                if (z.W[j] == 0 && z.workingR[j] > 0) {
                    anyZero = true;
                    break;
                }
            }
            if (!anyZero) return;

            uint256 i = 0;
            for (uint256 k = 1; k < 4; ++k) {
                if (z.W[k] > z.W[i]) i = k;
            }
            if (z.W[i] == 0) return;

            for (uint256 j; j < 4; ++j) {
                if (j == i || z.W[j] != 0 || z.workingR[j] == 0) continue;
                // Aim for ~1/N of remaining donor (closed-form slice, not iterative target refine)
                uint256 slice = z.W[i] / 4;
                if (slice == 0) slice = 1;
                if (slice > z.W[i]) slice = z.W[i];
                uint256 maxV = _maxViableIn(z, i, j, slice);
                if (maxV == 0) {
                    // try tiny unit
                    maxV = _maxViableIn(z, i, j, 1);
                    if (maxV == 0) continue;
                    slice = maxV;
                } else if (slice > maxV) {
                    slice = maxV;
                }
                _zapTryExecuteExactIn(z, i, j, slice);
            }
        }
    }

    function _zapTargets(ZapWork memory z)
        private
        pure
        returns (uint256[4] memory T_s, bool allMatch)
    {
        uint256 V;
        uint256 S;
        uint256[4] memory wS;
        uint256[4] memory rS;
        for (uint256 i; i < 4; ++i) {
            wS[i] = Math.scaleTo(z.W[i], z.rates[i]);
            rS[i] = Math.scaleTo(z.workingR[i], z.rates[i]);
            V += wS[i];
            S += rS[i];
        }
        allMatch = true;
        if (S == 0 || V == 0) return (T_s, true);
        for (uint256 i; i < 4; ++i) {
            T_s[i] = (V * rS[i]) / S;
            if (wS[i] > T_s[i] + 1 || wS[i] + 1 < T_s[i]) allMatch = false;
        }
    }

    function _zapPassSurplusDeficit(ZapWork memory z, uint256[4] memory T_s) private view {
        // Cap internal swaps to avoid fee-driven thrashing under frozen T_s (plan: max 2 outer passes).
        for (uint256 n; n < 12; ++n) {
            if (!_zapOneInternalSwap(z, T_s)) break;
        }
    }

    /// @dev One surplus→deficit exact-in on working snapshot; returns true if a swap ran.
    function _zapOneInternalSwap(ZapWork memory z, uint256[4] memory T_s)
        private
        view
        returns (bool did)
    {
        for (uint256 i; i < 4; ++i) {
            uint256 wSi = Math.scaleTo(z.W[i], z.rates[i]);
            if (!(wSi > T_s[i] + 1)) continue;
            for (uint256 j; j < 4; ++j) {
                if (j == i) continue;
                uint256 wSj = Math.scaleTo(z.W[j], z.rates[j]);
                if (!(wSj + 1 < T_s[j])) continue;
                if (_zapApplyPair(z, i, j, T_s[j] - wSj, wSi, T_s[i])) return true;
            }
        }
        return false;
    }

    function _zapApplyPair(
        ZapWork memory z,
        uint256 i,
        uint256 j,
        uint256 needJScaled,
        uint256 wSi,
        uint256 Tsi
    ) private view returns (bool) {
        uint256 wantUserOut = Math.descaleUp(needJScaled, z.rates[j]);
        uint256 swapIn = _zapSizeSwapIn(z, i, j, wantUserOut, wSi, Tsi);
        if (swapIn == 0) return false;
        return _zapTryExecuteExactIn(z, i, j, swapIn);
    }

    function _zapTryExecuteExactIn(ZapWork memory z, uint256 i, uint256 j, uint256 swapIn)
        private
        view
        returns (bool)
    {
        try this.zapQuoteExactInExternal(z.workingR, z.rates, i, j, swapIn, z.amp, z.fee) returns (
            uint256 userOut, uint256[4] memory newR
        ) {
            if (userOut == 0 || swapIn > z.W[i]) return false;
            z.workingR = newR;
            z.W[i] -= swapIn;
            z.W[j] += userOut;
            return true;
        } catch {
            return false;
        }
    }

    /// @dev External boundary so zap internal swaps can try/catch quote failures.
    function zapQuoteExactInExternal(
        uint256[4] memory reserves,
        uint256[4] memory rates,
        uint256 i,
        uint256 j,
        uint256 swapIn,
        uint256 amp,
        uint24 fee
    ) external pure returns (uint256 userOut, uint256[4] memory newR) {
        return Math.quoteExactIn(reserves, rates, i, j, swapIn, amp, fee);
    }

    function _zapSizeSwapIn(
        ZapWork memory z,
        uint256 i,
        uint256 j,
        uint256 wantUserOutRaw,
        uint256 wSi,
        uint256 Tsi
    ) private view returns (uint256 swapIn) {
        uint256 rawSurplus = Math.descale(wSi > Tsi ? wSi - Tsi : 0, z.rates[i]);
        if (rawSurplus == 0 || wantUserOutRaw == 0) return 0;

        uint256 amountInIdeal = _closedFormInverseExactIn(z, i, j, wantUserOutRaw);
        // Ideal 0 means inverse unviable or need cannot be priced — fall back to maxViable only
        // (do not force full surplus; that can thrash / drain out-leg).
        if (amountInIdeal == 0) {
            return _maxViableIn(z, i, j, rawSurplus);
        }
        swapIn = rawSurplus < amountInIdeal ? rawSurplus : amountInIdeal;
        uint256 maxViable = _maxViableIn(z, i, j, rawSurplus);
        if (maxViable == 0) return 0;
        if (swapIn > maxViable) swapIn = maxViable;
    }

    function _closedFormInverseExactIn(ZapWork memory z, uint256 i, uint256 j, uint256 wantUserOutRaw)
        private
        view
        returns (uint256 amountInIdeal)
    {
        if (wantUserOutRaw == 0) return 0;
        uint256 rawOutNeeded = Math.feeOnOutputExactOutGrossUp(wantUserOutRaw, z.fee);
        if (rawOutNeeded >= z.workingR[j]) return 0;

        uint256[4] memory xp;
        xp[0] = Math.scaleTo(z.workingR[0], z.rates[0]);
        xp[1] = Math.scaleTo(z.workingR[1], z.rates[1]);
        xp[2] = Math.scaleTo(z.workingR[2], z.rates[2]);
        xp[3] = Math.scaleTo(z.workingR[3], z.rates[3]);
        if (xp[0] == 0 || xp[1] == 0 || xp[2] == 0 || xp[3] == 0) return 0;

        try this.tryGetYForZap(xp, z.amp, i, j, rawOutNeeded, z.rates[j]) returns (uint256 xInNew) {
            if (xInNew <= xp[i]) return 0;
            amountInIdeal = Math.descaleUp(xInNew - xp[i], z.rates[i]);
        } catch {
            return 0;
        }
    }

    /// @dev External try/catch boundary for zap inverse (pure relative to storage).
    function tryGetYForZap(
        uint256[4] memory xp,
        uint256 amp,
        uint256 i,
        uint256 j,
        uint256 rawOutNeeded,
        uint256 rateOut
    ) external pure returns (uint256 xInNew) {
        uint256 D = Math.getD(xp, amp);
        uint256 yOutScaledDelta = Math.scaleToUp(rawOutNeeded, rateOut);
        if (yOutScaledDelta >= xp[j]) revert InvariantFailed();
        uint256 yOutNew = xp[j] - yOutScaledDelta;
        if (yOutNew == 0) revert InvariantFailed();
        // external Math.getY — new stack frame
        xInNew = Math.getY(j, i, yOutNew, xp, amp, D);
    }

    function _maxViableIn(ZapWork memory z, uint256 i, uint256 j, uint256 rawSurplus)
        private
        view
        returns (uint256 maxViableIn)
    {
        uint256 outScaled = Math.scaleTo(z.workingR[j], z.rates[j]);
        // Leave enough scaled units that getY stays well-conditioned (plan: ≥1; use ≥1e12 when large).
        // Leave enough scaled units that getY stays well-conditioned (plan: ≥1; use ≥1e12 when large).
        uint256 leaveAmt = outScaled > 1e12 ? 1e12 : (outScaled > 1 ? 1 : 0);
        if (leaveAmt == 0 || outScaled <= leaveAmt) return 0;
        uint256 maxRawOut = Math.descale(outScaled - leaveAmt, z.rates[j]);
        if (maxRawOut == 0) return 0;
        (uint256 maxUserOut,) = Math.feeOnOutputExactIn(maxRawOut, z.fee);
        if (maxUserOut == 0) return 0;
        uint256 ideal = _closedFormInverseExactIn(z, i, j, maxUserOut);
        if (ideal == 0) return 0;
        maxViableIn = ideal < rawSurplus ? ideal : rawSurplus;
    }

    /* ---------------------------------------------------------------------- */
    /*                         ERC-20 mint / burn                             */
    /* ---------------------------------------------------------------------- */

    function _mint(address to, uint256 amount) internal {
        Repo.Layout storage l = Repo._layout();
        l.totalSupply += amount;
        l.balanceOf[to] += amount;
        // Transfer event emitted by wire
        _emitTransfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        Repo.Layout storage l = Repo._layout();
        l.balanceOf[from] -= amount;
        l.totalSupply -= amount;
        _emitTransfer(from, address(0), amount);
    }

    function _emitTransfer(address from, address to, uint256 amount) internal virtual;

    function _requirePriceable() internal view {
        uint256[4] memory r = Repo._layout().reserves;
        uint256[4] memory rates = _loadRates();
        uint256[4] memory xp;
        for (uint256 i; i < 4; ++i) {
            xp[i] = Math.scaleTo(r[i], rates[i]);
        }
        // require all four for full book priceability after add/zap
        if (xp[0] == 0 || xp[1] == 0 || xp[2] == 0 || xp[3] == 0) revert InvariantFailed();
        // external getD
        Math.getD(xp, getCurrentAmp());
    }
}
