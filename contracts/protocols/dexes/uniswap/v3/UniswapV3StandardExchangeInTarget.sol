// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {UniswapV3ZapQuoter} from "@crane/contracts/utils/math/UniswapV3ZapQuoter.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV3PoolAwareRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3PoolAwareRepo.sol";
import {UniswapV3VaultRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol";
import {
    UniswapV3StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol";

/// @dev Mutate-only exchange-in (preview lives on InQueryFacet for EIP-170 size).
contract UniswapV3StandardExchangeInTarget is UniswapV3StandardExchangeCommon, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;

    error UniswapV3ExchangeIn_DeadlineExceeded();
    error UniswapV3ExchangeIn_InsufficientOutput();
    error UniswapV3ExchangeIn_ZeroDeposit();
    error UniswapV3ExchangeIn_SlippageExceeded();

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
        uint256 inbound0;
        uint256 inbound1;
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
        if (deadline < block.timestamp) revert UniswapV3ExchangeIn_DeadlineExceeded();
        _requireNotDisabled();

        IUniswapV3Pool pool = UniswapV3PoolAwareRepo._uniswapV3Pool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            return _swap(address(tokenIn), address(tokenOut), actualIn, minAmountOut, recipient);
        }

        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            // Phase A before principal pull when not pretransferred.
            if (!pretransferred) {
                _feeFirstCompound();
            }
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            if (pretransferred) {
                // Fees collected while principal already sits in vault: compound excluding principal.
                _feeFirstCompoundReservingPrincipal(tokenIn, actualIn);
            }
            return _executeZapInDeposit(tokenIn, actualIn, minAmountOut, recipient);
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function _executeZapInDeposit(IERC20 tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        internal
        returns (uint256 sharesOut)
    {
        if (amountIn == 0) revert UniswapV3ExchangeIn_ZeroDeposit();

        ZapInState memory state;
        state.token0 = _pool().token0();
        state.token1 = _pool().token1();
        state.zeroForOne = address(tokenIn) == state.token0;

        state.totalSharesBefore = IERC20(address(this)).totalSupply();
        (state.reserve0Before, state.reserve1Before) = _totalVaultReserves();
        state.managedTicks = _managedTicks();

        UniswapV3ZapQuoter.ZapInQuote memory quote = UniswapV3ZapQuoter.quoteZapInSingleCore(
            UniswapV3ZapQuoter.ZapInParams({
                pool: _pool(),
                tickLower: state.managedTicks.centerLower,
                tickUpper: state.managedTicks.centerUpper,
                zeroForOne: state.zeroForOne,
                amountIn: amountIn,
                sqrtPriceLimitX96: 0,
                maxSwapSteps: 0,
                searchIters: 20
            })
        );

        state.inbound0 = state.zeroForOne ? amountIn : 0;
        state.inbound1 = state.zeroForOne ? 0 : amountIn;

        if (quote.swapAmountIn > 0) {
            address other = state.zeroForOne ? state.token1 : state.token0;
            uint256 otherBefore = IERC20(other).balanceOf(address(this));
            uint256 inBefore = IERC20(address(tokenIn)).balanceOf(address(this));
            _swap(address(tokenIn), other, quote.swapAmountIn, 0, address(this));
            uint256 swapOut = IERC20(other).balanceOf(address(this)) - otherBefore;
            uint256 swapInUsed = inBefore - IERC20(address(tokenIn)).balanceOf(address(this));
            if (state.zeroForOne) {
                state.inbound0 = state.inbound0 > swapInUsed ? state.inbound0 - swapInUsed : 0;
                state.inbound1 += swapOut;
            } else {
                state.inbound1 = state.inbound1 > swapInUsed ? state.inbound1 - swapInUsed : 0;
                state.inbound0 += swapOut;
            }
        }

        _createOrganicPositionsIfNeeded(state.managedTicks);

        // A0/E6: phase B mints only this-call delivered inbound, never prior free inventory.
        state.plan = _managedLiquidityPlan(state.managedTicks, state.inbound0, state.inbound1);

        state.balance0Before = IERC20(state.token0).balanceOf(address(this));
        state.balance1Before = IERC20(state.token1).balanceOf(address(this));

        _mintManagedLiquidity(state.managedTicks, state.plan);

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

        if (sharesOut < minSharesOut) revert UniswapV3ExchangeIn_SlippageExceeded();

        ERC20Repo._mint(recipient, sharesOut);
        uint256 unused0 = state.inbound0 > state.amount0Used ? state.inbound0 - state.amount0Used : 0;
        uint256 unused1 = state.inbound1 > state.amount1Used ? state.inbound1 - state.amount1Used : 0;
        _refundRemainder(state.token0, unused0);
        _refundRemainder(state.token1, unused1);
    }

    /// @dev Collect + compound free inventory excluding reserved principal already held.
    function _feeFirstCompoundReservingPrincipal(IERC20 tokenIn, uint256 principalAmount) internal {
        if (!UniswapV3VaultRepo._isPositionCreated()) {
            return;
        }
        _collectManagedFees();

        IUniswapV3Pool pool = _pool();
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 bal0 = IERC20(token0).balanceOf(address(this));
        uint256 bal1 = IERC20(token1).balanceOf(address(this));

        uint256 available0 = address(tokenIn) == token0
            ? (bal0 > principalAmount ? bal0 - principalAmount : 0)
            : bal0;
        uint256 available1 = address(tokenIn) == token1
            ? (bal1 > principalAmount ? bal1 - principalAmount : 0)
            : bal1;

        if (available0 == 0 && available1 == 0) {
            return;
        }

        ManagedTicks memory managedTicks = _managedTicks();
        ManagedLiquidityPlan memory plan = _managedLiquidityPlan(managedTicks, available0, available1);
        _mintManagedLiquidity(managedTicks, plan);
        _updateManagedPositionLiquidities();
    }

    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        if (pretransferred) {
            require(
                tokenIn.balanceOf(address(this)) >= amountIn,
                "UniswapV3ExchangeIn: insufficient pretransferred balance"
            );
            return amountIn;
        }

        uint256 balBefore = tokenIn.balanceOf(address(this));
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        actualIn = tokenIn.balanceOf(address(this)) - balBefore;
    }

    /// @dev E6: refund only this-call unused inbound, never the entire `balanceOf(this)`.
    function _refundRemainder(address token, uint256 unusedInbound) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 refund = unusedInbound < balance ? unusedInbound : balance;
        if (refund > 0) {
            IERC20(token).safeTransfer(msg.sender, refund);
        }
    }
}
