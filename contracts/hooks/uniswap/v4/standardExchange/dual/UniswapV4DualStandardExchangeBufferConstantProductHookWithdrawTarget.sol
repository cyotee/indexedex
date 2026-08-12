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

/// @title UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget
/// @notice Role Target for size-split Dual SE CP Buffer hook (Option 1a).
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget is UniswapV4DualStandardExchangeBufferConstantProductHookCommon {
    using SafeERC20 for IERC20;

    function withdraw(
        uint256 lpAmount,
        address to,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        return _withdraw(lpAmount, to, minAmount0, minAmount1, deadline);
    }


    function withdrawFlexible(
        uint256 lpAmount,
        address to,
        bool receiveSeShare0,
        bool receiveSeShare1,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        return _withdrawFlexible(
            lpAmount, to, receiveSeShare0, receiveSeShare1, minAmount0, minAmount1, deadline
        );
    }


    function previewWithdraw(uint256 lpAmount)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _previewWithdraw(lpAmount);
    }


    function previewWithdrawFlexible(uint256 lpAmount, bool receiveSeShare0, bool receiveSeShare1)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _previewWithdrawFlexible(lpAmount, receiveSeShare0, receiveSeShare1);
    }


}
