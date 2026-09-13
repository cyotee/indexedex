// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
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
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

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

    function exitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        uint256 min0 = amountsMin.length > 0 ? amountsMin[0] : 0;
        uint256 min1 = amountsMin.length > 1 ? amountsMin[1] : 0;
        (uint256 a0, uint256 a1) = _withdraw(shares, to, min0, min1, deadline);
        amounts = new uint256[](2);
        amounts[0] = a0;
        amounts[1] = a1;
    }

    function previewExitProportional(uint256 shares) external view returns (uint256[] memory amounts) {
        (uint256 a0, uint256 a1) = _previewWithdraw(shares);
        amounts = new uint256[](2);
        amounts[0] = a0;
        amounts[1] = a1;
    }

    function exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAsset(tokenOut, sharesIn, to, deadline);
        if (amountOut < amountOutMin) revert InsufficientTokenOut();
    }

    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
        external
        view
        returns (uint256 amountOut)
    {
        if (sharesIn == 0 || !_isLive()) return 0;
        return _previewExitSingleAsset(tokenOut, sharesIn);
    }

    function exitSingleAssetExactTokenOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external pure returns (uint256) {
        tokenOut;
        amountOut;
        to;
        sharesInMax;
        deadline;
        revert InvalidRoute();
    }

    function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256)
    {
        tokenOut;
        amountOut;
        return 0;
    }

    /// @dev Dual has no DETF self-leg: proportional tokenOut only, no residual swap (H2).
    function previewBurnToToken(uint256 lpAmount, address tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (lpAmount == 0 || !_isLive()) return 0;
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenOut);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        Repo.Layout storage l = Repo._layout();
        (uint256 a0, uint256 a1) = _previewWithdraw(lpAmount);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            tokenOut = l.legs.pairOfStandardExchange[tokenOut];
        }
        if (tokenOut == l.currency0) return a0;
        if (tokenOut == l.currency1) return a1;
        return 0;
    }

    struct ExitState {
        address pair;
        bool asShare;
        bool outIs0;
        uint256 beforeOut;
    }

    function _exitSingleAsset(address tokenOut, uint256 sharesIn, address to, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        if (to == address(0)) revert ZeroAddress();
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenOut);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidRoute();
        Repo.Layout storage l = Repo._layout();
        ExitState memory state;
        state.asShare = kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange;
        state.pair = state.asShare ? l.legs.pairOfStandardExchange[tokenOut] : tokenOut;
        state.outIs0 = state.pair == l.currency0;
        if (!state.outIs0 && state.pair != l.currency1) revert InvalidRoute();

        state.beforeOut = IERC20(state.pair).balanceOf(address(this));
        (uint256 a0, uint256 a1) = _withdrawAndSettle(sharesIn, address(this), 0, 0, deadline, false);
        uint256 residual = state.outIs0 ? a1 : a0;
        if (residual > 0) {
            uint256 extra = _previewSwapExactIn(!state.outIs0, residual);
            if (extra > 0) _executeBookSwap(!state.outIs0, residual, extra, address(this));
            else IERC20(state.outIs0 ? l.currency1 : l.currency0).safeTransfer(msg.sender, residual);
        }
        // Credit actual operation proceeds, including rounding surplus, but no prior inventory.
        amountOut = IERC20(state.pair).balanceOf(address(this)) - state.beforeOut;
        if (state.asShare && amountOut > 0) amountOut = _buffer(tokenOut, state.pair, amountOut);
        IERC20(tokenOut).safeTransfer(to, amountOut);
        _syncReserves();
    }

    struct ExitQuoteLeg {
        address se;
        bytes state;
        uint256 assets;
        uint256 withdrawn;
    }

    function _previewExitSingleAsset(address tokenOut, uint256 sharesIn)
        internal view returns (uint256 amountOut)
    {
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenOut);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        Repo.Layout storage l = Repo._layout();
        bool asShare = kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange;
        address pair = asShare ? l.legs.pairOfStandardExchange[tokenOut] : tokenOut;
        bool outIs0 = pair == l.currency0;
        if (!outIs0 && pair != l.currency1) return 0;
        address other = outIs0 ? l.currency1 : l.currency0;
        if (ClaimLib.supportsTransitionQuote(_seFor(pair), pair, address(this))
            && ClaimLib.supportsTransitionQuote(_seFor(other), other, address(this))) {
            return _previewSequentialExit(pair, other, sharesIn, asShare);
        }
        amountOut = _previewFallbackExit(pair, other, sharesIn, outIs0);
        if (asShare && amountOut > 0) {
            amountOut = IStandardExchangeIn(tokenOut).previewExchangeIn(IERC20(pair), amountOut, IERC20(tokenOut));
        }
    }

    function _previewFallbackExit(address pair, address other, uint256 sharesIn, bool outIs0)
        private view returns (uint256)
    {
        // The residual trade uses the remaining share book after proportional withdrawal.
        (uint256 a0, uint256 a1) = _previewWithdraw(sharesIn);
        uint256 residual = outIs0 ? a1 : a0;
        uint256 claimIn = residual == 0 ? 0 : _previewBufferClaimIn(_seFor(other), other, residual);
        return (outIs0 ? a0 : a1) + _exitSaleQuote(
            other, pair, claimIn, _remainingClaim(other, sharesIn), _remainingClaim(pair, sharesIn)
        );
    }

    function _remainingClaim(address pair, uint256 lpAmount) private view returns (uint256) {
        address se = _seFor(pair);
        uint256 held = IERC20(se).balanceOf(address(this));
        uint256 removed = FullMath.mulDiv(held, lpAmount, _supplyAfterProtocolMint());
        return _claimOfSe(se, pair, held - removed);
    }

    function _previewSequentialExit(address pair, address other, uint256 sharesIn, bool asShare)
        private view returns (uint256 amountOut)
    {
        uint256 supply = _supplyAfterProtocolMint();
        ExitQuoteLeg memory output = _previewWithdrawLeg(pair, sharesIn, supply);
        ExitQuoteLeg memory input = _previewWithdrawLeg(other, sharesIn, supply);
        amountOut = output.withdrawn;
        if (input.withdrawn > 0) {
            uint256 assetsAfter;
            (,,, assetsAfter) = Transition(input.se).quoteTransition(
                input.state, Transition.Operation.DepositExactIn, input.withdrawn
            );
            uint256 addedClaim = assetsAfter > input.assets ? assetsAfter - input.assets : 0;
            uint256 extra = _exitSaleQuote(other, pair, addedClaim, input.assets, output.assets);
            if (extra > 0) {
                uint256 received;
                (output.state,, received, output.assets) = Transition(output.se).quoteTransition(
                    output.state, Transition.Operation.WithdrawExactOut, extra
                );
                amountOut += received;
            }
        }
        if (asShare && amountOut > 0) {
            (,, amountOut,) = Transition(output.se).quoteTransition(
                output.state, Transition.Operation.DepositExactIn, amountOut
            );
        }
    }

    function _previewWithdrawLeg(address pair, uint256 sharesIn, uint256 supply)
        private view returns (ExitQuoteLeg memory leg)
    {
        leg.se = _seFor(pair);
        (leg.state, leg.assets) = Transition(leg.se).quoteState(pair, address(this));
        uint256 seOut = FullMath.mulDiv(IERC20(leg.se).balanceOf(address(this)), sharesIn, supply);
        if (seOut > 0) {
            (leg.state,, leg.withdrawn, leg.assets) = Transition(leg.se).quoteTransition(
                leg.state, Transition.Operation.RedeemExactIn, seOut
            );
        }
    }

    function _exitSaleQuote(address tokenIn, address tokenOut, uint256 claimIn, uint256 reserveIn, uint256 reserveOut)
        private view returns (uint256)
    {
        if (claimIn == 0 || reserveIn == 0 || reserveOut == 0) return 0;
        uint8 decimalsIn = _decimalsOf(tokenIn);
        uint8 decimalsOut = _decimalsOf(tokenOut);
        return Math.fromWadFloor(Math.saleQuote(
            Math.toWad(claimIn, decimalsIn), Math.toWad(reserveIn, decimalsIn), Math.toWad(reserveOut, decimalsOut)
        ), decimalsOut);
    }

}
