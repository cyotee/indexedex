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
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
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
    UniswapV4DualStandardExchangeBufferConstantProductHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookBeforeInitializeLib.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

/// @title UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget
/// @notice Role Target for size-split Dual SE CP Buffer hook (Option 1a).
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget is UniswapV4DualStandardExchangeBufferConstantProductHookCommon, IHooks {
    using SafeERC20 for IERC20;

    function poolManager() public view returns (address) {
        return Repo._layout().poolManager;
    }


    function feeOracle() public view returns (address) {
        return Repo._layout().feeOracle;
    }


    function permit2() public pure returns (address) {
        return PERMIT2;
    }


    function standardExchange0() public view returns (address) {
        return Repo._layout().se0;
    }


    function standardExchange1() public view returns (address) {
        return Repo._layout().se1;
    }


    function token0() public view returns (address) {
        return Repo._layout().token0;
    }


    function token1() public view returns (address) {
        return Repo._layout().token1;
    }


    function currency0() public view returns (address) {
        return Repo._layout().currency0;
    }


    function currency1() public view returns (address) {
        return Repo._layout().currency1;
    }


    function tradingFeePercent() public pure returns (uint256) {
        return Repo.TRADING_FEE_PERCENT;
    }


    function tradingFeeDenominator() public pure returns (uint256) {
        return Repo.TRADING_FEE_DENOMINATOR;
    }


    function dexSwapFee() public view returns (uint256) {
        (, uint256 feeWad) =
            IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        return feeWad;
    }


    function feeTo() public view returns (address) {
        (IFeeCollectorProxy ft,) =
            IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        return address(ft);
    }


    function kLast() public view returns (uint256) {
        return Repo._layout().kLast;
    }


    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            beforeAddLiquidity: true,
            beforeSwap: true,
            beforeSwapReturnDelta: true,
            afterSwap: false,
            afterInitialize: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeDonate: false,
            afterDonate: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }


    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
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


    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
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


    function beforeSwap(address, PoolKey calldata, SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta swapDelta, uint24)
    {
        _onlyPoolManager();
        _requireLive();
        if (params.amountSpecified < 0) {
            swapDelta = _swapExactIn(params.zeroForOne, uint256(-params.amountSpecified));
        } else {
            swapDelta = _swapExactOut(params.zeroForOne, uint256(params.amountSpecified));
        }
        _syncReserves();
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
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }


    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }


    function previewSwapExactIn(bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactIn(zeroForOne, amountIn);
    }


    function previewSwapExactOut(bool zeroForOne, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOut(zeroForOne, amountOut);
    }

    function tokens() public view returns (address[] memory t) {
        t = new address[](2);
        t[0] = Repo._layout().currency0;
        t[1] = Repo._layout().currency1;
    }

    function standardExchangeOf(address token) public view returns (address) {
        return Repo._layout().legs.standardExchangeOf[token];
    }

    function syntheticNumeraires() public view returns (address[] memory n) {
        n = new address[](2);
        n[0] = Repo._layout().currency0;
        n[1] = Repo._layout().currency1;
    }

    function requiredFirstBondTokens() public view returns (address[] memory) {
        return tokens();
    }

    function firstJoinMustBeFullBook() public pure returns (bool) {
        return true;
    }

    function isLive() public view returns (bool) {
        return _isLive();
    }

    function tradingFeeWad() public pure returns (uint256) {
        return (Repo.TRADING_FEE_PERCENT * 1e18) / Repo.TRADING_FEE_DENOMINATOR;
    }

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        public
        view
        returns (uint256 amountOut)
    {
        if (!_isLive() || amountIn == 0) return 0;
        (bool ok, bool zfo) = _tryRouteZeroForOne(tokenIn, tokenOut);
        if (!ok) return 0;
        return _previewSwapExactIn(zfo, amountIn);
    }

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 amountIn)
    {
        if (!_isLive() || amountOut == 0) return 0;
        (bool ok, bool zfo) = _tryRouteZeroForOne(tokenIn, tokenOut);
        if (!ok) return 0;
        return _previewSwapExactOut(zfo, amountOut);
    }

    /// @dev Dual has no DETF self-leg. Do not invent Dual-as-DETF-reserve math (H2).
    function previewSynthetic(IDetfReserveQuote.DetfQuoteCtx calldata ctx, address numeraire)
        external
        view
        returns (uint256)
    {
        ctx;
        if (_classify(numeraire) == UniswapV4SeBufferHookLegLib.LegKind.Unknown) {
            return 0;
        }
        return 0;
    }

}
