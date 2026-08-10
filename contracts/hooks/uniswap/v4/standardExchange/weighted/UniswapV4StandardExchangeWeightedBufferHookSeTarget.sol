// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookTarget
 * @notice Product logic: dual-scale weighted book, SE buffer-last LP, rated V4/SE swaps, MultiAssetLiquidity.
 * @dev No BaseHook / DeltaResolver inheritance. LP via ERC20Repo; inventory = face | live SE shares.
 */
import {
    UniswapV4StandardExchangeWeightedBufferHookHooksTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookSeTarget
 * @notice SE In/Out swap-only surface.
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHookSeTarget is
    UniswapV4StandardExchangeWeightedBufferHookHooksTarget,
    IStandardExchangeIn,
    IStandardExchangeOut
{
    using SafeERC20 for IERC20;

/* ---------------------------------------------------------------------- */
    /*                         SE In / Out (swap-only)                        */
    /* ---------------------------------------------------------------------- */

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactIn(address(tokenIn), address(tokenOut), amountIn);
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        _requireDeadline(deadline);
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        if (tin == tout) revert InvalidRoute(tin, tout);
        _tokenIndex(tin);
        _tokenIndex(tout);

        // L-GAPS-11 / ISecurePullErrors: pretransfer credits only in-window delta (I1/I3).
        _securePull(IERC20(tin), amountIn, pretransferred);

        amountOut = _previewSwapExactIn(tin, tout, amountIn);
        if (amountOut < minAmountOut) revert Slippage();

        uint8 j = _tokenIndex(tout);
        uint8 i = _tokenIndex(tin);
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[j] != address(0)) {
            _unwrapExactTokenOut(j, amountOut, recipient);
        } else {
            if (amountOut >= l.rawReserves[j]) revert WouldZeroReserve();
            l.rawReserves[j] -= amountOut;
            IERC20(tout).safeTransfer(recipient, amountOut);
        }
        // buffer-last in
        if (l.standardExchanges[i] != address(0)) {
            _bufferToken(i, amountIn);
        } else {
            l.rawReserves[i] += amountIn;
        }
        _syncVaultReserves();
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOut(address(tokenIn), address(tokenOut), amountOut);
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        _requireDeadline(deadline);
        if (amountOut == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        amountIn = _previewSwapExactOut(tin, tout, amountOut);
        if (amountIn > maxAmountIn) revert Slippage();

        // L-GAPS-11: delta-gate claimed amountIn (no absolute free inventory credit).
        _securePull(IERC20(tin), amountIn, pretransferred);

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

}
