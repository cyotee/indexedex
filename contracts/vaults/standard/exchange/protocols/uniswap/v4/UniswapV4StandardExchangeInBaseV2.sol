// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeConstantProduct} from "../StandardExchangeConstantProduct.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {PositionInfo} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";

import {UniswapV4PositionRepoV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4PositionRepoV2.sol";
import {
    UniswapV4StandardExchangeCommonV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeCommonV2.sol";
import {
    IUniswapV4StandardExchangeLiquidReserveV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserveV2.sol";

abstract contract UniswapV4StandardExchangeInBaseV2 is UniswapV4StandardExchangeCommonV2, ReentrancyLockModifiers {
    error UniswapV4ExchangeIn_DeadlineExceeded();
    error UniswapV4ExchangeIn_SlippageExceeded();
    error UniswapV4ExchangeIn_PositionImportUnavailable();
    error UniswapV4ExchangeIn_InvalidImportedPool();
    error UniswapV4ExchangeIn_UntrustedPositionManager();
    error UniswapV4ExchangeIn_UntrustedImportOwner();

    function _swapExactIn(bool zeroForOne, uint256 amountSpecified) internal {
        _executeUnlock(
            OperationParams({
                op: Operation.SwapExactIn,
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                tickLower: 0,
                tickUpper: 0,
                liquidity: 0,
                salt: bytes32(0)
            })
        );
    }

    function _addLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity, bytes32 salt) internal {
        _executeUnlock(
            OperationParams({
                op: Operation.AddLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity,
                salt: salt
            })
        );
    }

    function _removeLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity, bytes32 salt) internal {
        _executeUnlock(
            OperationParams({
                op: Operation.RemoveLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity,
                salt: salt
            })
        );
    }

    function _createManagedPositionsIfNeeded(ManagedTicks memory managedTicks) internal {
        _createManagedPositionsIfNeededCommon(managedTicks);
    }

    function _executeDirectSwapIn(address tokenIn, uint256 amountIn, address recipient)
        internal
        returns (uint256 amountOut)
    {
        // D12: direct swaps require interaction-free; blocked → hard-revert via unlock guard.
        bool zeroForOne = tokenIn == _token0();
        address tokenOut = zeroForOne ? _token1() : _token0();
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

        _swapExactIn(zeroForOne, amountIn);

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
        _transferCurrency(tokenOut, recipient, amountOut);
        _syncVaultReserves();
        _rebalanceLiquidReserveBestEffort();
    }

    function _previewZapOutExactIn(address tokenOut, uint256 sharesBurned) internal view returns (uint256 amountOut) {
        if (sharesBurned == 0) {
            return 0;
        }

        uint256 totalShares = IERC20(address(this)).totalSupply();
        if (totalShares == 0) {
            return 0;
        }

        // D24: blocked preview models sleeve cover only; free models PM path.
        if (!canOpenPoolManagerUnlock()) {
            return _quoteSleeveZapOutAmount(tokenOut, sharesBurned, totalShares);
        }

        return _quoteZapOutAmount(tokenOut, sharesBurned, totalShares);
    }

    function _quoteZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 amount0, uint256 amount1) = _quoteManagedWithdrawal(sharesBurned, totalShares);
        // Also credit pro-rata free sleeve on burn (totals include free).
        (uint256 free0, uint256 free1) = _freeBalancesForShareMath();
        amount0 += (free0 * sharesBurned) / totalShares;
        amount1 += (free1 * sharesBurned) / totalShares;
        if (tokenOut == _token0()) {
            return amount0 + (amount1 > 0 ? _quoteSwapAfterWithdrawal(amount1, false, sharesBurned, totalShares) : 0);
        }
        return amount1 + (amount0 > 0 ? _quoteSwapAfterWithdrawal(amount0, true, sharesBurned, totalShares) : 0);
    }

    /// @dev Proportional burn plus fee-free conversion against the remaining complete book.
    function _quoteSleeveZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        return tokenOut == _token0()
            ? StandardExchangeConstantProduct._singleExit(reserve0, reserve1, sharesBurned, totalShares)
            : StandardExchangeConstantProduct._singleExit(reserve1, reserve0, sharesBurned, totalShares);
    }

    function _executeZapOutExactIn(address tokenOut, uint256 sharesBurned, uint256 minAmountOut, address recipient)
        internal
        returns (uint256 amountOut)
    {
        if (sharesBurned == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        uint256 totalShares = IERC20(address(this)).totalSupply();
        if (totalShares == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        if (!canOpenPoolManagerUnlock()) {
            // D18: blocked — pay from free inventory of tokenOut or revert InsufficientLocalReserve.
            amountOut = _quoteSleeveZapOutAmount(tokenOut, sharesBurned, totalShares);
            uint256 freeOut = IERC20(tokenOut).balanceOf(address(this));
            if (amountOut == 0 || freeOut < amountOut) {
                revert UniswapV4Exchange_InsufficientLocalReserve(
                    tokenOut, amountOut == 0 ? minAmountOut : amountOut, freeOut
                );
            }
            if (amountOut < minAmountOut) revert UniswapV4ExchangeIn_SlippageExceeded();
            ERC20Repo._burn(address(this), sharesBurned);
            _transferCurrency(tokenOut, recipient, amountOut);
            _syncVaultReserves();
            return amountOut;
        }

        // D3: free path always uses PoolManager even if sleeve would cover; then rebalance.
        amountOut = _executeFreeZapOutExactIn(tokenOut, sharesBurned, totalShares, minAmountOut, recipient);
    }

    function _executeFreeZapOutExactIn(
        address tokenOut,
        uint256 sharesBurned,
        uint256 totalShares,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256 amountOut) {
        _collectManagedFeesIfIdle();
        bool outIsToken0 = tokenOut == _token0();
        address otherToken = outIsToken0 ? _token1() : _token0();

        (uint256 free0, uint256 free1) = _freeBalances();
        uint256 freePortionOther =
            outIsToken0 ? (free1 * sharesBurned) / totalShares : (free0 * sharesBurned) / totalShares;
        uint256 freeOutShare = outIsToken0 ? (free0 * sharesBurned) / totalShares : (free1 * sharesBurned) / totalShares;

        uint256 otherBefore = IERC20(otherToken).balanceOf(address(this));
        uint256 outBefore = IERC20(tokenOut).balanceOf(address(this));

        _burnPositionLiquidity(sharesBurned, totalShares);

        {
            uint256 removedOther = IERC20(otherToken).balanceOf(address(this)) - otherBefore;
            uint256 otherForUser = removedOther + freePortionOther;
            uint256 otherBal = IERC20(otherToken).balanceOf(address(this));
            if (otherForUser > otherBal) otherForUser = otherBal;
            if (otherForUser > 0) {
                _swapExactIn(!outIsToken0, otherForUser);
            }
        }

        amountOut = (IERC20(tokenOut).balanceOf(address(this)) - outBefore) + freeOutShare;
        {
            uint256 bal = IERC20(tokenOut).balanceOf(address(this));
            if (amountOut > bal) amountOut = bal;
        }
        if (amountOut < minAmountOut) revert UniswapV4ExchangeIn_SlippageExceeded();

        ERC20Repo._burn(address(this), sharesBurned);
        _transferCurrency(tokenOut, recipient, amountOut);
        _syncVaultReserves();
        _rebalanceLiquidReserveBestEffort();
    }

    function _burnPositionLiquidity(uint256 sharesBurned, uint256 totalShares)
        internal
    {
        uint128 currentLiquidity = _currentLiquidity();
        if (currentLiquidity == 0) {
            return;
        }

        uint128 liquidityToBurn = uint128((sharesBurned * currentLiquidity) / totalShares);
        if (liquidityToBurn == 0) {
            return;
        }

        if (UniswapV4PositionRepoV2._isImportedPosition()) {

            bytes memory actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
            bytes[] memory params = new bytes[](2);
            params[0] = abi.encode(
                UniswapV4PositionRepoV2._importedPositionTokenId(),
                uint256(liquidityToBurn),
                uint128(0),
                uint128(0),
                bytes("")
            );
            params[1] = abi.encode(_currency0(), _currency1(), address(this));
            UniswapV4PositionRepoV2._importedPositionManager()
                .modifyLiquidities(abi.encode(actions, params), block.timestamp);
            return;
        }

        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepoV2._positionTicks();
        _removeLiquidity(tickLower, tickUpper, liquidityToBurn, UniswapV4PositionRepoV2._salt());
    }

    /**
     * @dev Preview deposit shares from total-reserve mint math only (D24 — no rebalance simulation).
     *      View path: reserves are pre-deposit (caller has not transferred).
     */
    function _previewZapInDeposit(address tokenIn, uint256 amountIn) internal view returns (uint256 sharesOut) {
        if (amountIn == 0) {
            return 0;
        }

        uint256 amount0Added = tokenIn == _token0() ? amountIn : 0;
        uint256 amount1Added = tokenIn == _token1() ? amountIn : 0;
        uint256 totalShares = IERC20(address(this)).totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        return _sharesOutForDeposit(amount0Added, amount1Added, totalShares, reserve0, reserve1);
    }

    /**
     * @dev Sleeve-then-deploy-excess deposit (D4/D27).
     *      Tokens already pulled onto the vault. Mint against free+deployed totals; do not refund sleeve.
     *      When free: best-effort rebalance deploys excess. When blocked: stay sleeve (no unlock).
     */
    function _executeZapInDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        internal
        returns (uint256 sharesOut)
    {
        if (amountIn == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        _collectManagedFeesIfIdle();

        uint256 amount0Added = tokenIn == _token0() ? amountIn : 0;
        uint256 amount1Added = tokenIn == _token1() ? amountIn : 0;
        uint256 totalSharesBefore = IERC20(address(this)).totalSupply();

        // Post-pull totals include deposit; back out for pre-deposit reserves.
        (uint256 total0, uint256 total1) = _totalVaultReserves();
        uint256 reserve0Before = total0 - amount0Added;
        uint256 reserve1Before = total1 - amount1Added;

        sharesOut = _sharesOutForDeposit(amount0Added, amount1Added, totalSharesBefore, reserve0Before, reserve1Before);
        if (sharesOut == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }
        if (sharesOut < minSharesOut) revert UniswapV4ExchangeIn_SlippageExceeded();

        // A0: residual inventory at empty supply is represented by dead shares, not first-minter NAV.
        if (totalSharesBefore == 0) {
            uint256 residual = _initialResidualShares(amount0Added, amount1Added, reserve0Before, reserve1Before, sharesOut);
            if (residual > 0) {
                ERC20Repo._mint(DEAD_SHARES_SINK, residual);
            }
        }

        ERC20Repo._mint(recipient, sharesOut);
        _syncVaultReserves();

        if (canOpenPoolManagerUnlock()) {
            // D27 / D11: deploy excess only; rebalance failure must not revert the mint.
            _rebalanceLiquidReserveBestEffort();
        } else {
            emit IUniswapV4StandardExchangeLiquidReserveV2.LocalDepositWhileBlocked(tokenIn, amountIn, sharesOut);
        }
    }

    /**
     * @dev Preview dual-sided deposit shares from total-reserve mint math only (D24).
     *      View path: reserves are pre-deposit (caller has not transferred).
     */
    function _previewZapInDualDeposit(uint256 amount0Added, uint256 amount1Added)
        internal
        view
        returns (uint256 sharesOut)
    {
        if (amount0Added == 0 || amount1Added == 0) {
            return 0;
        }
        uint256 totalShares = IERC20(address(this)).totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        return _sharesOutForDeposit(amount0Added, amount1Added, totalShares, reserve0, reserve1);
    }

    /**
     * @dev Dual-sided sleeve-then-deploy-excess join (D27/D45). Both amounts already pulled.
     *      User pays both `amountsIn` in full; surplus stays sleeve. No token0↔token1 swap.
     */
    function _executeZapInDualDeposit(
        uint256 amount0Added,
        uint256 amount1Added,
        uint256 minSharesOut,
        address recipient
    ) internal returns (uint256 sharesOut) {
        if (amount0Added == 0 || amount1Added == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        _collectManagedFeesIfIdle();

        uint256 totalSharesBefore = IERC20(address(this)).totalSupply();
        (uint256 total0, uint256 total1) = _totalVaultReserves();
        uint256 reserve0Before = total0 - amount0Added;
        uint256 reserve1Before = total1 - amount1Added;

        sharesOut = _sharesOutForDeposit(amount0Added, amount1Added, totalSharesBefore, reserve0Before, reserve1Before);
        if (sharesOut == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }
        if (sharesOut < minSharesOut) revert UniswapV4ExchangeIn_SlippageExceeded();

        if (totalSharesBefore == 0) {
            uint256 residual = _initialResidualShares(amount0Added, amount1Added, reserve0Before, reserve1Before, sharesOut);
            if (residual > 0) {
                ERC20Repo._mint(DEAD_SHARES_SINK, residual);
            }
        }

        ERC20Repo._mint(recipient, sharesOut);
        _syncVaultReserves();

        if (canOpenPoolManagerUnlock()) {
            _rebalanceLiquidReserveBestEffort();
        } else {
            emit IUniswapV4StandardExchangeLiquidReserveV2.LocalDepositWhileBlocked(_token0(), amount0Added, sharesOut);
            emit IUniswapV4StandardExchangeLiquidReserveV2.LocalDepositWhileBlocked(_token1(), amount1Added, sharesOut);
        }
    }

    function _increaseImportedPosition(uint128 liquidity, uint128 amount0Max, uint128 amount1Max) internal {
        _increaseImportedPositionCommon(liquidity, amount0Max, amount1Max);
    }
}
