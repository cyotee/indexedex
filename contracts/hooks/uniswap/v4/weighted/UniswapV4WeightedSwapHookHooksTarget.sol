// SPDX-License-Identifier: BSL-1.1
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

abstract contract UniswapV4WeightedSwapHookHooksTarget is UniswapV4WeightedSwapHookCommon, IHooks {
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

        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
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
        _syncVaultReserves();
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
        _syncVaultReserves();
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
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
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
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256 balInS = Math.scaleTo(l.reserves[i], rateIn);
        uint256 balOutS = Math.scaleTo(l.reserves[j], rateOut);
        amountIn = Math.quoteExactOut(
            balInS, l.weights[i], balOutS, l.weights[j], amountOut, rateIn, rateOut, feeWad
        );
    }


    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        return _previewSwapExactIn(tokenIn, tokenOut, amountIn);
    }


    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256)
    {
        return _previewSwapExactOut(tokenIn, tokenOut, amountOut);
    }



}
