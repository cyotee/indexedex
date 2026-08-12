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

/// @title UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget
/// @notice Role Target for size-split Dual SE CP Buffer hook (Option 1a).
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget is UniswapV4DualStandardExchangeBufferConstantProductHookCommon {
    using SafeERC20 for IERC20;

    function deposit(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        _pullErc20Dual(amount0, amount1);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }


    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount) {
        _pullErc20Single(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }


    function depositWithPermit2Signature(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        _pullPermit2SignatureDual(amount0, amount1, permit2Data);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }


    function depositWithPermit2Allowance(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        _pullPermit2AllowanceDual(amount0, amount1);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }


    function depositSingleWithPermit2Signature(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 lpAmount) {
        _pullPermit2SignatureSingle(tokenIn, amountIn, permit2Data);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }


    function depositSingleWithPermit2Allowance(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount) {
        _pullPermit2AllowanceSingle(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }


    function depositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        // Pure pair: pull then existing deposit (free pair does not inflate claims pre-buffer).
        if (!amount0IsSeShare && !amount1IsSeShare) {
            _pullFlexible(amount0, false, amount1, false);
            (lpAmount, used0, used1) = _deposit(amount0, amount1, to, minLpAmount, deadline);
            emit IHook.DepositFlexible(
                msg.sender, to, amount0, false, amount1, false, used0, used1, lpAmount
            );
            return (lpAmount, used0, used1);
        }

        // SE-bearing path: fee + claim snapshot must be pre-pull (SE is claim-bearing immediately).
        _requireDeadline(deadline);
        _requireNonZero(amount0);
        _requireNonZero(amount1);
        _mintProtocolFeeIfNeeded(true);
        uint256 xPre = claimSupplyCurrency0();
        uint256 yPre = claimSupplyCurrency1();
        _pullFlexible(amount0, amount0IsSeShare, amount1, amount1IsSeShare);
        return _depositFlexibleSe(
            amount0, amount0IsSeShare, amount1, amount1IsSeShare, to, minLpAmount, xPre, yPre
        );
    }


    function previewDeposit(uint256 amount0, uint256 amount1)
        external
        view
        returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        return _previewDeposit(amount0, amount1);
    }


    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 lpAmount)
    {
        return _previewDepositSingle(tokenIn, amountIn);
    }


    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn)
    {
        return _previewZapSplit(tokenIn, amountIn);
    }


    function previewDepositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare
    ) external view returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        return _previewDepositFlexible(amount0, amount0IsSeShare, amount1, amount1IsSeShare);
    }


}
