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

/// @title UniswapV4StandardExchangeOrbitalBufferHookDepositTarget
/// @notice Role Target for orbital buffer hook size split (Option 1a).
abstract contract UniswapV4StandardExchangeOrbitalBufferHookDepositTarget is UniswapV4StandardExchangeOrbitalBufferHookCommon {
    using SafeERC20 for IERC20;

    function addLiquidity(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2) {
        return _addLiquidity(a0Max, a1Max, a2Max, to, sharesMin, deadline, permit2Data);
    }


    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares) {
        return _depositSingle(tokenIn, amountIn, to, sharesMin, deadline, permit2Data);
    }


    function previewAddLiquidity(uint256 a0Max, uint256 a1Max, uint256 a2Max)
        external
        view
        returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2)
    {
        return _previewAddLiquidity(a0Max, a1Max, a2Max);
    }


    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares)
    {
        return _previewDepositSingle(tokenIn, amountIn);
    }


    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 saleJ, uint256 saleK, uint256 residualIn, uint256 outJ, uint256 outK)
    {
        return _previewZapSplit(tokenIn, amountIn);
    }


    function depositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external nonReentrant returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        DepositFlexibleVars memory v;
        v.amount0 = amount0;
        v.amount0IsSeShare = amount0IsSeShare;
        v.amount1 = amount1;
        v.amount1IsSeShare = amount1IsSeShare;
        v.amount2 = amount2;
        v.amount2IsSeShare = amount2IsSeShare;
        v.to = to;
        v.sharesMin = sharesMin;
        return _depositFlexible(v, deadline);
    }


    function previewDepositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare
    ) external view returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        DepositFlexibleVars memory v;
        v.amount0 = amount0;
        v.amount0IsSeShare = amount0IsSeShare;
        v.amount1 = amount1;
        v.amount1IsSeShare = amount1IsSeShare;
        v.amount2 = amount2;
        v.amount2IsSeShare = amount2IsSeShare;
        return _previewDepositFlexible(v);
    }



}
