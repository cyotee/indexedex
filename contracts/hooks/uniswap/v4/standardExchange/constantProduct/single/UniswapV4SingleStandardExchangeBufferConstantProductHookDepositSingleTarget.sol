// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4SingleStandardExchangeBufferConstantProductHookInExecutionBase} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookInExecutionBase.sol";
import {NativeStandardYieldMoneyTarget as NativeStandardYieldExecutionTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib as Withdrawal} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol";

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib as PullLib
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {UniswapV4SeBufferHookLegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget
/// @notice Single-asset CP deposits sharing the reserve accounting and reentrancy guard.
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget is
    UniswapV4SingleStandardExchangeBufferConstantProductHookInExecutionBase, NativeStandardYieldExecutionTarget
{
    function isValidTokenIn(address token_) public view override returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return token_ == l.rawToken || token_ == l.pairToken || token_ == l.standardExchange;
    }
    function isValidTokenOut(address token_) public view override returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return token_ == l.rawToken || token_ == l.pairToken;
    }
    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override onlyLiquidityRemover nonReentrant returns (uint256)
    {
        return Withdrawal.withdrawFrom(address(this), shares_, tokenOut_, receiver_, minimum_, block.timestamp);
    }
    function exchangeIn(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address to_, bool prepaid_, uint256 deadline_)
        external returns (uint256)
    {
        if (LiquidityRoute.isLiquidityRoute(in_, out_)) return _exchangeIn(in_, amount_, out_, minimum_, to_, prepaid_, deadline_);
        return _swapExchangeIn(in_, amount_, out_, minimum_, to_, prepaid_, deadline_);
    }

    /// @notice CP joinSingleAssetExactIn entry point.
    function joinSingleAssetExactIn(address tokenIn, uint256 amountIn, address to, uint256 sharesMin, uint256 deadline)
        external
        returns (uint256 shares)
    {
        return _joinLiquidityExactIn(tokenIn, amountIn, to, sharesMin, deadline, address(0));
    }

    /// @notice CP joinSingleAssetExactOut entry point.
    /// @notice CP depositSingle entry point.
    function depositSingle(address tokenIn, uint256 amountIn, address to, uint256 minLpAmount, uint256 deadline)
        external
        onlyLiquidityOwner
        nonReentrant
        accrueProtocolFee
        returns (uint256 lpAmount)
    {
        PullLib.pullErc20Single(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }

    /// @notice CP depositSingleWithPermit2Signature entry point.
    function depositSingleWithPermit2Signature(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external onlyLiquidityOwner nonReentrant accrueProtocolFee returns (uint256 lpAmount) {
        PullLib.pullPermit2SignatureSingle(tokenIn, amountIn, permit2Data);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }

    /// @notice CP depositSingleWithPermit2Allowance entry point.
    function depositSingleWithPermit2Allowance(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant accrueProtocolFee returns (uint256 lpAmount) {
        PullLib.pullPermit2AllowanceSingle(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }
}
