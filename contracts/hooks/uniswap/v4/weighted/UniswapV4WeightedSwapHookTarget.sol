// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4WeightedSwapHookCommon
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookCommon.sol";
import {
    UniswapV4WeightedSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookRepo.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";

/**
 * @title UniswapV4WeightedSwapHookTarget
 * @notice IHooks + join/exit + Weighted beforeSwap (fee-on-input, dynamic fee override).
 * @dev Settle pattern-copy from dual/orbital. rootK = V. Partial dual-mode O4.
 */
abstract contract UniswapV4WeightedSwapHookTarget is UniswapV4WeightedSwapHookCommon, IHooks {
    constructor(IPoolManager poolManager_, IVaultFeeOracleQuery feeOracle_)
        UniswapV4WeightedSwapHookCommon(poolManager_, feeOracle_)
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
        _tokenIndex(a);
        _tokenIndex(b);
        if (poolKey.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) revert InvalidPoolKey();
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
        _lock();
        address c0 = Currency.unwrap(key.currency0);
        address c1 = Currency.unwrap(key.currency1);
        address tokenIn = params.zeroForOne ? c0 : c1;
        address tokenOut = params.zeroForOne ? c1 : c0;

        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) {
            _unlock();
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

        emit IUniswapV4WeightedSwapHook.Swap(tx.origin, tokenIn, tokenOut, amountIn, amountOut, feeWad);
        _unlock();
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
    /*                              Swap execute                              */
    /* ---------------------------------------------------------------------- */

    function _swapExactInExecute(address tokenIn, address tokenOut, uint256 amountIn, uint256 feeWad)
        internal
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        amountOut = _previewSwapExactIn(tokenIn, tokenOut, amountIn);
        Repo.Layout storage l = Repo._layout();
        uint256 i = _tokenIndex(tokenIn);
        uint256 j = _tokenIndex(tokenOut);
        l.reserves[i] += amountIn; // gross (fee residual stays)
        if (amountOut >= l.reserves[j]) revert WouldZeroReserve();
        l.reserves[j] -= amountOut;
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();
        feeWad;
    }

    function _swapExactOutExecute(address tokenIn, address tokenOut, uint256 amountOut, uint256 feeWad)
        internal
        returns (uint256 amountIn)
    {
        if (amountOut == 0) revert ZeroAmount();
        amountIn = _previewSwapExactOut(tokenIn, tokenOut, amountOut);
        Repo.Layout storage l = Repo._layout();
        uint256 i = _tokenIndex(tokenIn);
        uint256 j = _tokenIndex(tokenOut);
        if (amountOut >= l.reserves[j]) revert WouldZeroReserve();
        l.reserves[i] += amountIn;
        l.reserves[j] -= amountOut;
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();
        feeWad;
    }

    function _previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert InvalidPair();
        Repo.Layout storage l = Repo._layout();
        uint256 i = _tokenIndex(tokenIn);
        uint256 j = _tokenIndex(tokenOut);
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();
        uint256 rateIn = _effectiveRate(i);
        uint256 rateOut = _effectiveRate(j);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256 balInS = Math.scaleTo(l.reserves[i], rateIn);
        uint256 balOutS = Math.scaleTo(l.reserves[j], rateOut);
        amountOut = Math.quoteExactIn(
            balInS, l.weights[i], balOutS, l.weights[j], amountIn, rateIn, rateOut, feeWad
        );
        if (amountOut >= l.reserves[j]) revert WouldZeroReserve();
    }

    function _previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        if (amountOut == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert InvalidPair();
        Repo.Layout storage l = Repo._layout();
        uint256 i = _tokenIndex(tokenIn);
        uint256 j = _tokenIndex(tokenOut);
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();
        if (amountOut >= l.reserves[j]) revert WouldZeroReserve();
        uint256 rateIn = _effectiveRate(i);
        uint256 rateOut = _effectiveRate(j);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256 balInS = Math.scaleTo(l.reserves[i], rateIn);
        uint256 balOutS = Math.scaleTo(l.reserves[j], rateOut);
        amountIn = Math.quoteExactOut(
            balInS, l.weights[i], balOutS, l.weights[j], amountOut, rateIn, rateOut, feeWad
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                           Protocol growth mint                         */
    /* ---------------------------------------------------------------------- */

    function _maybeMintProtocolFee() internal returns (uint256 protocolLp) {
        (bool feeOn, address feeTo_, uint256 ownerFeeShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0) return 0;

        uint256[] memory rates = _loadRates();
        (uint8 mode,, uint256 rootK) = _measureK(rates);
        if (mode != l.kLastMode) return 0;

        // rootKLast = stored k (rootK = V or interim k, both stored as k itself)
        protocolLp = Math.protocolLpShares(l.totalSupply, rootK, l.kLast, ownerFeeShare);
        if (protocolLp > 0) {
            _mint(feeTo_, protocolLp);
            emit IUniswapV4WeightedSwapHook.ProtocolFeeMinted(feeTo_, protocolLp);
        }
    }

    function _snapshotKLastIfFeeOn() internal {
        (bool feeOn,,,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn) {
            l.kLast = 0;
            return;
        }
        uint256[] memory rates = _loadRates();
        (uint8 mode, uint256 k,) = _measureK(rates);
        l.kLast = k;
        l.kLastMode = mode;
    }

    function _previewProtocolMintShares()
        internal
        view
        returns (uint256 protocolLp, uint256 supplyAfter)
    {
        Repo.Layout storage l = Repo._layout();
        supplyAfter = l.totalSupply;
        (bool feeOn,, uint256 ownerFeeShare,) = _feeOnAndShare();
        if (!feeOn || l.kLast == 0) return (0, supplyAfter);

        uint256[] memory rates = _loadRates();
        (uint8 mode,, uint256 rootK) = _measureK(rates);
        if (mode != l.kLastMode) return (0, supplyAfter);

        protocolLp = Math.protocolLpShares(l.totalSupply, rootK, l.kLast, ownerFeeShare);
        supplyAfter = l.totalSupply + protocolLp;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Liquidity: join                           */
    /* ---------------------------------------------------------------------- */

    function _joinProportional(
        uint256[] memory amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) internal returns (uint256 shares, uint256[] memory used) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();

        _maybeMintProtocolFee();
        bool first = l.totalSupply == 0;
        (shares, used) = _computeJoinProportional(amounts);
        if (shares < sharesMin) revert Slippage();
        _commitJoin(used, to, shares, permit2Data, first);
    }

    function _computeJoinProportional(uint256[] memory amounts)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = l.totalSupply;
        uint256[] memory rates = _loadRates();
        if (supply == 0) {
            return _firstMint(amounts, rates);
        }
        if (Math.isFullBookReserves(l.reserves)) {
            return _fullPropJoin(amounts, rates, supply);
        }
        return _partialJoin(amounts, rates, supply);
    }

    function _firstMint(uint256[] memory amounts, uint256[] memory rates)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        used = amounts;
        uint256 pos = Math.countPositive(amounts);
        if (n == 2) {
            // n==2: both legs required
            if (pos != 2) revert ZeroAmount();
        } else {
            if (pos < 2) revert ZeroAmount();
        }
        uint256[] memory scaled = _scaleAmounts(amounts, rates);
        if (pos == n) {
            // full first mint O2
            for (uint256 i; i < n; ++i) {
                if (amounts[i] == 0) revert ZeroAmount();
            }
            (shares,) = Math.firstMintSharesFull(l.weights, scaled);
        } else {
            // partial first mint O4 (n>=3)
            (shares,) = Math.firstMintSharesPartial(l.weights, scaled);
        }
    }

    function _fullPropJoin(uint256[] memory amounts, uint256[] memory rates, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        for (uint256 i; i < n; ++i) {
            if (amounts[i] == 0) revert ZeroAmount();
        }
        uint256[] memory aS = _scaleAmounts(amounts, rates);
        uint256[] memory rS = _scaleReserves(rates);
        shares = Math.proportionalJoinShares(aS, rS, supply);
        used = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            uint256 usedS = Math.proportionalUsedScaled(shares, rS[i], supply);
            used[i] = Math.descale(usedS, rates[i]);
            if (used[i] == 0 || used[i] > amounts[i]) revert Slippage();
        }
    }

    function _partialJoin(uint256[] memory amounts, uint256[] memory rates, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        used = new uint256[](n);

        // working balances for k
        uint256[] memory working = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            working[i] = Math.scaleTo(l.reserves[i], rates[i]);
        }
        uint256 kBefore = Math.computeInterimK(l.weights, working);

        bool anySeed;
        bool anyProp;
        // seed zeros fully
        for (uint256 i; i < n; ++i) {
            if (l.reserves[i] == 0 && amounts[i] > 0) {
                used[i] = amounts[i];
                working[i] = Math.scaleTo(amounts[i], rates[i]);
                anySeed = true;
            }
        }
        // prop on positive reserve legs
        uint256 minShares = type(uint256).max;
        for (uint256 i; i < n; ++i) {
            if (l.reserves[i] > 0 && amounts[i] > 0) {
                uint256 aS = Math.scaleTo(amounts[i], rates[i]);
                uint256 rS = Math.scaleTo(l.reserves[i], rates[i]);
                uint256 s = (aS * supply) / rS;
                if (s < minShares) minShares = s;
                anyProp = true;
            }
        }
        if (anyProp) {
            if (minShares == 0 || minShares == type(uint256).max) revert ZeroAmount();
            for (uint256 i; i < n; ++i) {
                if (l.reserves[i] > 0 && amounts[i] > 0) {
                    uint256 rS = Math.scaleTo(l.reserves[i], rates[i]);
                    uint256 usedS = Math.proportionalUsedScaled(minShares, rS, supply);
                    used[i] = Math.descale(usedS, rates[i]);
                    if (used[i] == 0) revert ZeroAmount();
                    working[i] = rS + usedS;
                }
            }
        }

        if (!anySeed && !anyProp) revert ZeroAmount();

        // Pure prop (no seed): Uni V2 min-ratio on positive legs.
        // Seed involved: prefer interim-k growth; if k does not rise (renorm discontinuity
        // when completing a leg), fall back to weight·balance NAV of seeds vs book.
        if (anySeed) {
            uint256 kAfter = Math.computeInterimK(l.weights, working);
            if (kAfter > kBefore) {
                shares = Math.partialJoinSharesFromK(supply, kBefore, kAfter);
            } else {
                shares = _seedNavShares(used, rates, supply);
            }
        } else {
            shares = minShares;
        }
    }

    /// @dev shares ≈ supply * Σ(used_i·w_i scaled) / Σ(r_j·w_j scaled) for seed fallback.
    function _seedNavShares(uint256[] memory used, uint256[] memory rates, uint256 supply)
        internal
        view
        returns (uint256 shares)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 vIn;
        uint256 vBook;
        for (uint256 i; i < l.numTokens; ++i) {
            uint256 rS = Math.scaleTo(l.reserves[i], rates[i]);
            uint256 uS = Math.scaleTo(used[i], rates[i]);
            vBook += (rS * l.weights[i]) / Math.WAD;
            vIn += (uS * l.weights[i]) / Math.WAD;
        }
        if (vBook == 0 || vIn == 0) revert ZeroAmount();
        shares = (supply * vIn) / vBook;
        if (shares == 0) revert ZeroAmount();
    }

    function _joinUnbalanced(
        uint256[] memory amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();
        if (l.totalSupply == 0) {
            return _joinUnbalancedFirst(amounts, to, sharesMin, permit2Data);
        }
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        _maybeMintProtocolFee();
        shares = _quoteUnbalancedJoin(amounts);
        if (shares < sharesMin) revert Slippage();
        _commitJoin(amounts, to, shares, permit2Data, false);
    }

    function _joinUnbalancedFirst(
        uint256[] memory amounts,
        address to,
        uint256 sharesMin,
        bytes calldata permit2Data
    ) private returns (uint256 shares) {
        if (Math.countPositive(amounts) != Repo._layout().numTokens) revert NotFullBook();
        (shares,) = _firstMint(amounts, _loadRates());
        if (shares < sharesMin) revert Slippage();
        _commitJoin(amounts, to, shares, permit2Data, true);
    }

    function _quoteUnbalancedJoin(uint256[] memory amounts) internal view returns (uint256 shares) {
        Repo.Layout storage l = Repo._layout();
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        shares = Math.unbalancedJoinShares(
            _scaleReserves(rates), _scaleAmounts(amounts, rates), l.weights, l.totalSupply, feeWad
        );
    }

    function _commitJoin(
        uint256[] memory amounts,
        address to,
        uint256 shares,
        bytes calldata permit2Data,
        bool firstMint
    ) private {
        Repo.Layout storage l = Repo._layout();
        _pullAmounts(amounts, permit2Data);
        for (uint256 i; i < l.numTokens; ++i) {
            l.reserves[i] += amounts[i];
        }
        if (firstMint) {
            _mint(address(0), Math.MINIMUM_LIQUIDITY);
        }
        _mint(to, shares);
        _snapshotKLastIfFeeOn();
        emit IUniswapV4WeightedSwapHook.LiquidityJoined(msg.sender, to, shares, amounts);
    }

    function _joinSingleExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amountIn == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        if (l.totalSupply == 0 || !Math.isFullBookReserves(l.reserves)) revert NotFullBook();

        _maybeMintProtocolFee();
        shares = _quoteSingleJoinExactIn(tokenIn, amountIn);
        if (shares < sharesMin) revert Slippage();

        uint256 idx = _tokenIndex(tokenIn);
        uint256[] memory used = new uint256[](l.numTokens);
        used[idx] = amountIn;
        _pullAmounts(used, permit2Data);
        l.reserves[idx] += amountIn;
        _mint(to, shares);
        _snapshotKLastIfFeeOn();
        emit IUniswapV4WeightedSwapHook.LiquidityJoined(msg.sender, to, shares, used);
    }

    function _quoteSingleJoinExactIn(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 shares)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 idx = _tokenIndex(tokenIn);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        shares = Math.singleJoinExactInShares(
            _scaleReserves(rates),
            l.weights,
            idx,
            Math.scaleTo(amountIn, rates[idx]),
            l.totalSupply,
            feeWad
        );
    }

    function _joinSingleExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline,
        bytes calldata permit2Data
    ) internal returns (uint256 amountIn) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (sharesOut == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        if (l.totalSupply == 0 || !Math.isFullBookReserves(l.reserves)) revert NotFullBook();

        _maybeMintProtocolFee();
        amountIn = _quoteSingleJoinExactOut(tokenIn, sharesOut);
        if (amountIn > amountInMax) revert Slippage();

        uint256 idx = _tokenIndex(tokenIn);
        uint256[] memory used = new uint256[](l.numTokens);
        used[idx] = amountIn;
        _pullAmounts(used, permit2Data);
        l.reserves[idx] += amountIn;
        _mint(to, sharesOut);
        _snapshotKLastIfFeeOn();
        emit IUniswapV4WeightedSwapHook.LiquidityJoined(msg.sender, to, sharesOut, used);
    }

    function _quoteSingleJoinExactOut(address tokenIn, uint256 sharesOut)
        internal
        view
        returns (uint256 amountIn)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 idx = _tokenIndex(tokenIn);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        uint256 aS = Math.singleJoinExactOutAmountIn(
            _scaleReserves(rates), l.weights, idx, sharesOut, l.totalSupply, feeWad
        );
        amountIn = Math.descaleUp(aS, rates[idx]);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Liquidity: exit                           */
    /* ---------------------------------------------------------------------- */

    function _exitProportional(
        uint256 shares,
        address to,
        uint256[] memory amountsMin,
        uint256 deadline
    ) internal returns (uint256[] memory amounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroAmount();

        _maybeMintProtocolFee();
        Repo.Layout storage l = Repo._layout();
        if (amountsMin.length != l.numTokens) revert InvalidN();
        uint256 supply = l.totalSupply;
        amounts = Math.proportionalExitAmounts(shares, l.reserves, supply);
        for (uint256 i; i < l.numTokens; ++i) {
            if (amounts[i] < amountsMin[i]) revert Slippage();
        }

        // D67 full book: no leg zeroing
        if (Math.isFullBookReserves(l.reserves)) {
            for (uint256 i; i < l.numTokens; ++i) {
                if (amounts[i] >= l.reserves[i]) revert WouldZeroReserve();
            }
        }

        _burn(msg.sender, shares);
        for (uint256 i; i < l.numTokens; ++i) {
            l.reserves[i] -= amounts[i];
            _push(l.tokens[i], to, amounts[i]);
        }
        // partial exit: require at least one positive if supply remains
        if (l.totalSupply > Math.MINIMUM_LIQUIDITY) {
            bool any;
            for (uint256 i; i < l.numTokens; ++i) {
                if (l.reserves[i] > 0) {
                    any = true;
                    break;
                }
            }
            if (!any) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        emit IUniswapV4WeightedSwapHook.LiquidityExited(msg.sender, to, shares, amounts);
    }

    function _exitSingleExactIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (sharesIn == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();

        _maybeMintProtocolFee();
        amountOut = _quoteExitSingleExactIn(tokenOut, sharesIn);
        if (amountOut < amountOutMin) revert Slippage();
        uint256 idx = _tokenIndex(tokenOut);
        if (amountOut >= l.reserves[idx]) revert WouldZeroReserve();

        _burn(msg.sender, sharesIn);
        l.reserves[idx] -= amountOut;
        for (uint256 i; i < l.numTokens; ++i) {
            if (l.reserves[i] == 0) revert WouldZeroReserve();
        }
        _push(tokenOut, to, amountOut);
        _snapshotKLastIfFeeOn();
        uint256[] memory amts = new uint256[](l.numTokens);
        amts[idx] = amountOut;
        emit IUniswapV4WeightedSwapHook.LiquidityExited(msg.sender, to, sharesIn, amts);
    }

    function _quoteExitSingleExactIn(address tokenOut, uint256 sharesIn)
        internal
        view
        returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 idx = _tokenIndex(tokenOut);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        uint256 outS = Math.singleExitExactInAmountOut(
            _scaleReserves(rates), l.weights, idx, sharesIn, l.totalSupply, feeWad
        );
        amountOut = Math.descale(outS, rates[idx]);
    }

    function _exitSingleExactOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) internal returns (uint256 sharesIn) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amountOut == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();

        _maybeMintProtocolFee();
        sharesIn = _quoteExitSingleExactOut(tokenOut, amountOut);
        if (sharesIn > sharesInMax) revert Slippage();
        uint256 idx = _tokenIndex(tokenOut);
        if (amountOut >= l.reserves[idx]) revert WouldZeroReserve();

        _burn(msg.sender, sharesIn);
        l.reserves[idx] -= amountOut;
        for (uint256 i; i < l.numTokens; ++i) {
            if (l.reserves[i] == 0) revert WouldZeroReserve();
        }
        _push(tokenOut, to, amountOut);
        _snapshotKLastIfFeeOn();
        uint256[] memory amts = new uint256[](l.numTokens);
        amts[idx] = amountOut;
        emit IUniswapV4WeightedSwapHook.LiquidityExited(msg.sender, to, sharesIn, amts);
    }

    function _quoteExitSingleExactOut(address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 sharesIn)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 idx = _tokenIndex(tokenOut);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        sharesIn = Math.singleExitExactOutSharesIn(
            _scaleReserves(rates),
            l.weights,
            idx,
            Math.scaleToUp(amountOut, rates[idx]),
            l.totalSupply,
            feeWad
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                              Previews                                  */
    /* ---------------------------------------------------------------------- */

    function _previewJoinProportional(uint256[] memory amounts)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        uint256[] memory rates = _loadRates();
        if (l.totalSupply == 0) {
            return _firstMint(amounts, rates);
        }
        if (Math.isFullBookReserves(l.reserves)) {
            return _fullPropJoin(amounts, rates, supplyAfter);
        }
        return _partialJoin(amounts, rates, supplyAfter);
    }

    function _previewJoinUnbalanced(uint256[] memory amounts) internal view returns (uint256 shares) {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();
        if (l.totalSupply == 0) {
            uint256[] memory rates0 = _loadRates();
            (shares,) = _firstMint(amounts, rates0);
            return shares;
        }
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        uint256[] memory rates = _loadRates();
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rS = _scaleReserves(rates);
        uint256[] memory aS = _scaleAmounts(amounts, rates);
        shares = Math.unbalancedJoinShares(rS, aS, l.weights, supplyAfter, feeWad);
    }

    function _previewJoinSingleExactIn(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 shares)
    {
        Repo.Layout storage l = Repo._layout();
        if (l.totalSupply == 0 || !Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        if (amountIn == 0) revert ZeroAmount();
        // growth-aware: use post-protocol supply via temporary math with supplyAfter
        (uint256 protocolLp, uint256 supplyAfter) = _previewProtocolMintShares();
        protocolLp;
        uint256 idx = _tokenIndex(tokenIn);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        shares = Math.singleJoinExactInShares(
            _scaleReserves(rates),
            l.weights,
            idx,
            Math.scaleTo(amountIn, rates[idx]),
            supplyAfter,
            feeWad
        );
    }

    function _previewJoinSingleExactOut(address tokenIn, uint256 sharesOut)
        internal
        view
        returns (uint256 amountIn)
    {
        Repo.Layout storage l = Repo._layout();
        if (l.totalSupply == 0 || !Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        if (sharesOut == 0) revert ZeroAmount();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        uint256 idx = _tokenIndex(tokenIn);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        uint256 aS = Math.singleJoinExactOutAmountIn(
            _scaleReserves(rates), l.weights, idx, sharesOut, supplyAfter, feeWad
        );
        amountIn = Math.descaleUp(aS, rates[idx]);
    }

    function _previewExitProportional(uint256 shares)
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (shares == 0) revert ZeroAmount();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        Repo.Layout storage l = Repo._layout();
        amounts = Math.proportionalExitAmounts(shares, l.reserves, supplyAfter);
    }

    function _previewExitSingleExactIn(address tokenOut, uint256 sharesIn)
        internal
        view
        returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        if (sharesIn == 0) revert ZeroAmount();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        uint256 idx = _tokenIndex(tokenOut);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        uint256 outS = Math.singleExitExactInAmountOut(
            _scaleReserves(rates), l.weights, idx, sharesIn, supplyAfter, feeWad
        );
        amountOut = Math.descale(outS, rates[idx]);
    }

    function _previewExitSingleExactOut(address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 sharesIn)
    {
        Repo.Layout storage l = Repo._layout();
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        if (amountOut == 0) revert ZeroAmount();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        uint256 idx = _tokenIndex(tokenOut);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        sharesIn = Math.singleExitExactOutSharesIn(
            _scaleReserves(rates),
            l.weights,
            idx,
            Math.scaleToUp(amountOut, rates[idx]),
            supplyAfter,
            feeWad
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                              Permit2 / pull                            */
    /* ---------------------------------------------------------------------- */

    function _pullAmounts(uint256[] memory used, bytes calldata permit2Data) internal {
        Repo.Layout storage l = Repo._layout();
        if (permit2Data.length == 0) {
            for (uint256 i; i < l.numTokens; ++i) {
                if (used[i] > 0) _pull(l.tokens[i], used[i]);
            }
            return;
        }

        uint8 mode;
        if (permit2Data.length >= 32) {
            mode = abi.decode(permit2Data[:32], (uint8));
        } else {
            mode = uint8(permit2Data[0]);
        }

        if (mode == 0) {
            (, ISignatureTransfer.PermitBatchTransferFrom memory permit, bytes memory signature) =
                abi.decode(permit2Data, (uint8, ISignatureTransfer.PermitBatchTransferFrom, bytes));
            _pullSignatureBatch(used, permit, signature);
        } else if (mode == 1) {
            for (uint256 i; i < l.numTokens; ++i) {
                if (used[i] > 0) {
                    IAllowanceTransfer(PERMIT2).transferFrom(
                        msg.sender, address(this), uint160(used[i]), l.tokens[i]
                    );
                }
            }
        } else {
            revert InvalidPermit2Data();
        }
    }

    function _pullSignatureBatch(
        uint256[] memory used,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes memory signature
    ) internal {
        Repo.Layout storage l = Repo._layout();
        uint256 n;
        for (uint256 i; i < l.numTokens; ++i) {
            if (used[i] > 0) ++n;
        }
        if (permit.permitted.length != n) revert InvalidPermit2Data();

        ISignatureTransfer.SignatureTransferDetails[] memory details =
            new ISignatureTransfer.SignatureTransferDetails[](n);
        uint256 k;
        for (uint256 i; i < l.numTokens; ++i) {
            if (used[i] == 0) continue;
            if (permit.permitted[k].token != l.tokens[i]) revert InvalidPermit2Data();
            details[k] = ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: used[i]
            });
            ++k;
        }
        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, details, msg.sender, signature);
    }
}
