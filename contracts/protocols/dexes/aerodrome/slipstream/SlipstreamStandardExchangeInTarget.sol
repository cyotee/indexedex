// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {SlipstreamZapQuoter} from "@crane/contracts/utils/math/SlipstreamZapQuoter.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SlipstreamPoolAwareRepo} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamPoolAwareRepo.sol";
import {SlipstreamVaultRepo} from "contracts/vaults/slipstream/SlipstreamVaultRepo.sol";
import {SlipstreamStandardExchangeCommon} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol";

contract SlipstreamStandardExchangeInTarget is SlipstreamStandardExchangeCommon, ReentrancyLockModifiers, IStandardExchangeIn {
    using BetterSafeERC20 for IERC20;

    struct ZapInState {
        address token0;
        address token1;
        bool zeroForOne;
        uint256 totalSharesBefore;
        uint256 reserve0Before;
        uint256 reserve1Before;
        ManagedTicks managedTicks;
        ManagedLiquidityPlan plan;
        uint256 balance0Before;
        uint256 balance1Before;
        uint256 amount0Used;
        uint256 amount1Used;
    }

    error SlipstreamExchangeIn_DeadlineExceeded();
    error SlipstreamExchangeIn_InsufficientOutput();
    error SlipstreamExchangeIn_ZeroDeposit();
    error SlipstreamExchangeIn_SlippageExceeded();

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        override
        returns (uint256 amountOut)
    {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        if ((address(tokenIn) == token0 && address(tokenOut) == token1)
            || (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            return _quoteSwap(address(tokenIn), address(tokenOut), amountIn);
        }

        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            return _previewZapInDeposit(tokenIn, amountIn);
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external override nonReentrant returns (uint256 amountOut) {
        if (deadline < block.timestamp) revert SlipstreamExchangeIn_DeadlineExceeded();

        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        if ((address(tokenIn) == token0 && address(tokenOut) == token1)
            || (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            return _swap(address(tokenIn), address(tokenOut), actualIn, minAmountOut, recipient);
        }

        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            return _executeZapInDeposit(tokenIn, actualIn, minAmountOut, recipient);
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function _previewZapInDeposit(IERC20 tokenIn, uint256 amountIn) internal view returns (uint256 sharesOut) {
        if (amountIn == 0) revert SlipstreamExchangeIn_ZeroDeposit();

        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        bool zeroForOne = address(tokenIn) == pool.token0();
        bool initialDeposit = !SlipstreamVaultRepo._isPositionCreated();
        ManagedTicks memory managedTicks = _managedTicks();
        uint256 totalShares = IERC20(address(this)).totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();

        SlipstreamZapQuoter.ZapInQuote memory quote = SlipstreamZapQuoter.quoteZapInSingleCore(
            SlipstreamZapQuoter.createZapInParams(
                pool,
                managedTicks.centerLower,
                managedTicks.centerUpper,
                address(tokenIn),
                amountIn,
                0,
                0,
                20,
                true
            )
        );

        uint256 available0;
        uint256 available1;
        if (zeroForOne) {
            available0 = amountIn - quote.swap.amountIn;
            available1 = quote.swap.amountOut;
        } else {
            available0 = quote.swap.amountOut;
            available1 = amountIn - quote.swap.amountIn;
        }

        (uint160 currentSqrtPriceX96, , , , , ) = pool.slot0();
        uint160 priceForMint = quote.swapAmountIn > 0 ? quote.swap.sqrtPriceAfterX96 : currentSqrtPriceX96;
        ManagedLiquidityPlan memory plan = _managedLiquidityPlanAtState(managedTicks, available0, available1, priceForMint);

        if (initialDeposit || totalShares == 0) {
            return plan.amount0Used + plan.amount1Used;
        }

        return ConstProdUtils._depositQuote(plan.amount0Used, plan.amount1Used, totalShares, reserve0, reserve1);
    }

    function _executeZapInDeposit(IERC20 tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        internal
        returns (uint256 sharesOut)
    {
        if (amountIn == 0) revert SlipstreamExchangeIn_ZeroDeposit();

        ZapInState memory state;
        state.token0 = _pool().token0();
        state.token1 = _pool().token1();
        state.zeroForOne = address(tokenIn) == state.token0;

        _collectManagedFees();

        state.totalSharesBefore = IERC20(address(this)).totalSupply();
        (state.reserve0Before, state.reserve1Before) = _totalVaultReserves();
        state.managedTicks = _managedTicks();

        SlipstreamZapQuoter.ZapInQuote memory quote = SlipstreamZapQuoter.quoteZapInSingleCore(
            SlipstreamZapQuoter.createZapInParams(
                _pool(),
                state.managedTicks.centerLower,
                state.managedTicks.centerUpper,
                address(tokenIn),
                amountIn,
                0,
                0,
                20,
                true
            )
        );

        if (quote.swapAmountIn > 0) {
            _swap(address(tokenIn), state.zeroForOne ? state.token1 : state.token0, quote.swapAmountIn, 0, address(this));
        }

        if (!SlipstreamVaultRepo._isPositionCreated()) {
            SlipstreamVaultRepo._createPositionIfNeeded(
                SlipstreamVaultRepo.PositionKind.Center,
                state.managedTicks.centerLower,
                state.managedTicks.centerUpper
            );
            SlipstreamVaultRepo._createPositionIfNeeded(
                SlipstreamVaultRepo.PositionKind.LowerWing,
                state.managedTicks.lowerWingLower,
                state.managedTicks.lowerWingUpper
            );
            SlipstreamVaultRepo._createPositionIfNeeded(
                SlipstreamVaultRepo.PositionKind.UpperWing,
                state.managedTicks.upperWingLower,
                state.managedTicks.upperWingUpper
            );
        }

        uint256 available0 = IERC20(state.token0).balanceOf(address(this));
        uint256 available1 = IERC20(state.token1).balanceOf(address(this));
        state.plan = _managedLiquidityPlan(state.managedTicks, available0, available1);

        state.balance0Before = IERC20(state.token0).balanceOf(address(this));
        state.balance1Before = IERC20(state.token1).balanceOf(address(this));

        _mintPositionLiquidity(state.managedTicks.centerLower, state.managedTicks.centerUpper, state.plan.centerLiquidity);
        _mintPositionLiquidity(state.managedTicks.lowerWingLower, state.managedTicks.lowerWingUpper, state.plan.lowerWingLiquidity);
        _mintPositionLiquidity(state.managedTicks.upperWingLower, state.managedTicks.upperWingUpper, state.plan.upperWingLiquidity);

        state.amount0Used = state.balance0Before - IERC20(state.token0).balanceOf(address(this));
        state.amount1Used = state.balance1Before - IERC20(state.token1).balanceOf(address(this));

        _updateManagedPositionLiquidities();

        if (state.totalSharesBefore == 0) {
            sharesOut = state.amount0Used + state.amount1Used;
        } else {
            sharesOut = ConstProdUtils._depositQuote(
                state.amount0Used,
                state.amount1Used,
                state.totalSharesBefore,
                state.reserve0Before,
                state.reserve1Before
            );
        }

        if (sharesOut < minSharesOut) revert SlipstreamExchangeIn_SlippageExceeded();

        ERC20Repo._mint(recipient, sharesOut);
        _refundRemainder(state.token0);
        _refundRemainder(state.token1);
    }

    function _mintPositionLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity) internal {
        if (liquidity == 0) {
            return;
        }
        _mintLiquidity(address(this), tickLower, tickUpper, liquidity);
    }

    function _mintLiquidity(address recipient, int24 tickLower, int24 tickUpper, uint128 liquidity)
        internal
        returns (uint256 amount0Used, uint256 amount1Used)
    {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint256 bal0Before = IERC20(token0).balanceOf(address(this));
        uint256 bal1Before = IERC20(token1).balanceOf(address(this));

        pool.mint(recipient, tickLower, tickUpper, liquidity, bytes(""));

        amount0Used = bal0Before - IERC20(token0).balanceOf(address(this));
        amount1Used = bal1Before - IERC20(token1).balanceOf(address(this));
    }

    function _refundRemainder(address token) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(msg.sender, balance);
        }
    }
}
