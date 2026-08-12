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
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";

/// @title UniswapV4StandardExchangeOrbitalBufferHookHooksTarget
/// @notice Role Target for orbital buffer hook size split (Option 1a).
abstract contract UniswapV4StandardExchangeOrbitalBufferHookHooksTarget is UniswapV4StandardExchangeOrbitalBufferHookCommon, IHooks {
    using SafeERC20 for IERC20;

    function poolManager() public view returns (IPoolManager) {
        return IPoolManager(Repo._layout().poolManager);
    }


    function feeOracle() public view returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle);
    }


    function standardExchange(uint8 i) public view returns (address) {
        return Repo._seAt(Repo._layout(), i);
    }


    function rateProvider(uint8 i) public view returns (address) {
        return Repo._rpAt(Repo._layout(), i);
    }


    function isBuffered(uint8 i) public view returns (bool) {
        return Repo._seAt(Repo._layout(), i) != address(0);
    }


    function permit2() public pure returns (address) {
        return PERMIT2;
    }


    function rawReserve(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address t = Repo._tokenAt(l, i);
        if (Repo._seAt(l, i) != address(0)) return 0;
        return l.reserves[t];
    }


    function seBalance(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        if (se == address(0)) return 0;
        return IERC20(se).balanceOf(address(this));
    }


    function seClaim(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        if (se == address(0)) return 0;
        return ClaimLib.seClaimOf(se, Repo._tokenAt(l, i), IERC20(se).balanceOf(address(this)));
    }


    function effectiveReserve(uint8 i) public view returns (uint256) {
        return _effectiveNativeAt(i);
    }


    function effectiveReserves() public view returns (uint256 e0, uint256 e1, uint256 e2) {
        e0 = _effectiveNativeAt(0);
        e1 = _effectiveNativeAt(1);
        e2 = _effectiveNativeAt(2);
    }


    function radius() public view returns (uint256) {
        return Repo._layout().R;
    }


    function lSquared() public view returns (uint256) {
        return Repo._layout().L_SQUARED;
    }


    function dexSwapFee() public view returns (uint256) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeOfVault(address(this));
    }


    function usageFee() public view returns (uint256) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle).usageFeeOfVault(address(this));
    }


    function feeTo() public view returns (address) {
        return address(IVaultFeeOracleQuery(Repo._layout().feeOracle).feeTo());
    }


    function kLast() public view returns (uint256) {
        return Repo._layout().kLast;
    }


    function kLastMode() public view returns (IUniswapV4StandardExchangeOrbitalBufferHook.KLastMode) {
        return IUniswapV4StandardExchangeOrbitalBufferHook.KLastMode(Repo._layout().kLastMode);
    }


    function pairPoolTickSpacing() public view returns (int24) {
        return Repo._layout().tickSpacing;
    }


    function pairPoolSqrtPriceX96() public view returns (uint160) {
        return Repo._layout().sqrtPriceX96;
    }


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
            beforeDonate: false,
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
        if (!_isBound(a) || !_isBound(b) || a == b) revert InvalidPoolToken();
        if (poolKey.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) revert InvalidPoolFee();
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
        _lock();
        address c0 = Currency.unwrap(key.currency0);
        address c1 = Currency.unwrap(key.currency1);
        if (!_isBound(c0) || !_isBound(c1)) {
            _unlock();
            revert InvalidPoolToken();
        }

        address tokenIn = params.zeroForOne ? c0 : c1;
        address tokenOut = params.zeroForOne ? c1 : c0;
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) {
            _unlock();
            revert Math.MathDomain();
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
        // Buffer-last: unwrap out already done inside execute; buffer in after take
        if (_seOf(tokenIn) != address(0)) {
            _bufferToken(tokenIn, amountIn);
        } else {
            Repo._layout().reserves[tokenIn] += amountIn;
        }
        _settle(Currency.wrap(tokenOut), amountOut);
        _recomputeL2();
        _syncVaultReserves();

        emit Swap(tx.origin, tokenIn, tokenOut, amountIn, amountOut, feeWad);
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


    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactIn(tokenIn, tokenOut, amountIn);
    }


    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOut(tokenIn, tokenOut, amountOut);
    }



}
